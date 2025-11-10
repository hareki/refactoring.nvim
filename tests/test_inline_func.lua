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
  child.type_keys " aI"
  sleep(1500)
  eq(get_lines(), vim.split(expected_lines, "\n"))
end

T["lua"] = MiniTest.new_set()

T["lua"]["works"] = function()
  local lines = [[
local function a(x, y, z)
  print(x)
  y = y + z
  return x, y, z
end

local c, d, e = a(1, 2, 3)
c, d, e = a(c + 1, d + 1, e + 1)]]
  local expected_lines = [[

local x, y, z = 1, 2, 3
print(x)
y = y + z

local c, d, e = x, y, z
local x, y, z = c + 1, d + 1, e + 1
print(x)
y = y + z

local c, d, e = x, y, z]]

  child.cmd "edit tmp.lua"
  validate(lines, { 1, 15 }, expected_lines)
end

T["lua"]["anonymous function declaration"] = function()
  local lines = [[
local b = function(x, y, z)
  print(x)
  y = y + z
  return x, y, z
end

b(1, 2, 3)
c, d, e = b()]]
  local expected_lines = [[

local x, y, z = 1, 2, 3
print(x)
y = y + z


local x, y, z = nil, nil, nil
print(x)
y = y + z

local c, d, e = x, y, z]]

  child.cmd "edit tmp.lua"
  validate(lines, { 1, 6 }, expected_lines)
end

return T
