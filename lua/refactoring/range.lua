local M = {}

---@param a Range2
---@param b Range2
---@return 1|0|-1
function M.compare(a, b)
  if a[1] < b[1] then return -1 end
  if a[1] > b[1] then return 1 end
  if a[1] == b[1] and a[2] < b[2] then return -1 end
  if a[1] == b[1] and a[2] > b[2] then return 1 end
  return 0
end

---@param range Range4
---@param point Range2
function M.contains(range, point)
  local compare_start = M.compare(point, { range[1], range[2] })
  local compare_end = M.compare(point, { range[3], range[4] })
  if compare_start == -1 or compare_end == 1 then return false end
  return true
end

---@param range_type 'v'|'V'|''
---@return Range4, string[]
function M.get_extracted_range(range_type)
  local range_start = vim.fn.getpos "'["
  local range_end = vim.fn.getpos "']"
  local range_last_line_length = #vim.fn.getline "']"

  local extracted_range = {
    range_start[2] - 1,
    range_type ~= "V" and range_start[3] - 1 or 0,
    range_end[2] - 1,
    range_type ~= "V" and range_end[3] - 1 or range_last_line_length,
  }
  local lines = vim.fn.getregion(range_start, range_end, { type = range_type })

  return extracted_range, lines
end

---@param a Range4
---@param b Range4
function M.comp_non_overlaping_ranges_desc(a, b)
  local compare_start = M.compare({ a[1], a[2] }, { b[1], b[2] })
  if compare_start == 1 then return true end
  if compare_start == -1 then return false end

  local compare_end = M.compare({ a[3], a[4] }, { b[3], b[4] })
  return compare_end == 1
end

return M
