local M = {}

---@class refactor.debug.Opts
---@field output_location 'above'|'below'

---@alias refactor.DebugFunc fun(type: 'v' | 'V' | '', opts: refactor.debug.Opts?)

local last_debug ---@type refactor.DebugFunc|nil
local last_opts ---@type refactor.debug.Opts|nil

---@param type "line" | "char" | "block"
function M.debug_operatorfunc(type)
  if not last_debug then return end

  local range_type = type == "line" and "V" or type == "char" and "v" or ""
  last_debug(range_type, last_opts)
end

---@param opts refactor.debug.Opts?
function M.print_var(opts)
  vim.o.operatorfunc = "v:lua.require'refactoring.debug'.debug_operatorfunc"
  last_debug = require("refactoring.debug.print_var").print_var
  last_opts = opts
  return "g@"
end

return M
