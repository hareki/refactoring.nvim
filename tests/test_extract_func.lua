---@module "mini.test"
-- TODO: add tests for extract_func_to_file

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

---@param path string
---@return string
local function read_file(path)
  local before_file = io.open(path)
  assert(before_file)
  local lines = before_file:read "*a"
  -- NOTE: remove trailling newline to avoid issues when splitting by newlines
  lines = lines:gsub("\n$", "") ---@type string

  return lines
end

T["lua"] = MiniTest.new_set()

T["lua"]["works"] = function()
  local lines = read_file "./tests/files/extract_func_works_before.lua"
  local expected_lines = read_file "./tests/files/extract_func_works_after.lua"
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 15, 0 }, expected_lines, " aeip", "bar<cr>")
end

T["lua"]["defaults to extracted location"] = function()
  local lines = read_file "./tests/files/extract_func_defaults_to_extracted_location_before.lua"
  local expected_lines = read_file "./tests/files/extract_func_defaults_to_extracted_location_after.lua"
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 1, 0 }, expected_lines, " aeip", "bar<cr>")
end

T["lua"]["identifies references outside extracted range scope"] = function()
  local lines = read_file "./tests/files/extract_func_identifies_references_outside_extracted_range_scope_before.lua"
  local expected_lines =
    read_file "./tests/files/extract_func_identifies_references_outside_extracted_range_scope_after.lua"
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 1, 0 }, expected_lines, " ae_", "foo2<cr>")
end

T["lua"]["chooses correct declaration"] = function()
  local lines = read_file "./tests/files/extract_func_chooses_correct_declaration_before.lua"
  local expected_lines = read_file "./tests/files/extract_func_chooses_correct_declaration_after.lua"
  child.cmd "edit tmp.lua"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 1, 0 }, expected_lines, " ae_", "foo2<cr>")
end

T["java"] = MiniTest.new_set()

T["java"]["works"] = function()
  local lines = read_file "./tests/files/extract_func_works_before.java"
  local expected_lines = read_file "./tests/files/extract_func_works_after.java"
  child.cmd "edit tmp.java"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 22, 0 }, expected_lines, " aeip", "bar<cr>")
end

T["php"] = MiniTest.new_set()

T["php"]["works"] = function()
  local lines = read_file "./tests/files/extract_func_works_before.php"
  local expected_lines = read_file "./tests/files/extract_func_works_after.php"
  child.cmd "edit tmp.php"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 21, 0 }, expected_lines, " aeip", "bar<cr>")
end

T["go"] = MiniTest.new_set()

T["go"]["works"] = function()
  local lines = read_file "./tests/files/extract_func_works_before.go"
  local expected_lines = read_file "./tests/files/extract_func_works_after.go"
  child.cmd "edit tmp.go"
  child.bo.expandtab = false
  validate(lines, { 21, 0 }, expected_lines, " aeip", "bar<cr>")
end

T["powershell"] = MiniTest.new_set()

T["powershell"]["works"] = function()
  local lines = read_file "./tests/files/extract_func_works_before.ps1"
  local expected_lines = read_file "./tests/files/extract_func_works_after.ps1"
  child.cmd "edit tmp.ps1"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 21, 0 }, expected_lines, " aeip", "bar<cr>")
end

T["python"] = MiniTest.new_set()

T["python"]["works"] = function()
  local lines = read_file "./tests/files/extract_func_works_before.py"
  local expected_lines = read_file "./tests/files/extract_func_works_after.py"
  child.cmd "edit tmp.py"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 18, 8 }, expected_lines, " aeip", "bar<cr>")
end

T["ruby"] = MiniTest.new_set()

T["ruby"]["works"] = function()
  local lines = read_file "./tests/files/extract_func_works_before.rb"
  local expected_lines = read_file "./tests/files/extract_func_works_after.rb"
  child.cmd "edit tmp.rb"
  child.bo.expandtab = true
  child.bo.shiftwidth = 2
  validate(lines, { 19, 4 }, expected_lines, " aeip", "bar<cr>")
end

T["vimscript"] = MiniTest.new_set()

T["vimscript"]["works"] = function()
  local lines = read_file "./tests/files/extract_func_works_before.vim"
  local expected_lines = read_file "./tests/files/extract_func_works_after.vim"
  child.cmd "edit tmp.vim"
  child.bo.expandtab = true
  child.bo.shiftwidth = 4
  validate(lines, { 16, 8 }, expected_lines, " aeip", "bar<cr>")
end

return T
