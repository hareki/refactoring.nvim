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
local a, b =
  function()
    print "a"
  end, function()
    print "b"
    if true then
      for _, value in ipairs(some_table) do
        print "a"
      end
    elseif false then
      print "elseif"
    else
      print "else"
    end
  end]]
  local expected_lines = [[
local a, b =
  function()
    print "a"
  end, function()
    print "b"
    if true then
      for _, value in ipairs(some_table) do
        print "a"
        -- __PRINT_LOC_START
        print([==[b#if#for]==])-- __PRINT_LOC_END
      end
    elseif false then
      print "elseif"
    else
      print "else"
    end
  end]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 8, 8 }, expected_lines, " pp")
end

T["lua"]["works above"] = function()
  local lines = [[
local a, b =
  function()
    print "a"
  end, function()
    print "b"
    if true then
      for _, value in ipairs(some_table) do
        print "a"
      end
    elseif false then
      print "elseif"
    else
      print "else"
    end
  end]]
  local expected_lines = [[
local a, b =
  function()
    print "a"
  end, function()
    print "b"
    if true then
      -- __PRINT_LOC_START
      print([==[b#if]==])-- __PRINT_LOC_END
      for _, value in ipairs(some_table) do
        print "a"
      end
    elseif false then
      print "elseif"
    else
      print "else"
    end
  end]]
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 7, 6 }, expected_lines, " pP")
end

return T
