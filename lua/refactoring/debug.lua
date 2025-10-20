local M = {}

-- TODO: user_opts everywhere will optional types

---@class refactor.debug.Marker
---@field start string
---@field end string

---@class refactor.debug.Markers
---@field print_var refactor.debug.Marker
---@field print_loc refactor.debug.Marker
---@field print_exp refactor.debug.Marker

---@class refactor.debug.cleanup.Opts
---@field markers refactor.debug.Markers
---@field types ('print_var'|'print_loc'|'print_exp')[]

---@class refactor.debug.print_var.Opts
---@field markers refactor.debug.Markers
---@field output_location 'above'|'below'

---@alias refactor.DebugFunc fun(type: 'v' | 'V' | '', opts: refactor.debug.print_var.Opts|refactor.debug.cleanup.Opts|nil)

local last_debug ---@type refactor.DebugFunc|nil
local last_opts ---@type refactor.debug.print_var.Opts|refactor.debug.cleanup.Opts|nil

---@param type "line" | "char" | "block"
function M.debug_operatorfunc(type)
  if not last_debug then return end

  local range_type = type == "line" and "V" or type == "char" and "v" or ""
  last_debug(range_type, last_opts)
end

---@param opts refactor.debug.print_var.Opts?
function M.print_var(opts)
  vim.o.operatorfunc = "v:lua.require'refactoring.debug'.debug_operatorfunc"
  last_debug = require("refactoring.debug.print_var").print_var
  last_opts = opts
  return "g@"
end

---@param opts refactor.debug.cleanup.Opts?
function M.cleanup(opts)
  vim.o.operatorfunc = "v:lua.require'refactoring.debug'.debug_operatorfunc"
  last_debug = require("refactoring.debug.cleanup").cleanup
  last_opts = opts
  return "g@"
end

return M
