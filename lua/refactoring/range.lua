---@brief
---
--- EXPERIMENTAL: This API may change in the future. Its semantics are not yet finalized.
--- Subscribe to https://github.com/neovim/neovim/issues/25509
--- to stay updated or contribute to its development.
---
--- Provides operations to compare, calculate, and convert ranges represented by |vim.Range|
--- objects.

local api = vim.api
local validate = vim.validate
local pos = require "refactoring.pos"

--- TODO(ofseed): Make it work for unloaded buffers. Check get_line() in vim.lsp.util.
---@param buf integer
---@param row integer
local function get_line(buf, row)
  return api.nvim_buf_get_lines(buf, row, row + 1, true)[1]
end

--- Represents a well-defined range.
---
--- A |vim.Range| object contains a {start} and a {end_} position(see |vim.Pos|).
--- Note that the {end_} position is exclusive (row-exclusive_col-0).
--- To create a new |vim.Range| object, call `vim.range()`.
---
--- Example:
--- ```lua
--- local pos1 = vim.pos(3, 5)
--- local pos2 = vim.pos(4, 0)
---
--- -- Create a range from two positions.
--- local range1 = vim.range(pos1, pos2)
--- -- Or create a range from four integers representing start and end positions.
--- local range2 = vim.range(3, 5, 4, 0)
---
--- -- Because `vim.Range` is end exclusive, `range1` and `range2` both represent
--- -- a range starting at the row 3, column 5 and ending at where the row 3 ends.
---
--- -- Operators are overloaded for comparing two `vim.Pos` objects.
--- if range1 == range2 then
---   print("range1 and range2 are the same range")
--- end
--- ```
---
--- It may include optional fields that enable additional capabilities,
--- such as format conversions. Note that the {start} and {end_} positions
--- need to have the same optional fields.
---
---@class vim.Range
---@field start vim.Pos Start position.
---@field end_ vim.Pos End position, exclusive.
local Range = {}
Range.__index = Range

---@class vim.Range.Optional
---@inlinedoc
---@field buf? integer

---@package
---@overload fun(self: vim.Range, start: vim.Pos, end_: vim.Pos): vim.Range
---@overload fun(self: vim.Range, start_row: integer, start_col: integer, end_row: integer, end_col: integer, opts?: vim.Range.Optional): vim.Range
function Range.new(...)
  ---@type vim.Pos, vim.Pos
  local start, end_

  local nargs = select("#", ...)
  if nargs == 2 then
    ---@type vim.Pos, vim.Pos
    start, end_ = ...
    validate("start", start, "table")
    validate("end_", end_, "table")

    if start.buf ~= end_.buf then error "start and end positions must belong to the same buffer" end
  elseif nargs == 4 or nargs == 5 then
    ---@type integer, integer, integer, integer, vim.Range.Optional
    local start_row, start_col, end_row, end_col, opts = ...
    start, end_ =
      pos(start_row, start_col, { buf = opts.buf, type = "start" }),
      pos(end_row, end_col, { buf = opts.buf, type = "end" })
  else
    error "invalid parameters"
  end

  ---@type vim.Range
  local self = setmetatable({
    start = start,
    end_ = end_,
  }, Range)

  return self
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function Range.__lt(r1, r2)
  return r1.end_ < r2.start
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function Range.__le(r1, r2)
  return r1.end_ <= r2.start
end

---@private
---@param r1 vim.Range
---@param r2 vim.Range
function Range.__eq(r1, r2)
  return r1.start == r2.start and r1.end_ == r2.end_
end

--- Checks whether {outer} range contains {inner} range.
---
---@param outer vim.Range
---@param inner vim.Range
---@return boolean `true` if {outer} range fully contains {inner} range.
function Range.has(outer, inner)
  return outer.start <= inner.start and outer.end_ >= inner.end_
end

--- Checks whether {outer} range contains {pos}.
---
---@param outer vim.Range
---@param pos vim.Pos
---@return boolean `true` if {outer} range fully contains {post}.
function Range.has_pos(outer, pos)
  return outer.start <= pos and outer.end_ >= pos
end

--- Computes the common range shared by the given ranges.
---
---@param r1 vim.Range First range to intersect.
---@param r2 vim.Range Second range to intersect
---@return vim.Range? range that is present inside both `r1` and `r2`.
---                   `nil` if such range does not exist.
function Range.intersect(r1, r2)
  if r1.end_ <= r2.start or r1.start >= r2.end_ then return nil end
  local rs = r1.start <= r2.start and r2 or r1
  local re = r1.end_ >= r2.end_ and r2 or r1
  return Range.new(rs.start, re.end_)
