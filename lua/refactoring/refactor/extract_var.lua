-- TODO: handle extra logic for extracting var into class scope
local M = {}

local async = require "async"
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

---@class refactor.extract_var.code_generation
---@field variable_declaration {[string]: nil|fun(opts: refactor.extract_var.code_generation.variable_declaration.Opts): string}
---@field variable {[string]: nil|fun(opts: refactor.extract_var.code_generation.variable.Opts): string}

-- TODO: when rewriting `print_var` and `printf`, distinguish between
-- `print_expression` operator to print everything inside the selected region
-- and `print_var` operator to print ever variable inside the selected region
-- in the [some scope, I haven't think it through. Try to avoid loops and
-- things like that unless necesary. Maybe as close as possible to the last
-- declaration of the variables]

-- TODO: extract inline "before" code examples from tests to files under the `test/` directory

-- TODO: add per-feature configuration in `require'refactoring'.setup` that
-- includes overrides for code_generation (and all of the language-dependant
-- fields?) that could also allow users to define their own features
-- per-language (they would also need to define their own queries)
---@type refactor.extract_var.code_generation
local code_generation = {
  variable_declaration = {
    lua = function(opts)
      return ("local %s = %s"):format(opts.name, opts.value)
    end,
    javascript = function(opts)
      return ("const %s = %s;"):format(opts.name, opts.value)
    end,
    c = function(opts)
      return ("P %s = %s;"):format(opts.name, opts.value)
    end,
    c_sharp = function(opts)
      return ("var %s = %s;"):format(opts.name, opts.value)
    end,
    go = function(opts)
      return ("%s := %s"):format(opts.name, opts.value)
    end,
    java = function(opts)
      return ("var %s = %s;"):format(opts.name, opts.value)
    end,
    php = function(opts)
      return ("$%s = %s;"):format(opts.name, opts.value)
    end,
    python = function(opts)
      return ("%s = %s"):format(opts.name, opts.value)
    end,
    ruby = function(opts)
      return ("%s = %s"):format(opts.name, opts.value)
    end,
    vim = function(opts)
      return ("let l:%s = %s"):format(opts.name, opts.value)
    end,
    powershell = function(opts)
      return ("$%s = %s"):format(opts.name, opts.value)
    end,
  },
  variable = {
    php = function(opts)
      return ("$%s"):format(opts.name)
    end,
    vim = function(opts)
      return ("l:%s"):format(opts.name)
    end,
    powershell = function(opts)
      return ("$%s"):format(opts.name)
    end,
  },
}
code_generation.variable_declaration.typescript = code_generation.variable_declaration.javascript
code_generation.variable_declaration.cpp = code_generation.variable_declaration.c

---@class refactor.Scope
---@field scope TSNode
---@field inside TSNode?
---@field outside TSNode?

