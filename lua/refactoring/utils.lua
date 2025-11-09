local api = vim.api
local async = require "async"
local range = require "refactoring.range"
local pos = require "refactoring.pos"
local lsp = vim.lsp
local iter = vim.iter
local ts = vim.treesitter

local M = {}

---@class refactor.TextEdit
---@field range vim.Range
---@field lines string[]

---@param text_edits_by_buf {[integer]: refactor.TextEdit[]}
function M.apply_text_edits(text_edits_by_buf)
  for buf, text_edits in pairs(text_edits_by_buf) do
    table.sort(text_edits, function(a, b)
      return a.range > b.range
    end)

    for _, text_edit in ipairs(text_edits) do
      local srow, scol, erow, ecol = text_edit.range:to_extmark()
      api.nvim_buf_set_text(buf, srow, scol, erow, ecol, text_edit.lines)
    end
  end
end

---@type async fun(opts: table): string
M.input = async.wrap(2, function(opts, cb)
  vim.ui.input(opts, cb)
end)

---@type async fun(items: any[], opts: table)
M.select = async.wrap(3, function(items, opts, on_choice)
  vim.ui.select(items, opts, on_choice)
end)

---@param missing_code_gen string
---@param lang string
function M.code_gen_error(missing_code_gen, lang)
  vim.notify(
    ("There's no `%s` code generation defined for language %s"):format(missing_code_gen, lang),
    vim.log.levels.ERROR
  )
end

---@param get_key nil|fun(value: any): any
---@return fun(value: any): boolean
function M.is_unique(get_key)
  ---@type {[string]: boolean}
  local already_seen = {}

  ---@param value any
  return function(value)
    local key = get_key and get_key(value) or value
    if already_seen[key] then return false end
    already_seen[key] = true
    return true
  end
end