end

--- Converts |vim.Range| to `lsp.Range`.
---
--- Example:
--- ```lua
--- -- `buf` is required for conversion to LSP range.
--- local buf = vim.api.nvim_get_current_buf()
--- local range = vim.range(3, 5, 4, 0, { buf = buf })
---
--- -- Convert to LSP range, you can call it in a method style.
--- local lsp_range = range:to_lsp('utf-16')
--- ```
---@param range vim.Range
---@param position_encoding lsp.PositionEncodingKind
function Range.to_lsp(range, position_encoding)
  validate("range", range, "table")
  validate("position_encoding", position_encoding, "string", true)

  ---@type lsp.Range
  return {
    ["start"] = range.start:to_lsp(position_encoding),
    ["end"] = range.end_:to_lsp(position_encoding),
  }
end

--- Creates a new |vim.Range| from `lsp.Range`.
---
--- Example:
--- ```lua
--- local buf = vim.api.nvim_get_current_buf()
--- local lsp_range = {
---   ['start'] = { line = 3, character = 5 },
---   ['end'] = { line = 4, character = 0 }
--- }
---
--- -- `buf` is mandatory, as LSP ranges are always associated with a buffer.
--- local range = vim.range.lsp(buf, lsp_range, 'utf-16')
--- ```
---@param buf integer
---@param range lsp.Range
---@param position_encoding lsp.PositionEncodingKind
function Range.lsp(buf, range, position_encoding)
  validate("buf", buf, "number")
  validate("range", range, "table")
  validate("position_encoding", position_encoding, "string")

  -- TODO(ofseed): avoid using `Pos:lsp()` here,
  -- as they need reading files separately if buffer is unloaded.
  local start = pos.lsp(buf, range["start"], position_encoding)
  local end_ = pos.lsp(buf, range["end"], position_encoding)

  return Range.new(start, end_)
end

--- Converts |vim.Range| to `integer, integer, integer, integer` equivalent to the result of |TSNode:range()|.
---
--- Example:
--- ```lua
--- -- `buf` is required for conversion to Treesitter range.
--- local buf = vim.api.nvim_get_current_buf()
--- local range = vim.range(3, 5, 4, 0, { buf = buf })
---
--- -- Convert to Treesitter range, you can call it in a method style.
--- local start_row, start_col, end_row, end_col = range:to_treesitter()
--- ```
---@param range vim.Range
---@return integer, integer, integer, integer
function Range.to_treesitter(range)
  validate("range", range, "table")

  local start_row, start_col = range.start:to_treesitter()
  local end_row, end_col = range.end_:to_treesitter()

  return start_row, start_col, end_row, end_col
end

--- Creates a new |vim.Range| from the result of |TSNode:range()|.
---
--- Example:
--- ```lua
--- local buf = vim.api.nvim_get_current_buf()
---
--- -- `buf` is mandatory, as Treesitter ranges are always associated with a buffer.
--- local range = vim.range.treesitter(buf, vim.treesitter.get_node():range())
--- ```
---@param buf integer
---@param srow integer
---@param scol integer
---@param erow integer
---@param ecol integer
function Range.treesitter(buf, srow, scol, erow, ecol)
  validate("buf", buf, "number")
  validate("srow", srow, "number")
  validate("scol", scol, "number")
  validate("erow", erow, "number")
  validate("ecol", ecol, "number")

  local start = pos.treesitter(buf, "start", srow, scol)
  -- TODO(TheLeoP): should this be done on `vim.Pos.treesitter_start`? it would need to know about `end_`
  if ecol == 0 and srow == erow then
    start.row = start.row - 1
    start.col = #get_line(buf, start.row)
  end
  local end_ = pos.treesitter(buf, "end", erow, ecol)

  return Range.new(start, end_)
end

--- Converts |vim.Range| to `integer, integer, integer, integer` following |api-indexing|.
---
--- Example:
--- ```lua
--- -- `buf` is required for conversion to LSP range.
--- local buf = vim.api.nvim_get_current_buf()
--- local range = vim.range(3, 5, 4, 0, { buf = buf })
---
--- -- Convert to API range, you can call it in a method style.
--- local start_row, start_col, end_row, end_col = range:to_api()
--- ```
---@param range vim.Range
---@return integer, integer, integer, integer
function Range.to_api(range)
  validate("range", range, "table")

  local end_row, end_col = range.end_.row, range.end_.col
  if range.start.row == range.end_.row and range.start.col == range.end_.col then
  elseif end_col == 0 then
    end_row = end_row - 1
    end_col = #get_line(range.end_.buf, end_row)
  end
  return range.start.row, range.start.col, end_row, end_col
