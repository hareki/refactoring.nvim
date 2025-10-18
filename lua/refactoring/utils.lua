local api = vim.api
local async = require "async"
local lsp = vim.lsp
local iter = vim.iter
local ts = vim.treesitter

local M = {}

---@class refactor.TextEdit
---@field range Range4
---@field lines string[]

---@param a refactor.TextEdit
---@param b refactor.TextEdit
local function comp_non_overlaping_text_edits_desc(a, b)
  local comp_non_overlaping_ranges_desc = require("refactoring.range").comp_non_overlaping_ranges_desc

  return comp_non_overlaping_ranges_desc(a.range, b.range)
end

---@param text_edits_by_buf {[integer]: refactor.TextEdit[]}
function M.apply_text_edits(text_edits_by_buf)
  for buf, text_edits in pairs(text_edits_by_buf) do
    table.sort(text_edits, comp_non_overlaping_text_edits_desc)

    for _, text_edit in ipairs(text_edits) do
      api.nvim_buf_set_text(
        buf,
        text_edit.range[1],
        text_edit.range[2],
        text_edit.range[3],
        text_edit.range[4],
        text_edit.lines
      )
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

---@param scopes TSNode[]
---@param start Range2
---@param end_ Range2
---@return TSNode|nil
local function smaller_containing_scope(scopes, start, end_)
  local contains = require("refactoring.range").contains

  local declaration_scope = iter(scopes)
    :filter(
      ---@param s TSNode
      function(s)
        local scope_range = { s:range() }
        return contains(scope_range, start) and contains(scope_range, end_)
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
        local start_row, start_col, end_row, end_col = d.identifier:range()
        local scope = smaller_containing_scope(scopes, { start_row, start_col }, { end_row, end_col })
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
  local compare = require("refactoring.range").compare

  local reference_range = { reference.identifier:range() }
  local scopes_for_reference = M.scopes_for_range(all_scopes, reference_range)
  table.sort(scopes_for_reference, node_comp_desc)

  local identifier = ts.get_node_text(reference.identifier, buf)
  local reference_start_row, reference_start_col = reference.identifier:start()
  local reference_start = { reference_start_row, reference_start_col }
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
            local d_start_row, d_start_col = d.identifier:start()
            return compare(reference_start, { d_start_row, d_start_col }) ~= -1
          end
        )
        :fold(
          nil,
          ---@param acc refactor.Reference|nil
          ---@param d refactor.Reference
          function(acc, d)
            if not acc then return d end

            local d_start_row, d_start_col = d.identifier:start()
            local acc_start_row, acc_start_col = acc.identifier:start()

            local is_d_closer = M.is_first_closer(
              { d_start_row, d_start_col },
              { acc_start_row, acc_start_col },
              reference_start
            )
            if is_d_closer then return d end
            return acc
          end
        )
    end
  )
end

---@param first Range2
---@param second Range2
---@param range Range2
---@return boolean
function M.is_first_closer(first, second, range)
  local first_row_distance = math.abs(first[1] - range[1])
  local second_row_distance = math.abs(second[1] - range[1])
  if second_row_distance < first_row_distance then return false end

  local first_col_distance = math.abs(first[2] - range[2])
  local second_col_distance = math.abs(second[2] - range[2])
  if second_row_distance == first_row_distance and second_col_distance < first_col_distance then return false end
  return true
end

---@param all_scopes TSNode[]
---@param range Range4
---@return TSNode[]
function M.scopes_for_range(all_scopes, range)
  local contains = require("refactoring.range").contains

  return iter(all_scopes)
    :filter(
      ---@param s TSNode
      function(s)
        local scope_range = { s:range() }
        return contains(scope_range, { range[1], range[2] }) and contains(scope_range, { range[3], range[4] })
      end
    )
    :totable()
end

return M
