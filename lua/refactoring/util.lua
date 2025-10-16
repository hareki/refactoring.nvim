local api = vim.api
local async = require "async"
local lsp = vim.lsp

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

return M
