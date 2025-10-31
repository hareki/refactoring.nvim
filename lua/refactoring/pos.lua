---@brief
---
--- EXPERIMENTAL: This API may change in the future. Its semantics are not yet finalized.
--- Subscribe to https://github.com/neovim/neovim/issues/25509
--- to stay updated or contribute to its development.
---
--- Provides operations to compare, calculate, and convert positions represented by |vim.Pos|
--- objects.

local api = vim.api
local validate = vim.validate

---@alias vim.Pos.Type 'start'|'end'

--- Represents a well-defined position.
---
--- A |vim.Pos| object contains the {row} and {col} coordinates of a position.
--- To create a new |vim.Pos| object, call `vim.pos()`.
---
--- Example:
--- ```lua
--- local pos1 = vim.pos(3, 5)
--- local pos2 = vim.pos(4, 0)
---
--- -- Operators are overloaded for comparing two `vim.Pos` objects.
--- if pos1 < pos2 then
---   print("pos1 comes before pos2")
--- end
---
--- if pos1 ~= pos2 then
---   print("pos1 and pos2 are different positions")
--- end
--- ```
---
--- It may include optional fields that enable additional capabilities,
--- such as format conversions.
---
---@class vim.Pos
---@field row integer 0-based byte index.
---@field col integer 0-based byte index.
---
--- Optional buffer handle.
---
--- When specified, it indicates that this position belongs to a specific buffer.
--- This field is required when performing position conversions.
---@field buf? integer
---
--- Optional type.
---
--- When specified, it indicates the type of this position.
--- This field is required when performing position conversions and comparisons.
---@field type? vim.Pos.Type
local Pos = {}
Pos.__index = Pos

---@class vim.Pos.Optional
---@inlinedoc
---@field buf? integer
---@field type? vim.Pos.Type

---@package
---@param row integer
---@param col integer
---@param opts? vim.Pos.Optional
function Pos.new(row, col, opts)
  validate("row", row, "number")
  validate("col", col, "number")
  validate("opts", opts, "table", true)

  opts = opts or {}

  ---@type vim.Pos
  local self = setmetatable({
    row = row,
    col = col,
    buf = opts.buf,
    type = opts.type,
  }, Pos)

  return self
end

---@param p1_row integer Row of first position to compare.
---@param p1_col integer Col of first position to compare.
---@param p2_row integer Row of second position to compare.
---@param p2_col integer Col of second position to compare.
---@return integer
--- 1: a > b
--- 0: a == b
--- -1: a < b
local function cmp_pos(p1_row, p1_col, p2_row, p2_col)
  if p1_row == p2_row then
    if p1_col > p2_col then
      return 1
    elseif p1_col < p2_col then
      return -1
    else
      return 0
    end
  elseif p1_row > p2_row then
    return 1
  end

  return -1
end

--- TODO(ofseed): Make it work for unloaded buffers. Check get_line() in vim.lsp.util.
---@param buf integer
---@param row integer
local function get_line(buf, row)
  return api.nvim_buf_get_lines(buf, row, row + 1, true)[1]
end

---@private
---@param pos vim.Pos
---@return integer, integer
local function to_inclusive_pos(pos)
  local col = pos.col
  local row = pos.row
  if pos.type == "end" and pos.col > 0 then
    col = col - 1
  elseif pos.type == "end" and pos.col == 0 and pos.row > 0 then
    row = row - 1
    col = #get_line(pos.buf, row)
  end

  return row, col
end

---@private
---@param p1 vim.Pos
---@param p2 vim.Pos
function Pos.__lt(p1, p2)
  local p1_row, p1_col = to_inclusive_pos(p1)
  local p2_row, p2_col = to_inclusive_pos(p2)
  return cmp_pos(p1_row, p1_col, p2_row, p2_col) == -1
end

---@private
---@param p1 vim.Pos
---@param p2 vim.Pos
function Pos.__le(p1, p2)
  local p1_row, p1_col = to_inclusive_pos(p1)
  local p2_row, p2_col = to_inclusive_pos(p2)
  return cmp_pos(p1_row, p1_col, p2_row, p2_col) ~= 1
end

---@private
---@param p1 vim.Pos
---@param p2 vim.Pos
function Pos.__eq(p1, p2)
  local p1_row, p1_col = to_inclusive_pos(p1)
  local p2_row, p2_col = to_inclusive_pos(p2)
  return cmp_pos(p1_row, p1_col, p2_row, p2_col) == 0
end

--- Converts |vim.Pos| to `lsp.Position`.
---
--- Example:
--- ```lua
--- -- `buf` is required for conversion to LSP position.
--- local buf = vim.api.nvim_get_current_buf()
--- local pos = vim.pos(3, 5, { buf = buf })
---
--- -- Convert to LSP position, you can call it in a method style.
--- local lsp_pos = pos:lsp('utf-16')
--- ```
---@param pos vim.Pos
---@param position_encoding lsp.PositionEncodingKind
function Pos.to_lsp(pos, position_encoding)
  validate("pos", pos, "table")
  validate("position_encoding", position_encoding, "string")

  local buf = assert(pos.buf, "position is not a buffer position")
  local row, col = pos.row, pos.col
  -- When on the first character,
  -- we can ignore the difference between byte and character.
  if col > 0 then col = vim.str_utfindex(get_line(buf, row), position_encoding, col, false) end

  ---@type lsp.Position
  return { line = row, character = col }
