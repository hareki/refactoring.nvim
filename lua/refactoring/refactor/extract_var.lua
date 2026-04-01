-- TODO: handle extra logic for extracting var into class scope
local M = {}

local async = require "async"
local range = require "refactoring.range"
local pos = require "refactoring.pos"
local ts = vim.treesitter
local iter = vim.iter
local api = vim.api

---@param node TSNode
---@param buf integer
---@param acc string[]|nil
---@return string[]
local function significant_text_list(node, buf, acc)
  acc = acc or {}
  if node:child_count() == 0 then table.insert(acc, ts.get_node_text(node, buf)) end
  if node:child_count() > 0 then
    for child in node:iter_children() do
      significant_text_list(child, buf, acc)
    end
  end

  return acc
end

---@param node TSNode
---@param buf integer
---@return string
local function significant_text(node, buf)
  return table.concat(significant_text_list(node, buf), "")
end

---@class refactor.extract_var.code_generation.variable_declaration.Opts
---@field name string
---@field value string

---@class refactor.extract_var.code_generation.variable.Opts
---@field name string

---@class refactor.extract_var.CodeGeneration
---@field variable_declaration {[string]: nil|fun(opts: refactor.extract_var.code_generation.variable_declaration.Opts): string}
---@field variable {[string]: nil|fun(opts: refactor.extract_var.code_generation.variable.Opts): string}

---@class refactor.extract_var.UserCodeGeneration
---@field variable_declaration? {[string]: nil|fun(opts: refactor.extract_var.code_generation.variable_declaration.Opts): string}
---@field variable? {[string]: nil|fun(opts: refactor.extract_var.code_generation.variable.Opts): string}

---@class refactor.ScopeInfo
---@field scope TSNode[]
---@field inside TSNode
---@field outside TSNode

