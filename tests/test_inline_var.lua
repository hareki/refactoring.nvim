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

---@param ms integer
local sleep = function(ms)
  vim.uv.sleep(ms)
  -- Poke child's event loop to make it up to date
  child.api.nvim_eval "1"
end

---@param lines string
---@param cursor {[1]: integer, [2]: integer}
---@param expected_lines string
local function validate(lines, cursor, expected_lines)
  set_lines(lines)
  set_cursor(cursor[1], cursor[2])
  child.lua [[vim.wait(1000, function() return #vim.lsp.get_clients({ bufnr = 0 }) == 1  end)]]
  child.type_keys " ai"
  sleep(1500)
  eq(get_lines(), vim.split(expected_lines, "\n"))
end

T["lua"] = MiniTest.new_set()

T["lua"]["simple assignment"] = function()
  local lines = [[
local foo = 'foo'
print(foo)
print(foo)
print(foo)]]
  local expected_lines = [[
print('foo')
print('foo')
print('foo')]]

  child.cmd "edit tmp.lua"
  validate(lines, { 1, 6 }, expected_lines)
end

T["lua"]["multiple assignment"] = function()
  local lines = [[
local foo, bar = 'foo', 'bar'
print(bar)
print(foo)
print(foo)
print(foo)]]
  local expected_lines = [[
local  bar =  'bar'
print(bar)
print('foo')
print('foo')
print('foo')]]

  child.cmd "edit tmp.lua"
  validate(lines, { 1, 6 }, expected_lines)
end

-- TODO: maybe the comment should also be deleted
T["lua"]["filters LSP definitions without a Treesitter match"] = function()
  local lines = [[
---@type table<integer, string>
local foo = { "foo" }
print(foo)
print(foo)
print(foo)
print(foo)
print(foo)]]
  local expected_lines = [[
---@type table<integer, string>
print({ "foo" })
print({ "foo" })
print({ "foo" })
print({ "foo" })
print({ "foo" })]]

  child.cmd "edit tmp.lua"
  validate(lines, { 2, 6 }, expected_lines)
end

T["lua"]["orders reference's text edits backwards"] = function()
  local lines = [[
local foo = "foo"
print(foo, foo)
print(foo, foo)
print(foo, foo)]]
  local expected_lines = [[
print("foo", "foo")
print("foo", "foo")
print("foo", "foo")]]

  child.cmd "edit tmp.lua"
  validate(lines, { 1, 6 }, expected_lines)
end

T["c"] = MiniTest.new_set()

T["c"]["multiple assignment"] = function()
  local lines = [[
#include <stdio.h>

int main(){
    int a = 1, b = 2;
    printf("%i", a);
    printf("%i", a);

    printf("%i", b);
    printf("%i", b);
}]]
  local expected_lines = [[
#include <stdio.h>

int main(){
    int    b = 2;
    printf("%i", 1);
    printf("%i", 1);

    printf("%i", b);
    printf("%i", b);
}]]

  child.cmd "edit tmp.c"
  validate(lines, { 4, 8 }, expected_lines)
end

return T
