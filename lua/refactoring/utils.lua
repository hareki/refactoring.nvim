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
      local srow, scol, erow, ecol = text_edit.range:to_api()
      api.nvim_buf_set_text(buf, srow, scol, erow, ecol, text_edit.lines)
    end
  end
end

---@type fun(opts: table): string
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
        local scope_range = range.treesitter(buf, s:range())
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

---@alias refactor.declarations_by_scope {[TSNode]: {[string]: refactor.Reference[]}}

---@param references refactor.Reference[]
---@param scopes TSNode[]
---@param buf integer
---@return refactor.declarations_by_scope
function M.get_declarations_by_scope(references, scopes, buf)
  local declarations_by_scope = iter(references)
    :filter(
      ---@param r refactor.Reference
      function(r)
        return r.declaration
      end
    )
    :fold(
      {},
      ---@param acc refactor.declarations_by_scope
      ---@param d refactor.Reference
      function(acc, d)
        local d_range = range.treesitter(buf, d.identifier:range())
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
---@param reference refactor.Reference
---@param buf integer
---@return TSNode|nil
function M.get_declaration_scope(declarations_by_scope, all_scopes, reference, buf)
  local reference_range = range.treesitter(buf, reference.identifier:range())
  local scopes_for_reference = M.scopes_for_range(buf, all_scopes, reference_range)
  table.sort(scopes_for_reference, node_comp_desc)

  local identifier = ts.get_node_text(reference.identifier, buf)
  local reference_start = pos.treesitter(buf, "start", reference.identifier:start())
  return iter(scopes_for_reference):find(
    ---@param s TSNode
    function(s)
      local scope_declarations = declarations_by_scope[s]
      if not scope_declarations then return end
      local identifier_declarations = scope_declarations[identifier]
      if not identifier_declarations then return end

      return iter(identifier_declarations)
        :filter(
          ---@param d refactor.Reference
          function(d)
            local d_start = pos.treesitter(buf, "start", d.identifier:start())
            return reference_start >= d_start
          end
        )
        :fold(
          nil,
          ---@param acc refactor.Reference|nil
          ---@param d refactor.Reference
          function(acc, d)
            if not acc then return d end

            local d_start = pos.treesitter(buf, "start", d.identifier:start())
            local acc_start = pos.treesitter(buf, "start", acc.identifier:start())

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
        local scope_range = range.treesitter(buf, s:range())
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
  local range_end = api.nvim_buf_get_mark(buf, "]")
  if range_type == "V" then
    range_start[2] = 0
    range_end[2] = #api.nvim_buf_get_lines(buf, range_end[1] - 1, range_end[1], true)[1]
  end

  return range.mark(buf, range_start, range_end)
end

-- TODO: rename this everywhere (and the resulting var) to a more general name.
-- `extracted_range` comes from the `extratc_func` refactor, but it's now used
-- in multiple (all?) refactors
-- TODO: inline this instead?
---@param range_type 'v'|'V'|''
function M.get_extracted_lines(range_type)
  return vim.fn.getregion(vim.fn.getpos "'[", vim.fn.getpos "']", { type = range_type })
end

return M