---@param range_type 'v' | 'V' | ''
---@param config refactor.Config
function M.extract_var(range_type, config)
  local get_selected_range = require("refactoring.utils").get_selected_range
  local apply_text_edits = require("refactoring.utils").apply_text_edits
  local input = require("refactoring.utils").input
  local code_gen_error = require("refactoring.utils").code_gen_error
  local get_scopes_info = require("refactoring.utils").get_scopes_info
  local query_error = require("refactoring.utils").query_error

  local opts = config.refactor.extract_var
  local code_generation = opts.code_generation

  local buf = api.nvim_get_current_buf()
  local selected_range = get_selected_range(buf, range_type)

  local task = async.run(function()
    local var_name = opts.input and table.remove(opts.input, 1) or input { prompt = "Variable name: " }
    if not var_name then return end

    local lang_tree, err1 = ts.get_parser(buf, nil, { error = false })
    if not lang_tree then
      ---@cast err1 -nil
      vim.notify(err1, vim.log.levels.ERROR)
      return
    end
    -- TODO: use async parsing
    lang_tree:parse(true)
    local selected_range_ts =
      { selected_range.start_row, selected_range.start_col, selected_range.end_row, selected_range.end_col }
    local nested_lang_tree = lang_tree:language_for_range(selected_range_ts)
    local lang = nested_lang_tree:lang()
    local encompassing_node = nested_lang_tree:node_for_range(selected_range_ts)
    if not encompassing_node then
      vim.notify("Couldn't find a Treesitter node that contains the selected range", vim.log.levels.WARN)
      return
    end

    local get_var = code_generation.variable[lang]
    local variable = get_var and get_var { name = var_name } or var_name
    local get_variable_declaration = code_generation.variable_declaration[lang]
    if not get_variable_declaration then return code_gen_error("variable_declaration", lang) end

    local selected_text = ts.get_node_text(encompassing_node, buf)

    local ok, maybe_encompasing_query = pcall(ts.query.parse, lang, ("%s @tmp_query"):format(encompassing_node:sexpr()))
    if not ok then
      vim.notify(
        "The selected text couldn't be parser using Treesitter to look for similar occurrences.",
        vim.log.levels.ERROR
      )
      return
    end
    local encompasing_query = maybe_encompasing_query
    local scope_query = ts.query.get(lang, "refactor_scope")
    if not scope_query then return query_error("refactor_scope", lang) end

    local selected_significant_text = significant_text(encompassing_node, buf)
    local matching_nodes = {} ---@type TSNode[]
    for _, tree in ipairs(nested_lang_tree:trees()) do
      for _, node in encompasing_query:iter_captures(tree:root(), buf) do
        local node_significant_text = significant_text(node, buf)
        if node_significant_text == selected_significant_text then table.insert(matching_nodes, node) end
      end
    end
    local scopes_info = get_scopes_info(buf, nested_lang_tree, scope_query)

    ---@type {[integer]: refactor.TextEdit[]}
    local text_edits_by_buf = {}
    text_edits_by_buf[buf] = {}
    iter(matching_nodes):each(
      ---@param n TSNode
      function(n)
        local srow, scol, erow, ecol = n:range()
        local node_range = range(srow, scol, erow, ecol, { buf = buf })
        table.insert(text_edits_by_buf[buf], { range = node_range, lines = { variable } })
      end
    )

    ---@type {si: refactor.ScopeInfo, s: TSNode}|nil
    local smallest_common_scope_with_node = iter(scopes_info)
      :map(
        ---@param si refactor.ScopeInfo
        function(si)
          local scope = iter(si.scope):find(
            ---@param s TSNode
            function(s)
              local srow, scol, erow, ecol = s:range()
              local scope_range = range(srow, scol, erow, ecol, { buf = buf })
              return iter(matching_nodes):all(
                ---@param n TSNode
                function(n)
                  local n_srow, n_scol, n_erow, n_ecol = n:range()
                  local node_range = range(n_srow, n_scol, n_erow, n_ecol, { buf = buf })
                  return scope_range:has(node_range)
                end
              )
            end
          )
          return si, scope
        end
      )
      :filter(
        ---@param scope TSNode|nil
        function(_, scope)
          return scope ~= nil
        end
      )
      :fold(
        nil,
        ---@param acc {si: refactor.ScopeInfo, s: TSNode}|nil
        ---@param si refactor.ScopeInfo
        ---@param s TSNode
        function(acc, si, s)
          if not acc then return { si = si, s = s } end
          if s:byte_length() < acc.s:byte_length() then return { si = si, s = s } end
          return acc
        end
      )
    if not smallest_common_scope_with_node then
      -- TODO: put all of this notifies into a single function and return to
      -- put into a single line
      return vim.notify "Couldn't find the smallest common scope using Treesitter"
    end
    local smallest_common_scope = smallest_common_scope_with_node.si

    local srow, scol, erow, ecol = smallest_common_scope.inside:range()
    local smallest_common_inside_scope_range = range(srow, scol, erow, ecol, { buf = buf })
    ---@type refactor.ScopeInfo|nil
    local highest_nested_containing_scope = iter(scopes_info)
      :filter(
        ---@param si refactor.ScopeInfo
        function(si)
          if si == smallest_common_scope then return false end

          local scope = si.outside
          local s_srow, s_scol, s_erow, s_ecol = scope:range()
          local scope_range = range(s_srow, s_scol, s_erow, s_ecol, { buf = buf })

          return smallest_common_inside_scope_range:has(scope_range)
            and iter(matching_nodes):any(
              ---@param n TSNode
              function(n)
                local n_srow, n_scol, n_erow, n_ecol = n:range()
                local node_range = range(n_srow, n_scol, n_erow, n_ecol, { buf = buf })
                return scope_range:has(node_range)
              end
            )
        end
      )
      :fold(
        nil,
        ---@param acc refactor.ScopeInfo|nil
        ---@param s refactor.ScopeInfo
        function(acc, s)
          if not acc then return s end

          local s_srow, s_scol = s.outside:start()
          local s_start = pos(s_srow, s_scol, { buf = buf })
          local acc_srow, acc_scol = acc.outside:start()
          local acc_start = pos(acc_srow, acc_scol, { buf = buf })
          if s_start < acc_start then return s end

          return acc
        end
      )

    ---@type TSNode?
    local highest_matching_node = iter(matching_nodes):fold(
      nil,
      ---@param acc TSNode|nil
      ---@param n TSNode
      function(acc, n)
        if not acc then return n end

        local n_srow, n_scol = n:start()
        local n_start = pos(n_srow, n_scol, { buf = buf })
        local acc_srow, acc_scol = acc:start()
        local acc_start = pos(acc_srow, acc_scol, { buf = buf })
        if n_start < acc_start then return n end

        return acc
      end
    )
    assert(highest_matching_node)
    local highest_matching_node_start_row = highest_matching_node:start()
    local highest_matching_node_start_line =
      api.nvim_buf_get_lines(buf, highest_matching_node_start_row, highest_matching_node_start_row + 1, true)[1]
    local _, highest_matching_node_start_first_non_blank = highest_matching_node_start_line:find "^%s+"

    -- TODO: I still need to compute where the declaration for all references
    -- inside the extracte_text are and make sure that `output_range` is below
    -- all of them (this may exclude possible candidates for `matching_nodes`),
    -- so I'll need to use it to found the correct scope inside of which all of
    -- `matching_nodes` should be
    local output_range = range.extmark(
      highest_matching_node_start_row,
      highest_matching_node_start_first_non_blank or 0,
      highest_matching_node_start_row,
      highest_matching_node_start_first_non_blank or 0,
      { buf = buf }
    )
    if highest_nested_containing_scope then
      local cs_srow, cs_scol = highest_nested_containing_scope.outside:start()
      local highest_nested_containing_scope_start = pos(cs_srow, cs_scol, { buf = buf })
      if
        highest_nested_containing_scope_start
        < pos(output_range.start_row, output_range.start_col, { buf = output_range.buf })
      then
        local api_srow, api_scol = highest_nested_containing_scope_start:to_extmark()
        output_range = range.extmark(api_srow, api_scol, api_srow, api_scol, { buf = buf })
      end
    end

    local variable_declaration = get_variable_declaration {
      name = var_name,
      value = selected_text,
    }
    local variable_declaration_lines = vim.split(variable_declaration, "\n")
    local output_srow = output_range:to_extmark()
    local output_start_line = api.nvim_buf_get_lines(buf, output_srow, output_srow + 1, true)[1]
    local _, indent_amount = vim.text.indent(0, output_start_line)
    table.insert(variable_declaration_lines, (vim.bo[buf].expandtab and " " or "\t"):rep(indent_amount))
    table.insert(text_edits_by_buf[buf], {
      range = output_range,
      lines = variable_declaration_lines,
    })

    apply_text_edits(text_edits_by_buf)
  end)

  task:raise_on_error()
end

return M
