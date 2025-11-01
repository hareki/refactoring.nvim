local iter = vim.iter
local ts = vim.treesitter
local api = vim.api
local async = require "async"
local pos = require "refactoring.pos"
local range = require "refactoring.range"

local M = {}

-- TODO: inlining `local ft = vim.bo.filetype` twice frozes the editor. Why?

---@param definition refactor.QfItem
---@param variables_info refactor.VariableInfo[]
---@return nil|refactor.ProcessedVariableInfo
local function get_definition_info(definition, variables_info)
  local definition_buf = vim.fn.bufadd(definition.filename)

  local definition_start = pos.vimscript(definition_buf, "start", definition.lnum, definition.col)
  ---@type refactor.ProcessedVariableInfo
  local variable_info = iter(variables_info)
    :map(
      ---@param info refactor.VariableInfo
      function(info)
        local variable_info = iter(ipairs(info.identifier))
          :filter(
            ---@param _ integer
            ---@param identifier TSNode
            function(_, identifier)
              local identifier_range = range.treesitter(definition_buf, identifier:range())
              return identifier_range:has_pos(definition_start)
            end
          )
          :map(
            ---@param i integer
            ---@param identifier TSNode
            ---@return refactor.ProcessedVariableInfo
            function(i, identifier)
              return {
                identifier = identifier,
                identifier_separator = info.identifier_separator
                  and (info.identifier_separator[i] or info.identifier_separator[i - 1]),
                value = info.value[i],
                value_separator = info.value_separator and (info.value_separator[i] or info.value_separator[i - 1]),
                -- NOTE: captures must only have one declaration
                declaration = info.declaration[1],
              }
            end
          )
          :next()
        return variable_info
      end
    )
    :filter(
      ---@param variable_info refactor.ProcessedVariableInfo
      function(variable_info)
        return variable_info ~= nil
      end
    )
    :next()

  return variable_info
end

---@class refactor.inline_var.MatchInfo
---@field variables refactor.VariableInfo[]
---@field references refactor.ReferenceInfo[]

--As a side effect, loads all the buffers for all of the definitions and references
---@param definitions refactor.QfItem[]
---@param references refactor.QfItem[]
---@param lang string
---@return nil|{[integer]: refactor.inline_var.MatchInfo}
local function get_match_info(definitions, references, lang)
  local is_unique = require("refactoring.utils").is_unique

  local query = ts.query.get(lang, "refactor")
  if not query then
    vim.notify(("There is no `refactor` query file for language %s"):format(lang), vim.log.levels.ERROR)
    return
  end

  ---@type {[integer]: refactor.inline_var.MatchInfo}
  local ts_info = iter({ definitions, references })
    :flatten(1)
    :map(
      ---@param item refactor.QfItem
      function(item)
        local buf = vim.fn.bufadd(item.filename)
        if not api.nvim_buf_is_loaded(buf) then vim.fn.bufload(buf) end
        return buf
      end
    )
    :filter(is_unique())
    :map(
      ---@param buf integer
      function(buf)
        local lang_tree, err2 = ts.get_parser(buf, lang, { error = false })
        if not lang_tree then
          vim.notify(err2, vim.log.levels.ERROR)
          return
        end

        local variables_info = {} ---@type refactor.VariableInfo[]
        local references_info = {} ---@type refactor.ReferenceInfo[]
        for _, tree in ipairs(lang_tree:trees()) do
          for _, match, metadata in query:iter_matches(tree:root(), buf) do
            local variable_info ---@type refactor.VariableInfo|nil
            for capture_id, nodes in pairs(match) do
              local name = query.captures[capture_id]

              if name == "variable.identifier" then
                variable_info = variable_info or {}
                variable_info.identifier = nodes
              elseif name == "variable.identifier_separator" then
                variable_info = variable_info or {}
                variable_info.identifier_separator = nodes
              elseif name == "variable.value_separator" then
                variable_info = variable_info or {}
                variable_info.value_separator = nodes
              elseif name == "variable.value" then
                variable_info = variable_info or {}
                variable_info.value = nodes
              elseif name == "variable.declaration" then
                variable_info = variable_info or {}
                variable_info.declaration = nodes
              end

              if name == "reference.identifier" then
                for i, node in ipairs(nodes) do
                  table.insert(references_info, {
                    identifier = node,
                    reference_type = metadata.reference_type,
                    type = metadata.types and metadata.types[i],
                    declaration = metadata.declaration ~= nil,
                  })
                end
              end
            end
            if variable_info then table.insert(variables_info, variable_info) end
          end
        end

        return buf, { variables = variables_info, references = references_info }
      end
    )
    :fold(
      {},
      ---@param acc {[integer]: refactor.inline_var.MatchInfo}
      ---@param k integer
      ---@param v nil|refactor.inline_var.MatchInfo
      function(acc, k, v)
        acc[k] = v
        return acc
      end
    )
  return ts_info
end

---@class refactor.VariableInfo
---@field identifier TSNode[]
---@field identifier_separator TSNode[]|nil
---@field value TSNode[]
---@field value_separator TSNode[]|nil
---@field declaration TSNode[]

---@class refactor.ProcessedVariableInfo
---@field identifier TSNode
---@field identifier_separator TSNode|nil
---@field value TSNode
---@field value_separator TSNode|nil
---@field declaration TSNode

