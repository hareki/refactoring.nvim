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

T["lua"]["works below"] = function()
  local lines = [[
local bar = "bar"
local foo = "foo"
print(foo)
print(foo)
print(foo)
print(foo)
print(bar)
print(bar)]]
  local expected_lines = [[
local bar = "bar"
local foo = "foo"
print(foo)
print(foo)
print(foo)
print(foo)
print(bar)
print(bar)
-- __PRINT_VAR_START
print([==[bar:]==], vim.inspect(bar))
print([==[foo:]==], vim.inspect(foo))-- __PRINT_VAR_END]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 1, 0 }, expected_lines, " pvG")
end

T["lua"]["works above"] = function()
  local lines = [[
local bar = "bar"
local foo = "foo"
print(foo)
print(foo)
print(foo)
print(foo)
print(bar)
print(bar)]]
  local expected_lines = [[
local bar = "bar"
local foo = "foo"
-- __PRINT_VAR_START
print([==[foo:]==], vim.inspect(foo))
print([==[bar:]==], vim.inspect(bar))-- __PRINT_VAR_END
print(foo)
print(foo)
print(foo)
print(foo)
print(bar)
print(bar)]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 3, 0 }, expected_lines, " pVG")
end

T["c"] = MiniTest.new_set()

T["c"]["works"] = function()
  local lines = [[
int main() {
    int i = 3;
    return i;
}]]
  local expected_lines = [[
int main() {
    int i = 3;
    // __PRINT_VAR_START
    printf("i: %s \n", i);// __PRINT_VAR_END
    return i;
}]]
  child.cmd "edit tmp.c"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 2, 8 }, expected_lines, " pviw")
end

T["javascript"] = MiniTest.new_set()

T["javascript"]["works"] = function()
  local lines = [[
function foo() {
  const i = 3;
  return i;
}]]
  local expected_lines = [[
function foo() {
  const i = 3;
  // __PRINT_VAR_START
  console.log("i:", i)// __PRINT_VAR_END
  return i;
}]]
  child.cmd "edit tmp.js"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 2, 8 }, expected_lines, " pviw")
end

return T
