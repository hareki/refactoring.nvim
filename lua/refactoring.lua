local async = require "async"
local api = vim.api

local M = {}

---@alias refactor.RefactorFunc fun(type: 'v' | 'V' | '') | fun()

local last_refactor ---@type refactor.RefactorFunc|nil

---@param type "line" | "char" | "block"
function M.refactor_operatorfunc(type)
  if not last_refactor then return end

  local region_type = type == "line" and "V" or type == "char" and "v" or ""
  last_refactor(region_type)
end

function M.extract_func()
  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_refactor = require("refactoring.refactor.extract_func").extract_func
  return "g@"
end

function M.extract_func_to_file()
  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_refactor = require("refactoring.refactor.extract_func").extract_func_to_file
  return "g@"
end

function M.extract_var()
  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_refactor = require("refactoring.refactor.extract_var").extract_var
  return "g@"
end

function M.inline_var()
  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_refactor = require("refactoring.refactor.inline_var").inline_var
  return "g@l"
end

function M.inline_func()
  vim.o.operatorfunc = "v:lua.require'refactoring'.refactor_operatorfunc"
  last_refactor = require("refactoring.refactor.inline_func").inline_func
  return "g@l"
end

-- TODO: add CONFIG here (and everywhere)
---@param opts {prefer_ex_cmd: boolean?}?
function M.select_refactor(opts)
  -- TODO: use this setting to start typing the command after rewriting the
  -- command interface
  local prefer_ex_cmd = opts and opts.prefer_ex_cmd or false

  local mode = api.nvim_get_mode().mode

  local task = async.run(function()
    local select = require("refactoring.util").select
    ---@type nil|{name: string, fn: fun(): string}
    local selected = select({
      { name = "Inline variable", fn = M.inline_var },
      { name = "Extract variable", fn = M.extract_var },
      { name = "Inline function", fn = M.inline_func },
      { name = "Extract function", fn = M.extract_func },
    }, {
      prompt = "Select a refactor:",
      format_item = function(item)
        return item.name
      end,
    })
    if not selected then return end

    local keys = selected.fn()
    if (mode == "v" or mode == "V" or mode == "\22") and keys == "g@" then keys = "gvg@" end
    api.nvim_input(keys)
  end)
  task:raise_on_error()
end

return M
