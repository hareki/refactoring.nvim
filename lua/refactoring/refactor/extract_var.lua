local M = {}

local async = require "async"
local ts = vim.treesitter
local iter = vim.iter
local api = vim.api

-- TODO: move all of this common functions into some other file
---@type fun(opts: table): string
local input = async.wrap(2, function(opts, cb)
  vim.ui.input(opts, cb)
end)

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

---@param a TSNode
---@param b TSNode
---@return boolean
local function node_comp_asc(a, b)
  local a_row, a_col, a_bytes = a:start()
  local b_row, b_col, b_bytes = b:start()
  if a_row ~= b_row then return a_row < b_row end

  return (a_col < b_col or b_col + b_bytes > a_col + a_bytes)
end

---@param a TSNode
---@param b TSNode
---@return boolean
local function node_comp_desc(a, b)
  return not node_comp_asc(a, b)
end

---@class refactor.extract_var.code_generation.variable_declaration.Opts
---@field name string
---@field value string

---@class refactor.extract_var.code_generation
---@field variable_declaration {[string]: fun(opts: refactor.extract_var.code_generation.variable_declaration.Opts): string}

---@type refactor.extract_var.code_generation
local code_generation = {
  variable_declaration = {
    lua = function(opts)
      return ("local %s = %s"):format(opts.name, opts.value)
    end,
  },
}

---@class refactor.Scope
---@field scope TSNode
---@field start TSNode

-- TODO: remove first parameter (buf) after rewrite
---@param range_type 'v' | 'V' | ''
function M.extract_var(_, range_type)
  -- TODO: lazy load imports in other refactors
  local get_extracted_range = require("refactoring.range").get_extracted_range
  local contains = require("refactoring.range").contains

  local buf = api.nvim_get_current_buf()
  local extracted_range, lines = get_extracted_range(range_type)

  local task = async.run(function()
    local var_name = input { prompt = "Variable name: " }
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

    local extracted_text = ts.get_node_text(encompassing_node, buf)

    -- TODO: not all languages can freely parse a sexpr. Check if this gives me issues for any language
    local encompasing_query = ts.query.parse(lang, ("%s @tmp_query"):format(encompassing_node:sexpr()))
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
          elseif name == "scope.start" then
            match_info = match_info or {}
            match_info.start = nodes[1]
          end
        end
        if match_info then table.insert(scopes, match_info) end
      end
    end

    table.sort(matching_nodes, node_comp_desc)
    iter(matching_nodes):each(
      ---@param n TSNode
      function(n)
        -- TODO: I may need to handle end_row-exclusive, 0-col Treesitter ranges everywhere
        local start_row, start_col, end_row, end_col = n:range()
        api.nvim_buf_set_text(buf, start_row, start_col, end_row, end_col, { var_name })
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
      vim.notify "Couldn't find the smallest common scope using Treesitter"
      return
    end

    local start_row, start_col = smallest_common_scope.start:start()
    local variable_declaration = code_generation.variable_declaration[lang] {
      name = var_name,
      value = extracted_text,
    }
    local scope_start_line = api.nvim_buf_get_lines(buf, start_row, start_row + 1, true)[1]
    local _, indent_amount = vim.text.indent(0, scope_start_line)
    api.nvim_buf_set_text(
      buf,
      start_row,
      start_col,
      start_row,
      start_col,
      { variable_declaration, (vim.bo[buf].expandtab and " " or "\t"):rep(indent_amount) }
    )
  end)

  task:raise_on_error()
end

return M