end

--- Creates a new |vim.Range| from |api-indexing|.
---
--- Example:
--- ```lua
--- local buf = vim.api.nvim_get_current_buf()
---
--- -- `buf` is mandatory, as Treesitter ranges are always associated with a buffer.
--- local range = vim.range.treesitter(buf, vim.treesitter.get_node():range())
--- local _, _, erow, ecol = range:api()
--- local insert_at_end_range = vim.range.api(buf, erow, ecol, erow, ecol)
--- ```
---@param buf integer
---@param srow integer
---@param scol integer
---@param erow integer
---@param ecol integer
function Range.api(buf, srow, scol, erow, ecol)
  validate("buf", buf, "number")
  validate("srow", srow, "number")
  validate("scol", scol, "number")
  validate("erow", erow, "number")
  validate("ecol", ecol, "number")

  local start = pos.api(buf, "start", srow, scol)
  ---@type vim.Pos
  local end_
  if srow == erow and scol == ecol then
    end_ = pos(erow, ecol, { buf = buf, type = "end" })
  else
    end_ = pos.api(buf, "end", erow, ecol)
  end

  return Range.new(start, end_)
end

--- Converts |vim.Range| to `integer, integer, integer, integer` that follow extkmark indexing.
---
--- Example:
--- ```lua
--- -- `buf` is required for conversion to LSP range.
--- local buf = vim.api.nvim_get_current_buf()
--- local range = vim.range(3, 5, 4, 0, { buf = buf })
---
--- -- Convert to extmark range, you can call it in a method style.
--- local start_row, start_col, end_row, end_col = range:to_extmark()
--- ```
---@param range vim.Range
---@return integer, integer, integer, integer
function Range.to_extmark(range)
  validate("range", range, "table")

  local end_row, end_col = range.end_.row, range.end_.col
  if end_col == 0 then
    end_row = end_row - 1
    end_col = #get_line(range.end_.buf, range.end_.row) + 1
  end
  return range.start.row, range.start.col, end_row, end_col
end

-- TODO(TheLeoP): should support tuple-like {bufnum, lnum, col, off} like the
-- return value of |getpos()|? Or maybe split into `range.qfitem` and
-- `range.getpos` or something like that
--- Creates a new |vim.Range| from the result of |TSNode:range()|.
---
--- Creates a new |vim.Range| from vimscript (|builtin-functions|).
---
--- Example:
--- ```lua
--- local buf = vim.api.nvim_get_current_buf()
--- local treesitter_range = { vim.treesitter.get_node():range() }
---
--- -- `buf` is mandatory, as Treesitter ranges are always associated with a buffer.
--- local range = vim.range.treesitter(buf, lsp_range)
--- ```
---@param buf integer
---@param lnum integer
---@param col integer
---@param end_lnum integer
---@param end_col integer
function Range.vimscript(buf, lnum, col, end_lnum, end_col)
  validate("buf", buf, "number")
  validate("srow", lnum, "number")
  validate("scol", col, "number")
  validate("erow", end_lnum, "number")
  validate("ecol", end_col, "number")

  local start = pos.vimscript(buf, "start", lnum, col)
  local end_ = pos.vimscript(buf, "end", end_lnum, end_col)

  return Range.new(start, end_)
end

--- Example:
--- ```lua
--- local buf = vim.api.nvim_get_current_buf()
--- local range_start = vim.api.nvim_buf_get_mark(buf, "[")
--- local range_end = vim.api.nvim_buf_get_mark(buf, "]")
---
--- -- `buf` is mandatory, as Treesitter ranges are always associated with a mark.
--- local range = vim.range.treesitter(buf, lsp_range)
--- ```
---@param buf integer
---@param start [integer, integer]
---@param end_ [integer, integer]
function Range.mark(buf, start, end_)
  validate("buf", buf, "number")
  validate("srow", start, "table")
  validate("scol", end_, "table")

  return Range.new(pos.mark(buf, "start", start), pos.mark(buf, "end", end_))
end

-- Overload `Range.new` to allow calling this module as a function.
setmetatable(Range, {
  __call = function(_, ...)
    return Range.new(...)
  end,
})
---@cast Range +fun(start: vim.Pos, end_: vim.Pos): vim.Range
---@cast Range +fun(start_row: integer, start_col: integer, end_row: integer, end_col: integer, opts?: vim.Pos.Optional): vim.Range

return Range