-- NOTE: the indent logic in `vim.text.indent` counts each char as 1 indent
-- level. the indent logic in `vim.fn.indent` takes into account `expandtab`,
-- `tabstop` and `shiftwidth`.
---@param expandtab boolean
---@param size integer
---@param text string
---@param opts {expandtab: number}?
function M.indent(expandtab, size, text, opts)
  local indented, previous_size = vim.text.indent(size, text, opts)

  if not expandtab then
    indented = indented:gsub("^( +)", function(spaces)
      return ("\t"):rep(#spaces)
    end)
    indented = indented:gsub("\n( +)", function(spaces)
      return "\n" .. ("\t"):rep(#spaces)
    end)
  end
  return indented, previous_size
end

---@class refactor.QfItem
---@field filename string
---@field lnum integer
---@field end_lnum integer
---@field col integer
---@field end_col integer
---@field text string
---@field kind string?

-- TODO: cache if inside of preview. The cache key must include the buffer and
-- cursor location. Actually, the cursor position may change because of the
-- preview, so I don't think I can do that. I may have to have a single,
-- global, cache and invalidate it as soon as possible
--
-- How to invalidate the cache?
-- - it can't be invalidated when no longer in preview, because preview may be canceled
-- - it could be invalidated in a one time autocmd. What event should I use? CursorMove, CursorMoveI and ModeChange?
---@type async fun(): refactor.QfItem[]
M.get_definitions = async.wrap(1, function(cb)
  lsp.buf.definition {
    on_list = function(args)
      cb(args.items)
    end,
  }
end)

---@type async fun(): refactor.QfItem[]
M.get_references = async.wrap(1, function(cb)
  lsp.buf.references({
    includeDeclaration = false,
  }, {
    on_list = function(args)
      cb(args.items)
    end,
  })
end)

-- TODO: maybe move all scope/reference related functions into a diferent file

---@param buf integer
---@param scopes TSNode[]
---@param inner_range vim.Range
---@return TSNode|nil
local function smaller_containing_scope(buf, scopes, inner_range)
  local declaration_scope = iter(scopes)
    :filter(
      ---@param s TSNode
      function(s)
        local srow, scol, erow, ecol = s:range()
        local scope_range = range(srow, scol, erow, ecol, { buf = buf })
        return scope_range:has(inner_range)
      end
    )
    :fold(
      nil,
      ---@param acc nil|TSNode
      ---@param s TSNode
      function(acc, s)
        if not acc then return s end
        if s:byte_length() < acc:byte_length() then return s end
        return acc
      end
    )

  return declaration_scope
end

---@alias refactor.declarations_by_scope {[TSNode]: {[string]: refactor.ReferenceInfo[]}}

---@param references refactor.ReferenceInfo[]
---@param scopes TSNode[]
---@param buf integer
---@return refactor.declarations_by_scope
function M.get_declarations_by_scope(references, scopes, buf)
  local declarations_by_scope = iter(references)
    :filter(
      ---@param r refactor.ReferenceInfo
      function(r)
        return r.declaration
      end
    )
    :fold(
      {},
      ---@param acc refactor.declarations_by_scope
      ---@param d refactor.ReferenceInfo
      function(acc, d)
        local srow, scol, erow, ecol = d.identifier:range()
        local d_range = range(srow, scol, erow, ecol, { buf = buf })
        local scope = smaller_containing_scope(buf, scopes, d_range)
        local identifier = ts.get_node_text(d.identifier, buf)
        assert(scope)
        acc[scope] = acc[scope] or {}
        acc[scope][identifier] = acc[scope][identifier] or {}
        table.insert(acc[scope][identifier], d)

        return acc
      end
    )

  return declarations_by_scope
end

---@param a TSNode
---@param b TSNode
---@return boolean
local function node_comp_desc(a, b)
  local a_row, a_col, a_bytes = a:start()
  local b_row, b_col, b_bytes = b:start()
  if a_row ~= b_row then return a_row > b_row end

  return (a_col > b_col or a_col + a_bytes > b_col + b_bytes)
end

---@param declarations_by_scope refactor.declarations_by_scope
---@param all_scopes refactor.Scope[]
---@param reference refactor.ReferenceInfo
---@param buf integer
---@return TSNode|nil
function M.get_declaration_scope(declarations_by_scope, all_scopes, reference, buf)
  local srow, scol, erow, ecol = reference.identifier:range()
  local reference_range = range(srow, scol, erow, ecol, { buf = buf })
  local scopes_for_reference = M.scopes_for_range(buf, all_scopes, reference_range)
  table.sort(scopes_for_reference, node_comp_desc)

  local identifier = ts.get_node_text(reference.identifier, buf)
  local reference_start = pos(srow, scol, { buf = buf })
  return iter(scopes_for_reference):find(
    ---@param s TSNode
    function(s)
      local scope_declarations = declarations_by_scope[s]
      if not scope_declarations then return end
      local identifier_declarations = scope_declarations[identifier]
      if not identifier_declarations then return end

      return iter(identifier_declarations)
        :filter(
          ---@param d refactor.ReferenceInfo
          function(d)
            local d_srow, d_scol = d.identifier:start()
            local d_start = pos(d_srow, d_scol, { buf = buf })
            return reference_start >= d_start
          end
        )
        :fold(
          nil,
          ---@param acc refactor.ReferenceInfo|nil
          ---@param d refactor.ReferenceInfo
          function(acc, d)
            if not acc then return d end

            local d_srow, d_scol = d.identifier:start()
            local d_start = pos(d_srow, d_scol, { buf = buf })
            local acc_srow, acc_scol = d.identifier:start()
            local acc_start = pos(acc_srow, acc_scol, { buf = buf })

            local is_d_closer = M.is_first_closer(d_start, acc_start, reference_start)
            if is_d_closer then return d end
            return acc
          end
        )
    end
  )
end

---@param first vim.Pos
---@param second vim.Pos
---@param position vim.Pos
---@return boolean
function M.is_first_closer(first, second, position)
  local first_row_distance = math.abs(first.row - position.row)
  local second_row_distance = math.abs(second.row - position.row)
  if second_row_distance < first_row_distance then return false end

  local first_col_distance = math.abs(first.col - position.col)
  local second_col_distance = math.abs(second.col - position.col)
  if second_row_distance == first_row_distance and second_col_distance < first_col_distance then return false end
  return true
end

---@param buf integer
---@param all_scopes TSNode[]
---@param contained_range vim.Range
---@return TSNode[]
function M.scopes_for_range(buf, all_scopes, contained_range)
  return iter(all_scopes)
    :filter(
      ---@param s TSNode
      function(s)
        local srow, scol, erow, ecol = s:range()
        local scope_range = range(srow, scol, erow, ecol, { buf = buf })
        return scope_range:has(contained_range)
      end
    )
    :totable()
end

-- TODO: rename this everywhere (and the resulting var) to a more general name.
-- `extracted_range` comes from the `extratc_func` refactor, but it's now used
-- in multiple (all?) refactors
---@param buf integer
---@param range_type 'v' | 'V' | ''
---@return vim.Range
function M.get_extracted_range(buf, range_type)
  local range_start = api.nvim_buf_get_mark(buf, "[")
  range_start[1] = range_start[1] - 1
  local range_end = api.nvim_buf_get_mark(buf, "]")
  range_end[1] = range_end[1] - 1
  range_end[2] = range_end[2] + 1
  if range_type == "V" then
    range_start[2] = 0
    range_end[2] = #api.nvim_buf_get_lines(buf, range_end[1], range_end[1] + 1, true)[1]
  end

  return range(range_start[1], range_start[2], range_end[1], range_end[2], { buf = buf })
end

-- TODO: maybe use Info sufix for all of these types
---@class refactor.TsInfo
---@field debug_paths refactor.DebugPath[]
---@field output_statements refactor.OutputStatement[]
---@field references refactor.ReferenceInfo[]
---@field scopes refactor.Scope[]
---@field comments TSNode[]
---@field variables_info refactor.VariableInfo[]
---@field functions_info refactor.FunctionCallInfo[]
---@field function_calls_info refactor.FunctionInfo[]
---@field returns_info refactor.ReturnInfo[]
---@field outputs refactor.Output[]

-- TODO: Cache the results like on vim-matchup  to improve performance?
---@param buf integer
---@param nested_lang_tree vim.treesitter.LanguageTree
---@param query vim.treesitter.Query
---@return refactor.TsInfo
function M.get_ts_info(buf, nested_lang_tree, query)
  ---@type refactor.TsInfo
  local out = {
    -- TODO: change to a better name everywhere (debug_path_element?)
    debug_paths = {},
    output_statements = {},
    references = {},
    scopes = {},
    comments = {},
    variables_info = {},
    functions_info = {},
    function_calls_info = {},
    returns_info = {},
    outputs = {},
  }

  for _, tree in ipairs(nested_lang_tree:trees()) do
    for _, match, metadata in query:iter_matches(tree:root(), buf) do
      local output_statement ---@type nil|refactor.OutputStatement
      local scope_info ---@type refactor.Scope|nil
      local variable_info ---@type refactor.VariableInfo|nil
      local function_info ---@type nil|refactor.FunctionInfo
      local return_info ---@type nil|refactor.ReturnInfo
      local function_call_info ---@type nil|refactor.FunctionCallInfo
      local output ---@type table|refactor.Output|nil
      for capture_id, nodes in pairs(match) do
        local name = query.captures[capture_id]
        if name == "debug_path" then
          for i, node in ipairs(nodes) do
            local text = type(metadata.text) == "string" and metadata.text
              or ts.get_node_text(match[metadata.text][i], buf)
            table.insert(out.debug_paths, { debug_path = node, text = text })
          end
        end

        if name == "output_statement" then
          output_statement = output_statement or {}
          output_statement.output_statement = nodes[1]
        elseif name == "output_statement.inside" then
          output_statement = output_statement or {}
          output_statement.inside = nodes[1]
        end

        if name == "reference.identifier" then
          for i, node in ipairs(nodes) do
            table.insert(out.references, {
              identifier = node,
              reference_type = metadata.reference_type,
              type = metadata.types and metadata.types[i],
              declaration = metadata.declaration ~= nil,
            })
          end
        end

        if name == "scope" then
          scope_info = scope_info or {}
          scope_info.scope = nodes[1]
        elseif name == "scope.inside" then
          scope_info = scope_info or {}
          scope_info.inside = nodes[1]
        elseif name == "scope.outside" then
          scope_info = scope_info or {}
          scope_info.outside = nodes[1]
        end

        if name == "comment" then table.insert(out.comments, nodes[1]) end

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

        if name == "function" then
          function_info = function_info or {}
          function_info["function"] = nodes[1]
        elseif name == "function.outside" then
          function_info = function_info or {}
          function_info.outside = nodes[1]
        elseif name == "function.body" then
          function_info = function_info or {}
          function_info.body = nodes
        elseif name == "function.comment" then
          function_info = function_info or {}
          function_info.comments = nodes
        elseif name == "function.arg" then
          function_info = function_info or {}
          function_info.args = nodes
        end

        if name == "return" then
          return_info = return_info or {}
          return_info["return"] = nodes[1]
        elseif name == "return.value" then
          return_info = return_info or {}
          return_info.values = nodes
        end

        if name == "function_call" then
          function_call_info = function_call_info or {}
          function_call_info.function_call = nodes[1]
        elseif name == "function_call.name" then
          function_call_info = function_call_info or {}
          function_call_info.name = nodes[1]
        elseif name == "function_call.arg" then
          function_call_info = function_call_info or {}
          function_call_info.args = nodes
        elseif name == "function_call.return_value" then
          function_call_info = function_call_info or {}
          function_call_info.return_values = nodes
        elseif name == "function_call.outside" then
          function_call_info = function_call_info or {}
          function_call_info.outside = nodes[1]
        end

        -- TODO: split input.info and output location
        if name == "output.comment" then
          output = output or {}
          output.comment = nodes
        elseif name == "output.function" then
          output = output or {}
          output.fn = nodes[1]
          output.method = metadata.method ~= nil
          output.singleton = metadata.singleton ~= nil

          local struct_name = metadata.struct_name
          if struct_name then output.struct_name = ts.get_node_text(match[struct_name][1], buf) end
          local struct_var_name = metadata.struct_var_name
          if struct_var_name then output.struct_var_name = ts.get_node_text(match[struct_var_name][1], buf) end
        end
      end
      if output_statement then table.insert(out.output_statements, output_statement) end
      if scope_info then table.insert(out.scopes, scope_info) end
      if variable_info then table.insert(out.variables_info, variable_info) end
      if function_info then table.insert(out.functions_info, function_info) end
      if function_call_info then table.insert(out.function_calls_info, function_call_info) end
      if return_info then table.insert(out.returns_info, return_info) end
      if output then table.insert(out.outputs, output) end
    end
  end

  return out
end

return M
