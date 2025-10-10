---@module "mini.test"

local child = MiniTest.new_child_neovim()

local expect, eq = MiniTest.expect, MiniTest.expect.equality

---@type {[string]: any|{[string]: any}}
local T = MiniTest.new_set {
  hooks = {
    pre_case = function()
      child.restart { "-u", "scripts/minimal_init.lua" }
      child.bo.readonly = false
      -- NOTE: we use `vim.notify` to show warnings to users, this makes
      -- it easier to catch them with mini.test
      child.lua "vim.notify = function(msg) error(msg) end"
    end,
    post_once = child.stop,
  },
}

---@param lines string
local set_lines = function(lines)
  child.api.nvim_buf_set_lines(0, 0, -1, true, vim.split(lines, "\n"))
end

local get_lines = function()
  return child.api.nvim_buf_get_lines(0, 0, -1, true)
end

---@param row integer
---@param col integer
local set_cursor = function(row, col)
  child.api.nvim_win_set_cursor(0, { row, col })
end

---@param lines string
---@param cursor {[1]: integer, [2]: integer}
---@param expected_lines string
---@param ... string
local function validate(lines, cursor, expected_lines, ...)
  set_lines(lines)
  set_cursor(cursor[1], cursor[2])
  child.type_keys(...)
  eq(get_lines(), vim.split(expected_lines, "\n"))
end

T["lua"] = MiniTest.new_set()

T["lua"]["works"] = function()
  local lines = [[
local function bar()
  print("foo")
end
print("foo")

do
  print("foo")
end

while false do
  print("foo")
end

repeat
  print("foo")
until true

if true then
  print("foo")
else
  print("foo")
end

for i = 1, 2 do
  print("foo")
end
local baz = function()
  print("foo")
end
]]
  local expected_lines = [[
local foo = "foo"
local function bar()
  print(foo)
end
print(foo)

do
  print(foo)
end

while false do
  print(foo)
end

repeat
  print(foo)
until true

if true then
  print(foo)
else
  print(foo)
end

for i = 1, 2 do
  print(foo)
end
local baz = function()
  print(foo)
end
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 2, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["lua"]["works for 1 scope"] = function()
  local lines = [[
print("foo")
print("foo")
print("foo")
print("foo")
]]
  local expected_lines = [[
local foo = "foo"
print(foo)
print(foo)
print(foo)
print(foo)
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 1, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["lua"]["works for 1 nested scope"] = function()
  local lines = [[
local function bar()
  print("foo")
end
]]
  local expected_lines = [[
local function bar()
  local foo = "foo"
  print(foo)
end
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 2, 0 }, expected_lines, " avi)", "foo<cr>")
end

T["lua"]["works for multiple scopes including global"] = function()
  local lines = [[
print("foo")

local function bar()
  print("foo")
end
]]
  local expected_lines = [[
local foo = "foo"
print(foo)

local function bar()
  print(foo)
end
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 1, 0 }, expected_lines, " avi)", "foo<cr>")
end

return T