end

--- Creates a new |vim.Pos| from `lsp.Position`.
---
--- Example:
--- ```lua
--- local buf = vim.api.nvim_get_current_buf()
--- local lsp_pos = {
---   line = 3,
---   character = 5
--- }
---
--- -- `buf` is mandatory, as LSP positions are always associated with a buffer.
--- local pos = vim.pos.lsp(buf, lsp_pos, 'utf-16')
--- ```
---@param buf integer
---@param pos lsp.Position
---@param position_encoding lsp.PositionEncodingKind
function Pos.lsp(buf, pos, position_encoding)
  validate("buf", buf, "number")
  validate("pos", pos, "table")
  validate("position_encoding", position_encoding, "string")

  local row, col = pos.line, pos.character
  -- When on the first character,
  -- we can ignore the difference between byte and character.
  if col > 0 then
    -- `strict_indexing` is disabled, because LSP responses are asynchronous,
    -- and the buffer content may have changed, causing out-of-bounds errors.
    col = vim.str_byteindex(get_line(buf, row), position_encoding, col, false)
  end

  return Pos.new(row, col, { buf = buf })
end

--- Converts |vim.Pos| to cursor position.
---@param pos vim.Pos
---@return [integer, integer]
function Pos.to_cursor(pos)
  return { pos.row + 1, pos.col }
end

--- Creates a new |vim.Pos| from cursor position.
---@param pos [integer, integer]
function Pos.cursor(pos)
  return Pos.new(pos[1] - 1, pos[2])
end

--- Converts |vim.Pos| to extmark position.
---@param pos vim.Pos
---@return [integer, integer]
function Pos.to_extmark(pos)
  return { pos.row, pos.col }
end

--- Creates a new |vim.Pos| from extmark position.
---@param pos [integer, integer]
function Pos.extmark(pos)
  local row, col = unpack(pos)
  return Pos.new(row, col)
end

--- Converts |vim.Pos| to treesitter position.
---@param pos vim.Pos
---@return integer, integer
function Pos.to_treesitter(pos)
  local col = pos.col
  local row = pos.row
  if pos.type == "end" and col == 0 then
    row = row - 1
    col = #get_line(pos.buf, row)
  end
  return row, col
end

--- Creates a new |vim.Pos| from treesitter position.
---@param buf integer
---@param type vim.Pos.Type
---@param row integer
---@param col integer
function Pos.treesitter(buf, type, row, col)
  validate("buf", buf, "number")
  validate("row", row, "number")
  validate("col", col, "number")

  -- TODO(TheLeoP): we are technically losing information here. Treesitter has
  -- both kind of end indexing (row_incluvsive-col_exclusive and
  -- row_exclusive-col_0). But, does it matter in practice?
  if type == "end" and col > 0 and col == #get_line(buf, row) then
    row = row + 1
    col = 0
  end

  return Pos.new(row, col, { buf = buf, type = type })
end

-- TODO(TheLeoP): does this one require a mandatory `buf`?
--- Creates a new |vim.Pos| from vimscript (|builtin-functions|) position.
---@param buf integer
---@param lnum integer 1-based
---@param col integer 1-based
function Pos.vimscript(buf, type, lnum, col)
  validate("buf", buf, "number")
  validate("type", type, "string")
  validate("lnum", lnum, "number")
  validate("col", col, "number")

  if col == vim.v.maxcol then
    col = 0
  else
    lnum = lnum - 1
    col = col - 1
  end

  return Pos.new(lnum, col, { buf = buf, type = type })
end

-- TODO(TheLeoP): should we have an optional parameter `range_type` (line, block, char) and modify
-- the range depending on it?
--- Creates a new |vim.Pos| from mark-like position.
---@param buf integer
---@param type vim.Pos.Type
---@param range [integer, integer]
function Pos.mark(buf, type, range)
  validate("buf", buf, "number")
  validate("range", range, "table")

  local row, col = unpack(range)
  if type == "start" then
    row = row - 1
  elseif type == "end" then
    local row_length = #get_line(buf, row - 1)
    col = math.min(row_length, col + 1)
    if col == row_length then
      col = 0
    elseif col ~= 0 then
      row = row - 1
    end
  end

  return Pos.new(row, col, { buf = buf, type = type })
end

--- Converts |vim.Pos| to |api-indexing| position.
---@param pos vim.Pos
---@return integer, integer
function Pos.to_api(pos)
  local col = pos.col
  local row = pos.row
  if pos.type == "end" and col == 0 then
    row = row - 1
    col = #get_line(pos.buf, row)
  end
  return row, col
end

--- Creates a new |vim.Pos| from |api-indexing| position.
---@param buf integer
---@param type vim.Pos.Type
---@param row integer
---@param col integer
function Pos.api(buf, type, row, col)
  validate("buf", buf, "number")
  validate("row", row, "number")
  validate("col", col, "number")

  if type == "end" and col == #get_line(buf, row) then
    row = row + 1
    col = 0
  end

  return Pos.new(row, col, { buf = buf, type = type })
end

-- Overload `Range.new` to allow calling this module as a function.
setmetatable(Pos, {
  __call = function(_, ...)
    return Pos.new(...)
  end,
})
---@cast Pos +fun(row: integer, col: integer, opts: vim.Pos.Optional?): vim.Pos

return Pos
