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
---@param a integer
local function foo(a)
  for j = 1, 5 do
    local b = 'b'
    local c = 'c'
    local d = {'d'}
    local e = { e = 'e' }
    local f = {}
    function f.f(self) return 'f' end
    local g, h = function() return 'g' end, 'h'
    local i
    local k = 'k'
    local l = 'l'

    a = a + 1
    print(b)
    print(c + 1)
    print(d[1])
    print(e.e)
    print(f:f())
    print(g())
    if h then end
    while k do end
    repeat until l
    i = 'i'
    print(j)

    print(a)
    print(i)
  end
end
]]
  local expected_lines = [[
---@param b string
---@param c string
---@param d table
---@param e table
---@param f table
---@param g function
---@param h string
---@param k string
---@param l string
---@param i string
local function bar(a, b, c, d, e, f, g, h, k, l, i, j)
  a = a + 1
  print(b)
  print(c + 1)
  print(d[1])
  print(e.e)
  print(f:f())
  print(g())
  if h then end
  while k do end
  repeat until l
  i = 'i'
  print(j)

  return a,i
end

---@param a integer
local function foo(a)
  for j = 1, 5 do
    local b = 'b'
    local c = 'c'
    local d = {'d'}
    local e = { e = 'e' }
    local f = {}
    function f.f(self) return 'f' end
    local g, h = function() return 'g' end, 'h'
    local i
    local k = 'k'
    local l = 'l'

    local a, i = bar(a, b, c, d, e, f, g, h, k, l, i, j)

    print(a)
    print(i)
  end
end
]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 15, 0 }, expected_lines, " ae11j", "bar<cr>")
end

return T