-- TODO: success message (can be disabled in config)
---@param config refactor.Config
function M.inline_var(_, config)
  local apply_text_edits = require("refactoring.utils").apply_text_edits
  local is_unique = require("refactoring.utils").is_unique
  local select = require("refactoring.utils").select
  local get_definitions = require("refactoring.utils").get_definitions
  local get_references = require("refactoring.utils").get_references

  local opts = config.refactor.inline_var

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

    local ts_info = get_match_info(definitions, references, lang)
    if not ts_info then return end

    ---@type {definition: refactor.QfItem, info: refactor.ProcessedVariableInfo}[]
    local definitions_with_info = iter(definitions)
      :map(
        ---@param d refactor.QfItem
        function(d)
          local definition_buf = vim.fn.bufadd(d.filename)
          local variables_info = ts_info[definition_buf].variables
          local definition_info = get_definition_info(d, variables_info)
          return { definition = d, info = definition_info }
        end
      )
      :filter(
        ---@param dwi {definition: refactor.QfItem, info: refactor.ProcessedVariableInfo|nil}
        function(dwi)
          return dwi.info ~= nil
        end
      )
      :totable()

    if #definitions_with_info == 0 then
      vim.notify("Couldn't find the definition of the symbol under cursor using treesitter", vim.log.levels.ERROR)
      return
    end
    local definition_with_info = #definitions_with_info == 1 and definitions_with_info[1]
      or select(definitions_with_info, {
        prompt = "Mutliple definitions found, select one",
        format_item =
          ---@param item {definition: refactor.QfItem, info: refactor.ProcessedVariableInfo}
          function(item)
            local buf = vim.fn.bufadd(item.definition.filename)
            return ts.get_node_text(item.info.declaration, buf)
          end,
      })
    if not definition_with_info then return end

    local definition, definition_info = definition_with_info.definition, definition_with_info.info
    local definition_buf = vim.fn.bufadd(definition.filename)
    local definition_start = pos.vimscript(definition_buf, "start", definition.lnum, definition.col)

    ---@type {reference: refactor.QfItem, info: refactor.ReferenceInfo|nil}[]
    local references_with_info = iter(references)
      :filter(is_unique(
        ---@param r refactor.QfItem
        function(r)
          return ("%d-%d-%d-%d"):format(r.lnum, r.col, r.end_lnum, r.end_col)
        end
      ))
      :filter(
        ---@param r refactor.QfItem
        function(r)
          local r_buf = vim.fn.bufadd(r.filename)
          if r_buf ~= definition_buf then return true end

          local r_range = range.vimscript(r_buf, r.lnum, r.col, r.end_lnum, r.end_col)
          return not r_range:has_pos(definition_start)
        end
      )
      :map(
        ---@param r refactor.QfItem
        function(r)
          local reference_buf = vim.fn.bufadd(r.filename)
          local reference_range = range.vimscript(reference_buf, r.lnum, r.col, r.end_lnum, r.end_col)

          local references_info = ts_info[reference_buf].references
          local reference_info = iter(references_info):find(
            ---@param ri refactor.ReferenceInfo
            function(ri)
              local identifier_range = range.treesitter(reference_buf, ri.identifier:range())
              return identifier_range:has(reference_range)
            end
          )

          return { reference = r, info = reference_info }
        end
      )
      :filter(
        ---@param rwi {reference: refactor.QfItem, info: refactor.ReferenceInfo|nil}
        function(rwi)
          return rwi.info ~= nil
        end
      )
      :totable()

    local declaration_node = definition_info.declaration
    local identifier_node = definition_info.identifier
    local value_node = definition_info.value

    local value_text = ts.get_node_text(value_node, definition_buf)

    ---@type {[integer]: refactor.TextEdit[]}
    local text_edits_by_buf = {}
    iter(references_with_info):each(
      ---@param rwi {reference: refactor.QfItem, info: refactor.ReferenceInfo|nil}
      function(rwi)
        local reference = rwi.reference
        local buf = vim.fn.bufadd(reference.filename)
        local identifier_range = range.treesitter(buf, rwi.info.identifier:range())

        text_edits_by_buf[buf] = text_edits_by_buf[buf] or {}
        table.insert(text_edits_by_buf[buf], {
          range = identifier_range,
          lines = vim.split(value_text, "\n"),
        })
      end
    )

    -- TODO: these `text_edit`s only clean the line, they don't remove it.
    -- Remove it instead. Do the same thing in `inline_func`
    if definition_info.value_separator or definition_info.identifier_separator then
      iter({
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
            return range.treesitter(definition_buf, n:range())
          end
        )
        :each(
          ---@param r vim.Range
          function(r)
            text_edits_by_buf[definition_buf] = text_edits_by_buf[definition_buf] or {}
            table.insert(text_edits_by_buf[definition_buf], { range = r, lines = {} })
          end
        )
    else
      local declaration_range = range.treesitter(definition_buf, declaration_node:range())

      text_edits_by_buf[definition_buf] = text_edits_by_buf[definition_buf] or {}
      table.insert(text_edits_by_buf[definition_buf], { range = declaration_range, lines = {} })
    end

    apply_text_edits(text_edits_by_buf)
  end)
  task:raise_on_error()
end

return M
