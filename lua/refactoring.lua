local async = require "async"
local api = vim.api

local M = {}

---@class refactor.refactor.extract_func.Opts
---@field input string[]?
---@field preview_ns integer?
---@field code_generation refactor.extract_func.CodeGeneration

---@class refactor.refactor.extract_func.UserOpts
---@field input string[]?
---@field preview_ns integer?
---@field code_generation? refactor.extract_func.UserCodeGeneration

---@class refactor.refactor.extract_var.Opts
---@field input string[]?
---@field preview_ns integer?
---@field code_generation refactor.extract_var.CodeGeneration

---@class refactor.refactor.extract_var.UserOpts
---@field input string[]?
---@field preview_ns integer?
---@field code_generation? refactor.extract_var.UserCodeGeneration

---@class refactor.refactor.inline_var.Opts
---@field input string[]?
---@field preview_ns integer?

---@class refactor.refactor.inline_var.UserOpts
---@field input string[]?
---@field preview_ns integer?

---@class refactor.refactor.inline_func.Opts
---@field input string[]?
---@field preview_ns integer?
---@field code_generation refactor.inline_func.CodeGeneration

---@class refactor.refactor.inline_func.UserOpts
---@field input string[]?
---@field preview_ns integer?
---@field code_generation? refactor.inline_func.UserCodeGeneration

---@alias refactor.RefactorFunc fun(type: 'v' | 'V' | '', opts: refactor.Config|nil)

local last_refactor ---@type refactor.RefactorFunc|nil
local last_config ---@type refactor.Config|nil

---@param type "line" | "char" | "block"
function M.refactor_operatorfunc(type)
  if not last_refactor then return end

  local range_type = type == "line" and "V" or type == "char" and "v" or ""
  last_refactor(range_type, last_config)
end

---@param opts refactor.refactor.extract_func.UserOpts?
function M.extract_func(opts)
  local config = require("refactoring.config").get_config(0, { refactor = { extract_func = opts } })

  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_refactor = require("refactoring.refactor.extract_func").extract_func
  last_config = config
  return "g@"
end

---@param opts refactor.refactor.extract_func.UserOpts?
function M.extract_func_to_file(opts)
  local config = require("refactoring.config").get_config(0, { refactor = { extract_func = opts } })

  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_refactor = require("refactoring.refactor.extract_func").extract_func_to_file
  last_config = config
  return "g@"
end

---@param opts refactor.refactor.extract_var.UserOpts?
function M.extract_var(opts)
  local config = require("refactoring.config").get_config(0, { refactor = { extract_var = opts } })

  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_refactor = require("refactoring.refactor.extract_var").extract_var
  last_config = config
  return "g@"
end

---@param opts refactor.refactor.inline_var.UserOpts?
function M.inline_var(opts)
  local config = require("refactoring.config").get_config(0, { refactor = { inline_var = opts } })

  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_refactor = require("refactoring.refactor.inline_var").inline_var
  last_config = config
  return "g@l"
end

---@param opts refactor.refactor.inline_func.UserOpts?
function M.inline_func(opts)
  local config = require("refactoring.config").get_config(0, { refactor = { inline_func = opts } })

  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_refactor = require("refactoring.refactor.inline_func").inline_func
  last_config = config
  return "g@l"
end

---@param opts? {prefer_ex_cmd: boolean?}
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
