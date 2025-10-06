local contains = require("refactoring.range").contains
local compare = require("refactoring.range").compare
local iter = vim.iter
local ts = vim.treesitter
local api = vim.api
local async = require "async"
local lsp = vim.lsp

local M = {}

---@class refactor.QfItem
---@field filename string
---@field lnum integer
---@field end_lnum integer
---@field col integer
---@field end_col integer
---@field text string
---@field kind string?

---@type async fun(): refactor.QfItem[]
local get_definitions = async.wrap(1, function(cb)
  lsp.buf.definition {
    on_list = function(args)
      cb(args.items)
    end,
  }
end)

---@type async fun(): refactor.QfItem[]
local get_references = async.wrap(1, function(cb)
  lsp.buf.references({
    includeDeclaration = false,
  }, {
    on_list = function(args)
      cb(args.items)
    end,
  })
end)

---@type async fun(items: any[], opts: table)
local select = async.wrap(3, function(items, opts, on_choice)
  vim.ui.select(items, opts, on_choice)
end)

---@param definition refactor.QfItem
---@param lang string
---@return nil|refactor.VariableInfo
local function get_definition_info(definition, lang)
  local definition_buf = vim.fn.bufadd(definition.filename)
  if not api.nvim_buf_is_loaded(definition_buf) then vim.fn.bufload(definition_buf) end
  local definition_lang_tree, err2 = ts.get_parser(definition_buf, nil, { error = false })
  if not definition_lang_tree then
    vim.notify(err2, vim.log.levels.ERROR)
    return
  end
  -- TODO: use async parsing
  definition_lang_tree:parse(true)
  local definition_nested_lang_tree = definition_lang_tree:language_for_range {
    definition.lnum - 1,
    definition.col - 1,
    definition.end_lnum - 1,
    definition.end_col - 1,
  }

  local query = ts.query.get(lang, "refactor")
  if not query then
    vim.notify(("There is no `refactor` query file for language %s"):format(lang), vim.log.levels.ERROR)
    return
  end

  local definition_matches_info = {} ---@type refactor.VariableMatchInfo[]
  for _, tree in ipairs(definition_nested_lang_tree:trees()) do
    for _, match in query:iter_matches(tree:root(), definition_buf) do
      local match_info = {} ---@type refactor.VariableMatchInfo|{}
      for capture_id, nodes in pairs(match) do
        local name = query.captures[capture_id]

        if name == "variable.identifier" then
          match_info.identifier = nodes
        elseif name == "variable.identifier_separator" then
          match_info.identifier_separator = nodes
        elseif name == "variable.value_separator" then
          match_info.value_separator = nodes
        elseif name == "variable.value" then
          match_info.value = nodes
        elseif name == "variable.declaration" then
          match_info.declaration = nodes
        end
      end
      if not vim.tbl_isempty(match_info) then table.insert(definition_matches_info, match_info) end
    end
  end

  ---@type refactor.VariableInfo
  local variable_info = iter(definition_matches_info)
    :map(
      ---@param match_info refactor.VariableMatchInfo
      function(match_info)
        local variable_info = iter(ipairs(match_info.identifier))
          :filter(
            ---@param _ integer
            ---@param identifier TSNode
            function(_, identifier)
              local start_row, start_col, end_row, end_col = identifier:range()
              return contains({ start_row, start_col, end_row, end_col }, { definition.lnum - 1, definition.col - 1 })
            end
          )
          :map(
            ---@param i integer
            ---@param identifier TSNode
            ---@return refactor.VariableInfo
            function(i, identifier)
              return {
                identifier = identifier,
                identifier_separator = match_info.identifier_separator
                  and (match_info.identifier_separator[i] or match_info.identifier_separator[i - 1]),
                value = match_info.value[i],
                value_separator = match_info.value_separator
                  and (match_info.value_separator[i] or match_info.value_separator[i - 1]),
                -- NOTE: captures must only have one declaration
                declaration = match_info.declaration[1],
              }
            end
          )
          :next()
        return variable_info
      end
    )
    :filter(
      ---@param variable_info refactor.VariableInfo
      function(variable_info)
        return variable_info ~= nil
      end
    )
    :next()

  return variable_info
end

---@param a Range4
---@param b Range4
local function comp_non_overlaping_ranges_desc(a, b)
  local compare_start = compare({ a[1], a[2] }, { b[1], b[2] })
  if compare_start == 1 then return true end
  if compare_start == -1 then return false end

  local compare_end = compare({ a[3], a[4] }, { b[3], b[4] })
  return compare_end == 1
end

---@class refactor.VariableMatchInfo
---@field identifier TSNode[]
---@field identifier_separator TSNode[]|nil
---@field value TSNode[]
---@field value_separator TSNode[]|nil
---@field declaration TSNode[]

