local api = vim.api

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

return M
