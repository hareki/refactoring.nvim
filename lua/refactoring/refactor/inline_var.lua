local contains = require("refactoring.range").contains
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

---@type fun(): refactor.QfItem[]
local get_definitions = async.wrap(1, function(cb)
  lsp.buf.definition {
    on_list = function(args)
      cb(args.items)
    end,
  }
end)

---@type fun(): refactor.QfItem[]
local get_references = async.wrap(1, function(cb)
  lsp.buf.references({
    includeDeclaration = false,
  }, {
    on_list = function(args)
      cb(args.items)
    end,
  })
end)

---@class refactor.VariableMatchInfo
---@field identifier TSNode[]
---@field value TSNode[]
---@field declaration TSNode[]

-- TODO: preview highlight
-- TODO: preview is not working at all
-- TODO: success message (can be disabled in config)
-- TODO: add lua_ls to GitHub actions
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
    local definitions = unpack(results[1]) ---@type string?, refactor.QfItem[]
    local references = unpack(results[2]) ---@type string?, refactor.QfItem[]
    -- TODO: allow to select one of the multiple definitions
    -- TODO: filter definitions that do not have a matching treesitter
    -- capture on their range
    if #definitions > 1 then
      vim.notify("Symbol under cursor has multiple definitions. It can't be inlined", vim.log.levels.WARN)
      return
    end
    local definition = definitions[1]

    ---@type refactor.QfItem
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
          elseif name == "variable.value" then
            match_info.value = nodes
          elseif name == "variable.declaration" then
            match_info.declaration = nodes
          end
        end
        if not vim.tbl_isempty(match_info) then table.insert(definition_matches_info, match_info) end
      end
    end

    ---@type refactor.VariableMatchInfo
    local definition_match = iter(definition_matches_info):find(
      ---@param match_info refactor.VariableMatchInfo
      function(match_info)
        return iter(match_info.identifier):any(
          ---@param i TSNode
          function(i)
            local start_row, start_col, end_row, end_col = i:range()
            return contains({ start_row, start_col, end_row, end_col }, { definition.lnum - 1, definition.col - 1 })
          end
        )
      end
    )
    if not definition_match then
      vim.notify("Couldn't find the definition of the symbol under cursor using treesitter", vim.log.levels.ERROR)
      return
    end
    -- TODO: this isn't working in C
    local has_multiple_values = #definition_match.identifier > 1

    local declaration_node ---@type TSNode?
    local identifier_node ---@type TSNode?
    local value_node ---@type TSNode?
    -- TODO: do this inside of the iter above
    for i, identifier in ipairs(definition_match.identifier) do
      local declaration = definition_match.declaration[1]
      local value = definition_match.value[i]

      local start_row, start_col, end_row, end_col = identifier:range()

      if contains({ start_row, start_col, end_row, end_col }, { definition.lnum - 1, definition.col - 1 }) then
        declaration_node = declaration
        identifier_node = identifier
        value_node = value
        break
      end
    end
    if not declaration_node or not identifier_node or not value_node then
      vim.notify("Couldn't find corredct definition on a statement with multiple values", vim.log.levels.ERROR)
      return
    end

    local value_text = ts.get_node_text(value_node, definition_buf)
    local identifier_text = ts.get_node_text(identifier_node, definition_buf)
    iter(references):each(
      ---@param reference refactor.QfItem
      function(reference)
        local buf = vim.fn.bufadd(reference.filename)
        if not api.nvim_buf_is_loaded(buf) then vim.fn.bufload(buf) end
        -- TODO: sort all text edits from the bottom-up
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

    if has_multiple_values then
      for _, node in ipairs {
        value_node,
        identifier_node,
      } do
        -- TODO: this logic is spefic to Lua, it doens't work for c and c_sharp
        local previous = node:prev_sibling()
        local next = node:next_sibling()
        local previous_anonymous = previous and not previous:named()
        local next_anonymous = next and not next:named()
        if next_anonymous then
          local start_row, start_col, end_row, end_col = next:range()
          api.nvim_buf_set_text(definition_buf, start_row, start_col, end_row, end_col, {})
        end
        local start_row, start_col, end_row, end_col = node:range()
        api.nvim_buf_set_text(definition_buf, start_row, start_col, end_row, end_col, {})
        if not next_anonymous and previous_anonymous then
          start_row, start_col, end_row, end_col = previous:range()
          api.nvim_buf_set_text(definition_buf, start_row, start_col, end_row, end_col, {})
        end
      end
    else
      local start_row, start_col, end_row, end_col = declaration_node:range()
      api.nvim_buf_set_text(definition_buf, start_row, start_col, end_row, end_col, {})
    end
  end)
  task:raise_on_error()
end

return M