---@class refactor.VariableInfo
---@field identifier TSNode
---@field identifier_separator TSNode|nil
---@field value TSNode
---@field value_separator TSNode|nil
---@field declaration TSNode

-- TODO: preview highlight
-- TODO: preview is not working at all
-- TODO: success message (can be disabled in config)
function M.inline_var()
  local lang_tree, err1 = ts.get_parser(nil, nil, { error = false })
  if not lang_tree then
    vim.notify(err1, vim.log.levels.ERROR)
    return
  end
  -- TODO: use async parsing
  lang_tree:parse(true)
  local cursor = api.nvim_win_get_cursor(0)
  local nested_lang_tree = lang_tree:language_for_range {
    cursor[1] - 1,
    cursor[2],
    cursor[1] - 1,
    cursor[2],
  }
  local lang = nested_lang_tree:lang()

  local task = async.run(function()
    local results = async.await_all {
      async.run(get_definitions),
      async.run(get_references),
    }
    local definitions = unpack(results[1]) ---@type refactor.QfItem[]
    local references = unpack(results[2]) ---@type refactor.QfItem[]

    ---@type {definition: refactor.QfItem, match: refactor.VariableInfo}[]
    local definitions_with_match = iter(definitions)
      :map(
        ---@param d refactor.QfItem
        function(d)
          local definition_match = get_definition_info(d, lang)
          return { definition = d, match = definition_match }
        end
      )
      :filter(
        ---@param dwm {definition: refactor.QfItem, match: refactor.VariableInfo}
        function(dwm)
          return dwm.match ~= nil
        end
      )
      :totable()

    if #definitions_with_match == 0 then
      vim.notify("Couldn't find the definition of the symbol under cursor using treesitter", vim.log.levels.ERROR)
      return
    end
    local definition_with_match = #definitions_with_match == 1 and definitions_with_match[1]
      or select(definitions_with_match, {
        prompt = "Mutliple definitions found, select one",
        format_item =
          ---@param item {definition: refactor.QfItem, match: refactor.VariableInfo}
          function(item)
            local buf = vim.fn.bufadd(item.definition.filename)
            return ts.get_node_text(item.match.declaration, buf)
          end,
      })
    local definition, definition_info = definition_with_match.definition, definition_with_match.match
    local definition_buf = vim.fn.bufadd(definition.filename)

    ---@type refactor.QfItem[]
    references = iter(references)
      :filter(
        ---@param r refactor.QfItem
        function(r)
          return not contains(
            { r.lnum - 1, r.col - 1, r.end_lnum - 1, r.end_col - 1 },
            { definition.lnum - 1, definition.col - 1 }
          )
        end
      )
      :totable()

    local declaration_node = definition_info.declaration
    local identifier_node = definition_info.identifier
    local value_node = definition_info.value

    local value_text = ts.get_node_text(value_node, definition_buf)
    local identifier_text = ts.get_node_text(identifier_node, definition_buf)
    table.sort(references, function(a, b)
      return comp_non_overlaping_ranges_desc(
        { a.lnum, a.col, a.end_lnum, a.end_col },
        { b.lnum, b.col, b.end_lnum, b.end_col }
      )
    end)
    iter(references):each(
      ---@param reference refactor.QfItem
      function(reference)
        local buf = vim.fn.bufadd(reference.filename)
        if not api.nvim_buf_is_loaded(buf) then vim.fn.bufload(buf) end
        api.nvim_buf_set_text(
          buf,
          reference.lnum - 1,
          -- NOTE: references of `bar` on `foo.bar` won't include
          -- `foo.`. So, account for all of the identifier length
          reference.end_col
            - 1
            - #identifier_text,
          reference.end_lnum - 1,
          reference.end_col - 1,
          vim.split(value_text, "\n")
        )
      end
    )

    if definition_info.value_separator or definition_info.identifier_separator then
      ---@type Range4[]
      local ranges = iter({
          definition_info.value_separator,
          value_node,
          definition_info.identifier_separator,
          identifier_node,
        })
        :filter(function(n)
          return n ~= nil
        end)
        :map(
          ---@param n TSNode
          function(n)
            return { n:range() }
          end
        )
        :totable()
      table.sort(ranges, comp_non_overlaping_ranges_desc)
      for _, range in ipairs(ranges) do
        api.nvim_buf_set_text(definition_buf, range[1], range[2], range[3], range[4], {})
      end
    else
      local start_row, start_col, end_row, end_col = declaration_node:range()
      api.nvim_buf_set_text(definition_buf, start_row, start_col, end_row, end_col, {})
    end
  end)
  task:raise_on_error()
end

return M
