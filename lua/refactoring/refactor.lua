local extract_func = require("refactoring.refactor.extract_func")
local inline_func = require("refactoring.refactor.inline_func")
local extract_var = require("refactoring.refactor.extract_var")
local inline_var = require("refactoring.refactor.inline_var")

---@type table<string|integer, refactor.RefactorFunc> | {refactor_names: table<string, string>}
local M = {}

M.extract_func = extract_func.extract_func
M.extract_to_file = extract_func.extract_to_file
M.inline_func = inline_func.inline_func
M.extract_var = extract_var.extract_var
M.inline_var = inline_var.inline_var

M[106] = extract_func.extract_func
M[115] = inline_func.inline_func
M[119] = extract_var.extract_var
M[123] = inline_var.inline_var

M.refactor_names = {
    ["Inline Variable"] = "inline_var",
    ["Extract Variable"] = "extract_var",
    ["Extract Function"] = "extract_func",
    ["Extract Function To File"] = "extract_to_file",
    ["Inline Function"] = "inline_func",
}

return M
