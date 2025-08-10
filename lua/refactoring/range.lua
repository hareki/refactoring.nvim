local M = {}

---@param a Range2
---@param b Range2
---@return 1|0|-1
function M.compare(a, b)
    if a[1] < b[1] then
        return -1
    end
    if a[1] > b[1] then
        return 1
    end
    if a[1] == b[1] and a[2] < b[2] then
        return -1
    end
    if a[1] == b[1] and a[2] > b[2] then
        return 1
    end
    return 0
end

---@param range Range4
---@param point Range2
function M.contains(range, point)
    local compare_start = M.compare(point, { range[1], range[2] })
    local compare_end = M.compare(point, { range[3], range[4] })
    if compare_start == -1 or compare_end == 1 then
        return false
    end
    return true
end

return M
