local async = require "async"
local api = vim.api

local M = {}

---@class refactor.Opts
---@field input string[]?
---@field preview_ns integer?

---@alias refactor.RefactorFunc fun(type: 'v' | 'V' | '', opts: refactor.debug.print_var.Opts?)

local last_debug ---@type refactor.RefactorFunc|nil
local last_opts ---@type refactor.debug.print_var.Opts|nil

---@param type "line" | "char" | "block"
function M.refactor_operatorfunc(type)
  if not last_debug then return end

  local range_type = type == "line" and "V" or type == "char" and "v" or ""
  last_debug(range_type, last_opts)
end

---@param opts refactor.debug.print_var.Opts?
function M.extract_func(opts)
  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_debug = require("refactoring.refactor.extract_func").extract_func
  last_opts = opts
  return "g@"
end

---@param opts refactor.Opts?
function M.extract_func_to_file(opts)
  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_debug = require("refactoring.refactor.extract_func").extract_func_to_file
  last_opts = opts
  return "g@"
end

---@param opts refactor.Opts?
function M.extract_var(opts)
  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_debug = require("refactoring.refactor.extract_var").extract_var
  last_opts = opts
  return "g@"
end

---@param opts refactor.Opts?
function M.inline_var(opts)
  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_debug = require("refactoring.refactor.inline_var").inline_var
  last_opts = opts
  return "g@l"
end

---@param opts refactor.Opts?
function M.inline_func(opts)
  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_debug = require("refactoring.refactor.inline_func").inline_func
  last_opts = opts
  return "g@l"
end

---@param opts refactor.Opts|{prefer_ex_cmd: boolean?}|nil
function M.select_refactor(opts)
  local prefer_ex_cmd = opts and opts.prefer_ex_cmd or false

  local mode = api.nvim_get_mode().mode

  local task = async.run(function()
    local select = require("refactoring.utils").select
    ---@type nil|{name: string, command: string, fn: fun(): string}
    local selected = select({
      { name = "Inline variable", fn = M.inline_var, command = "inline_var" },
      { name = "Extract variable", fn = M.extract_var, command = "extract_var" },
      { name = "Inline function", fn = M.inline_func, command = "inline_func" },
      { name = "Extract function", fn = M.extract_func, command = "extract_func" },
    }, {
      prompt = "Select a refactor:",
      format_item = function(item)
        return item.name
      end,
    })
    if not selected then return end

    if prefer_ex_cmd then
      api.nvim_input((":Refactor %s "):format(selected.command))
      return
    end

    local keys = selected.fn()
    if (mode == "v" or mode == "V" or mode == "\22") and keys == "g@" then keys = "gvg@" end
    api.nvim_input(keys)
  end)
  task:raise_on_error()
end

return M