---@param range_type 'v' | 'V' | ''
---@param opts refactor.Opts?
function M.extract_var(range_type, opts)
  local get_extracted_range = require("refactoring.range").get_extracted_range
  local contains = require("refactoring.range").contains
  local compare = require("refactoring.range").compare
  local apply_text_edits = require("refactoring.utils").apply_text_edits
  local input = require("refactoring.utils").input
  local code_gen_error = require("refactoring.utils").code_gen_error

  opts = opts or {}

  local buf = api.nvim_get_current_buf()
  local extracted_range = get_extracted_range(range_type)

  local task = async.run(function()
    local var_name = opts.input and table.remove(opts.input, 1) or input { prompt = "Variable name: " }
    if not var_name then return end

    local lang_tree, err1 = ts.get_parser(buf, nil, { error = false })
    if not lang_tree then
      vim.notify(err1, vim.log.levels.ERROR)
      return
    end
    -- TODO: use async parsing
    lang_tree:parse(true)
    local nested_lang_tree = lang_tree:language_for_range(extracted_range)
    local lang = nested_lang_tree:lang()
    local encompassing_node = nested_lang_tree:node_for_range(extracted_range)
    if not encompassing_node then
      vim.notify("Couldn't find a Treesitter node that contains the selected range", vim.log.levels.WARN)
      return
    end

    local get_var = code_generation.variable[lang]
    local variable = get_var and get_var { name = var_name } or var_name
    local get_variable_declaration = code_generation.variable_declaration[lang]
    if not get_variable_declaration then return code_gen_error("variable_declaration", lang) end

    local extracted_text = ts.get_node_text(encompassing_node, buf)

    local ok, maybe_encompasing_query = pcall(ts.query.parse, lang, ("%s @tmp_query"):format(encompassing_node:sexpr()))
    if not ok then
      vim.notify(
        "The selected text couldn't be parser using Treesitter to look for similar occurrences.",
        vim.log.levels.ERROR
      )
      return
    end
    local encompasing_query = maybe_encompasing_query
    local query = ts.query.get(lang, "refactor")
    if not query then
      vim.notify(("There is no `refactor` query file for language %s"):format(lang), vim.log.levels.ERROR)
      return
    end

    local extracted_significant_text = significant_text(encompassing_node, buf)
    local matching_nodes = {} ---@type TSNode[]
    local scopes = {} ---@type refactor.Scope[]
    for _, tree in ipairs(nested_lang_tree:trees()) do
      for _, node in encompasing_query:iter_captures(tree:root(), buf) do
        local node_significant_text = significant_text(node, buf)
        if node_significant_text == extracted_significant_text then table.insert(matching_nodes, node) end
      end
      for _, match in query:iter_matches(tree:root(), buf) do
        local match_info ---@type refactor.Scope|nil
        for capture_id, nodes in pairs(match) do
          local name = query.captures[capture_id]
          if name == "scope" then
            match_info = match_info or {}
            match_info.scope = nodes[1]
          elseif name == "scope.inside" then
            match_info = match_info or {}
            match_info.inside = nodes[1]
          elseif name == "scope.outside" then
            match_info = match_info or {}
            match_info.outside = nodes[1]
          end
        end
        if match_info then table.insert(scopes, match_info) end
      end
    end

    ---@type {[integer]: refactor.TextEdit[]}
    local text_edits_by_buf = {}
    text_edits_by_buf[buf] = {}
    iter(matching_nodes):each(
      ---@param n TSNode
      function(n)
        -- TODO: I may need to handle end_row-exclusive, 0-col Treesitter ranges everywhere
        local range = { n:range() }
        table.insert(text_edits_by_buf[buf], { range = range, lines = { variable } })
      end
    )

    ---@type refactor.Scope|nil
    local smallest_common_scope = iter(scopes)
      :filter(
        ---@param s refactor.Scope
        function(s)
          local scope_range = { s.scope:range() }
          return iter(matching_nodes):all(
            ---@param n TSNode
            function(n)
              local node_start = { n:start() }
              local node_end = { n:end_() }
              return contains(scope_range, node_start) and contains(scope_range, node_end)
            end
          )
        end
      )
      :fold(
        nil,
        ---@param acc refactor.Scope|nil
        ---@param s refactor.Scope
        function(acc, s)
          if not acc then return s end
          if s.scope:byte_length() < acc.scope:byte_length() then return s end
          return acc
        end
      )
    if not smallest_common_scope then
      -- TODO: put all of this notifies into a single function and return to
      -- put into a single line
      vim.notify "Couldn't find the smallest common scope using Treesitter"
      return
    end

    local smallest_common_scope_start = { (smallest_common_scope.inside or smallest_common_scope.scope):start() }
    local smallest_common_scope_end = { (smallest_common_scope.inside or smallest_common_scope.scope):end_() }
    ---@type refactor.Scope|nil
    local highest_nested_containing_scope = iter(scopes)
      :filter(
        ---@param s refactor.Scope
        function(s)
          if s.scope:equal(smallest_common_scope.scope) then return false end

          local scope = s.outside or s.scope
          local scope_start = { (scope):start() }
          local scope_end = { (scope):end_() }
          local scope_range = { (scope):range() }

          return compare(smallest_common_scope_start, scope_start) ~= 1
            and compare(smallest_common_scope_end, scope_end) ~= -1
            and iter(matching_nodes):any(
              ---@param n TSNode
              function(n)
                local node_start = { n:start() }
                local node_end = { n:end_() }
                return contains(scope_range, node_start) and contains(scope_range, node_end)
              end
            )
        end
      )
      :fold(
        nil,
        ---@param acc refactor.Scope|nil
        ---@param s refactor.Scope
        function(acc, s)
          if not acc then return s end

          local s_start = { (s.outside or s.scope):start() }
          local acc_start = { (acc.outside or acc.scope):start() }
          if compare(s_start, acc_start) == -1 then return s end

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

        local n_start = { n:start() }
        local acc_start = { acc:start() }
        if compare(n_start, acc_start) == -1 then return n end

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
    local output_range = { highest_matching_node_start_row, highest_matching_node_start_first_non_blank or 0 }
    if
      highest_nested_containing_scope
      and compare(
          { (highest_nested_containing_scope.outside or highest_nested_containing_scope.scope):start() },
          output_range
        )
        == -1
    then
      output_range = { (highest_nested_containing_scope.outside or highest_nested_containing_scope.scope):start() }
    end

    local variable_declaration = get_variable_declaration {
      name = var_name,
      value = extracted_text,
    }
    local variable_declaration_lines = vim.split(variable_declaration, "\n")
    local output_start_line = api.nvim_buf_get_lines(buf, output_range[1], output_range[1] + 1, true)[1]
    local _, indent_amount = vim.text.indent(0, output_start_line)
    table.insert(variable_declaration_lines, (vim.bo[buf].expandtab and " " or "\t"):rep(indent_amount))
    table.insert(text_edits_by_buf[buf], {
      range = {
        output_range[1],
        output_range[2],
        output_range[1],
        output_range[2],
      },
      lines = variable_declaration_lines,
    })

    apply_text_edits(text_edits_by_buf)
  end)

  task:raise_on_error()
end

return M
