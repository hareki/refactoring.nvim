local M = {}

---@class refactor.debug.Marker
---@field start string
---@field end string

---@class refactor.debug.Markers
---@field print_var refactor.debug.Marker
---@field print_loc refactor.debug.Marker
---@field print_exp refactor.debug.Marker

---@class refactor.debug.UserMarkers
---@field print_var? refactor.debug.Marker
---@field print_loc? refactor.debug.Marker
---@field print_exp? refactor.debug.Marker

---@class refactor.debug.cleanup.Opts
---@field markers refactor.debug.Markers
---@field types ('print_var'|'print_loc'|'print_exp')[]
---@field restore_view boolean Does not work with dot-repeat

---@class refactor.debug.cleanup.UserOpts
---@field markers? refactor.debug.Markers
---@field types? ('print_var'|'print_loc'|'print_exp')[]
---@field restore_view? boolean

---@class refactor.debug.print_var.Opts
---@field markers refactor.debug.Markers
---@field output_location 'above'|'below'
---@field code_generation refactor.print_var.CodeGeneration

---@class refactor.debug.print_var.UserOpts
---@field markers? refactor.debug.UserMarkers
---@field output_location? 'above'|'below'
---@field code_generation? refactor.print_var.UserCodeGeneration

---@class refactor.debug.print_loc.Opts
---@field markers refactor.debug.Markers
---@field output_location 'above'|'below'
---@field code_generation refactor.print_loc.CodeGeneration

---@class refactor.debug.print_loc.UserOpts
---@field markers? refactor.debug.UserMarkers
---@field output_location? 'above'|'below'
---@field code_generation? refactor.print_loc.UserCodeGeneration

---@alias refactor.DebugFunc fun(type: 'v' | 'V' | '', opts: refactor.Config|nil)

local last_debug ---@type refactor.DebugFunc|nil
local last_config ---@type refactor.Config|nil

---@param type "line" | "char" | "block"
function M.debug_operatorfunc(type)
  if not last_debug then return end

  local range_type = type == "line" and "V" or type == "char" and "v" or ""
  last_debug(range_type, last_config)
end

---@param opts refactor.debug.print_var.UserOpts?
function M.print_var(opts)
  local config = require("refactoring.config").get_config(0, { debug = { print_var = opts } })

  vim.o.operatorfunc = "v:lua.require'refactoring.debug'.debug_operatorfunc"
  last_debug = require("refactoring.debug.print_var").print_var
  last_config = config
  return "g@"
end

M._last_view = nil ---@type vim.fn.winsaveview.ret|nil

---@param opts refactor.debug.cleanup.UserOpts?
function M.cleanup(opts)
  local config = require("refactoring.config").get_config(0, { debug = { cleanup = opts } })

  vim.o.operatorfunc = "v:lua.require'refactoring.debug'.debug_operatorfunc"
  last_debug = require("refactoring.debug.cleanup").cleanup
  last_config = config
  if config.debug.cleanup.restore_view then M._last_view = vim.fn.winsaveview() end
  return "g@"
end

---@param opts refactor.debug.print_loc.UserOpts?
function M.print_loc(opts)
  local config = require("refactoring.config").get_config(0, { debug = { print_loc = opts } })

  vim.o.operatorfunc = "v:lua.require'refactoring.debug'.debug_operatorfunc"
  last_debug = require("refactoring.debug.print_loc").print_loc
  last_config = config
  return "g@l"
end

return M
