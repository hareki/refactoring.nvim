local contains = require("refactoring.range").contains
local compare = require("refactoring.range").compare
local async = require("async")
local lsp = vim.lsp
local iter = vim.iter
local ts = vim.treesitter
local api = vim.api

local M = {}

---@type fun(): refactor.QfItem[]
local get_symbols = async.wrap(1, function(cb)
    lsp.buf.document_symbol({
        on_list = function(args)
            cb(args.items)
        end,
    })
end)

---@type fun(opts: table): string
local input = async.wrap(2, function(opts, cb)
    vim.ui.input(opts, cb)
end)

---@class refactor.code_generation.function_declaration.opts
---@field args string[]
---@field name string
---@field body string
---@field return_values string[]
---@field method boolean?
---@field struct_var_name string?
---@field struct_name string?

---@class refactor.code_generation.function_call.opts
---@field args string[]
---@field name string
---@field return_values string[]
---@field method boolean?

---@class refactor.code_generation.return_statement.opts
---@field return_values string[]

---@class refactor.code_generation
---@field function_declaration {[string]: fun(opts: refactor.code_generation.function_declaration.opts): string}
---@field function_call {[string]: fun(opts: refactor.code_generation.function_call.opts): string}
---@field return_statement {[string]: fun(opts: refactor.code_generation.return_statement.opts): string}

---@type refactor.code_generation
local code_generation = {
    function_declaration = {
        lua = function(opts)
            local args = table.concat(opts.args, ", ")

            return ([[
local function %s(%s)
%s
end]]):format(opts.name, args, opts.body)
        end,
        c = function(opts)
            -- TODO: infer types somehow
            local return_type = #opts.return_values == 1 and "P" or "void"
            local args = iter(opts.args):map(function(a)
                return "P " .. a
            end):join(", ")
            local return_values = iter(opts.return_values):map(function(r)
                return "P *" .. r
            end):join(", ")
            local in_n_out = args ~= ""
                    and table.concat({ args, return_values }, ", ")
                or return_values

            return ([[
%s %s(%s) {
%s
}]]):format(
                return_type,
                opts.name,
                #opts.return_values < 2 and args or in_n_out,
                opts.body
            )
        end,
        c_sharp = function(opts)
            local return_type = #opts.return_values == 1 and "P"
                or #opts.return_values == 0 and "void"
                or ("(%s)"):format(iter(opts.return_values):map(function()
                    return "P"
                end):join(", "))

            return ([[
public static %s %s(%s) {
%s
}]]):format(
                return_type,
                opts.name,
                iter(opts.args):map(function(a)
                    return "P " .. a
                end):join(", "),
                opts.body
            )
        end,
        javascript = function(opts)
            return ([[
%s%s(%s){
%s
}]]):format(
                opts.method and "" or "function ",
                opts.name,
                table.concat(opts.args, ", "),
                opts.body
            )
        end,
        go = function(opts)
            local args = iter(opts.args):map(function(a)
                return a .. "P"
            end):join(", ")
            if opts.struct_name and opts.struct_var_name then
                return ([[
func (%s *%s) %s(%s) {
%s
}]]):format(
                    opts.struct_var_name,
                    opts.struct_name,
                    opts.name,
                    args,
                    opts.body
                )
            end
            return ([[
func %s(%s) {
%s
}]]):format(opts.name, args, opts.body)
        end,
        java = function(opts)
            local return_type = #opts.return_values == 0 and "void" or "P"
            local args = iter(opts.args):map(function(a)
                return "P " .. a
            end):join(", ")
            return ([[
private %s %s(%s) {
%s
}]]):format(return_type, opts.name, args, opts.body)
        end,
        php = function(opts)
            return ([[
%sfunction %s(%s)
{
%s
}]]):format(
                opts.method and "private " or "",
                opts.name,
                table.concat(opts.args, ", "),
                opts.body
            )
        end,
        powershell = function(opts)
            if opts.method then
                return ([[
[%s] %s(%s)
{
%s
}]]):format(
                    opts.return_values == 0 and "Void" or "P",
                    opts.name,
                    table.concat(opts.args, ", "),
                    opts.body
                )
            end
            return ([[
function %s
{
param (%s)
%s
}]]):format(opts.name, table.concat(opts.args, ",\n"), opts.body)
        end,
        python = function(opts)
            local args = table.concat(opts.args, ", ")
            if opts.method then
                args = "self, " .. args
            end
            return ([[
def %s(%s):
%s]]):format(opts.name, args, opts.body)
        end,
    },
    function_call = {
        lua = function(opts)
            local args = table.concat(opts.args, ", ")

            if #opts.return_values == 0 then
                return ("%s(%s)"):format(opts.name, args)
            end

            return ("local %s = %s(%s)"):format(
                table.concat(opts.return_values, ","),
                opts.name,
                args
            )
        end,
        c = function(opts)
            local args = table.concat(opts.args, ", ")
            if #opts.return_values == 0 then
                return ("%s(%s)"):format(opts.name, args)
            end
            if #opts.return_values == 1 then
                return ("P %s = %s(%s)"):format(
                    opts.return_values[1],
                    opts.name,
                    args
                )
            end
            local return_values = iter(opts.return_values):map(function(r)
                return "&" .. r
            end):join(", ")
            local in_n_out = args ~= ""
                    and table.concat({ args, return_values }, ", ")
                or return_values
            return ("%s(%s)"):format(opts.name, in_n_out)
        end,
        c_sharp = function(opts)
            local args = table.concat(opts.args, ", ")
            if #opts.return_values == 0 then
                return ("%s(%s)"):format(opts.name, args)
            end
            if #opts.return_values == 1 then
                return ("var %s = %s(%s)"):format(
                    opts.return_values[1],
                    opts.name,
                    args
                )
            end
            return ("var out = %s(%s);"):format(opts.name, args)
        end,
        javascript = function(opts)
            local args = table.concat(opts.args, ", ")
            if #opts.return_values == 0 then
                return ("%s(%s)"):format(opts.name, args)
            end
            if #opts.return_values == 1 then
                return ("let %s = %s(%s)"):format(
                    opts.return_values[1],
                    opts.name,
                    args
                )
            end
            return ("let [%s] = %s(%s)"):format(
                table.concat(opts.return_values, ", "),
                opts.name,
                args
            )
        end,
        go = function(opts)
            local args = table.concat(opts.args, ", ")
            if #opts.return_values == 0 then
                return ("%s(%s)"):format(opts.name, args)
            end

            return ("var %s := %s(%s)"):format(
                table.concat(opts.return_values, ", "),
                opts.name,
                args
            )
        end,
        java = function(opts)
            local args = table.concat(opts.args, ", ")
            if #opts.return_values == 0 then
                return ("%s(%s);"):format(opts.name, args)
            end

            return ("var %s = %s(%s);"):format(
                opts.return_values[1],
                opts.name,
                args
            )
        end,
        php = function(opts)
            local args = table.concat(opts.args, ", ")
            local name = opts.method and "self->" .. opts.name or opts.name
            if #opts.return_values == 0 then
                return ("%s(%s);"):format(name, args)
            end
            local return_values = iter(opts.return_values):map(function(r)
                return r:match("^$") and r or "$" .. r
            end)
            if #opts.return_values == 1 then
                return ("%s = %s(%s);"):format(return_values:next(), name, args)
            end

            return ("[%s] = %s(%s);"):format(
                return_values:join(", "),
                name,
                args
            )
        end,
        powershell = function(opts)
            local args = table.concat(opts.args, " ")
            if #opts.return_values == 0 then
                return ("%s %s"):format(opts.name, args)
            end
            if #opts.return_values == 1 then
                return ("%s = %s %s"):format(
                    opts.return_values[1],
                    opts.name,
                    args
                )
            end

            return ("$out = %s %s"):format(opts.name, args)
        end,
        python = function(opts)
            local args = table.concat(opts.args, ", ")
            local name = opts.method and "self." .. opts.name or opts.name
            if #opts.return_values == 0 then
                return ("%s(%s)"):format(name, args)
            end
            return ("%s = %s(%s)"):format(
                table.concat(opts.return_values, ", "),
                name,
                args
            )
        end,
    },
    return_statement = {
        lua = function(opts)
            return ("\n\nreturn %s"):format(
                table.concat(opts.return_values, ",")
            )
        end,
        c = function(opts)
            if #opts.return_values > 1 then
                return ""
            end
            return ("\n\nreturn %s"):format(opts.return_values[1])
        end,
        c_sharp = function(opts)
            if #opts.return_values == 1 then
                return ("\n\nreturn %s"):format(opts.return_values[1])
            end
            return ("\n\nreturn (%s)"):format(
                table.concat(opts.return_values, ", ")
            )
        end,
        javascript = function(opts)
            if #opts.return_values == 1 then
                return ("\n\nreturn %s"):format(opts.return_values[1])
            end
            return ("\n\nreturn [%s]"):format(
                table.concat(opts.return_values, ", ")
            )
        end,
        go = function(opts)
            return ("\n\nreturn %s"):format(
                table.concat(opts.return_values, ", ")
            )
        end,
        java = function(opts)
            return ("\n\nreturn %s;"):format(opts.return_values[1])
        end,
        php = function(opts)
            -- TODO: capture variable names including `$` instead?
            local return_values = iter(opts.return_values):map(function(r)
                return r:match("^$") and r or "$" .. r
            end)
            if #opts.return_values == 1 then
                return ("\n\nreturn %s;"):format(return_values:next())
            end

            return ("\n\nreturn [%s];"):format(return_values:join(", "))
        end,
        powershell = function(opts)
            if #opts.return_values == 1 then
                return ("\n\nreturn %s"):format(opts.return_values[1])
            end

            return ("\n\nreturn @(%s)"):format(
                table.concat(opts.return_values, ", ")
            )
        end,
        python = function(opts)
            return ("\n\nreturn %s"):format(
                table.concat(opts.return_values, ", ")
            )
        end,
    },
}
code_generation.function_declaration.cpp =
    code_generation.function_declaration.c
code_generation.function_call.cpp = code_generation.function_call.c
code_generation.return_statement.cpp = code_generation.return_statement.c
code_generation.function_declaration.typescript =
    code_generation.function_declaration.javascript
code_generation.function_call.typescript =
    code_generation.function_call.javascript
code_generation.return_statement.typescript =
    code_generation.return_statement.javascript

---@type {[string]: {fn: integer, method?: integer}}
local parents_till_nil = {
    lua = {
        fn = 2,
    },
    c = {
        fn = 2,
    },
    c_sharp = {
        fn = 2,
        method = 4,
    },
    javascript = {
        fn = 2,
        method = 4,
    },
    go = {
        fn = 2,
    },
    java = {
        method = 4,
    },
    php = {
        fn = 2,
        method = 4,
    },
    powershell = {
        fn = 3,
        method = 4,
    },
    python = {
        fn = 2,
        method = 4,
    },
}
parents_till_nil.cpp = parents_till_nil.c
parents_till_nil.typescript = parents_till_nil.javascript

---@class refactor.Output
---@field comment TSNode[]?
---@field fn TSNode
---@field method boolean?
---@field struct_name string?
---@field struct_var_name string?

---@param nested_lang_tree vim.treesitter.LanguageTree
---@param query vim.treesitter.Query
---@param buf integer
---@param extract_range Range4
---@return TSNode?
---@return {method: boolean?, struct_name: string?, struct_var_name: string?}?
local function get_output_node(nested_lang_tree, query, buf, extract_range)
    local outputs = {} ---@type refactor.Output[]
    for _, tree in ipairs(nested_lang_tree:trees()) do
        for _, match in query:iter_matches(tree:root(), buf) do
            local output ---@type table|refactor.Output|nil
            for capture_id, nodes in pairs(match) do
                local name = query.captures[capture_id]
                local is_output_function = name == "output.function"
                local is_output_comment = name == "output.comment"
                local is_output_method = name == "output.method"
                local is_output_struct_name = name == "output.struct_name"
                local is_output_struct_var_name = name
                    == "output.struct_var_name"
                if is_output_comment then
                    output = output or {}
                    output.comment = nodes
                elseif is_output_function then
                    output = output or {}
                    output.fn = nodes[1]
                elseif is_output_method then
                    output = output or {}
                    output.fn = nodes[1]
                    output.method = true
                elseif is_output_struct_name then
                    output = output or {}
                    output.struct_name = ts.get_node_text(nodes[1], buf)
                elseif is_output_struct_var_name then
                    output = output or {}
                    output.struct_var_name = ts.get_node_text(nodes[1], buf)
                end
            end
            if output then
                table.insert(outputs, output)
            end
        end
    end

    local lang = nested_lang_tree:lang()
    ---@type refactor.Output|nil
    local selected_output = iter(outputs)
        :filter(
            ---@param o refactor.Output
            function(o)
                local expected = o.method and parents_till_nil[lang].method
                    or parents_till_nil[lang].fn

                local current = o.fn ---@type TSNode|nil
                local p_till_nil = 0
                while current do
                    current = current:parent()
                    p_till_nil = p_till_nil + 1
                end

                return p_till_nil == expected
            end
        )
        :filter(
            ---@param o refactor.Output
            function(o)
                -- TODO: add decorators for languages like python
                local n = o.comment and o.comment[1] or o.fn
                local start_row, start_col = n:start()
                return compare(
                    { start_row, start_col },
                    { extract_range[1], extract_range[2] }
                ) == -1
            end
        )
        :fold(
            nil,
            ---@param acc refactor.Output|nil
            ---@param o refactor.Output
            function(acc, o)
                if not acc then
                    return o
                end
                -- TODO: add decorators for languages like python
                local n = o.comment and o.comment[1] or o.fn
                local n_start_row, n_start_col = n:start()
                -- TODO: add decorators for languages like python
                local acc_n = acc.comment and acc.comment[1] or acc.fn
                local acc_start_row, acc_start_col = acc_n:start()

                local o_row_distance = math.abs(n_start_row - extract_range[1])
                local acc_row_distance =
                    math.abs(acc_start_row - extract_range[1])
                if acc_row_distance < o_row_distance then
                    return acc
                end

                local o_col_distance = math.abs(n_start_col - extract_range[2])
                local acc_col_distance =
                    math.abs(acc_start_col - extract_range[2])
                if
                    acc_row_distance == o_row_distance
                    and acc_col_distance < o_col_distance
                then
                    return acc
                end
                return o
            end
        )

    if not selected_output then
        return
    end

    -- TODO: add decorators for languages like python
    return selected_output.comment and selected_output.comment[1]
        or selected_output.fn,
        {
            method = selected_output.method,
            struct_name = selected_output.struct_name,
            struct_var_name = selected_output.struct_var_name,
        }
end

---@param declarations refactor.QfItem
---@param extract_range Range4
---@param buf integer
---@param output_range Range4
---@param lines string[]
---@param out_buf integer
---@param fn_name string
---@param nested_lang_tree vim.treesitter.LanguageTree
---@param query vim.treesitter.Query
---@param opts {method: boolean?, struct_name: string?, struct_var_name: string?}
local function extract_func(
    declarations,
    extract_range,
    buf,
    output_range,
    lines,
    out_buf,
    fn_name,
    nested_lang_tree,
    query,
    opts
)
    local reference_nodes = {} ---@type TSNode[]
    local scopes = {} ---@type TSNode[]
    for _, tree in ipairs(nested_lang_tree:trees()) do
        for _, match in query:iter_matches(tree:root(), buf) do
            for capture_id, nodes in pairs(match) do
                local name = query.captures[capture_id]
                local is_identifier = name == "reference.identifier"
                local is_scope = name == "scope"
                if is_identifier then
                    for _, node in ipairs(nodes) do
                        table.insert(reference_nodes, node)
                    end
                elseif is_scope then
                    for _, node in ipairs(nodes) do
                        table.insert(scopes, node)
                    end
                end
            end
        end
    end

    local already_seen = {} ---@type {[string]: boolean}
    local references_inside_range = iter(reference_nodes)
        :filter(
            ---@param r TSNode
            function(r)
                local start_row, start_col, end_row, end_col = r:range()
                local start_node = { start_row, start_col }
                local end_node = { end_row, end_col }
                local contains_start = contains(extract_range, start_node)
                local contains_end = contains(extract_range, end_node)
                return contains_start and contains_end
            end
        )
        :map(
            ---@param r TSNode
            function(r)
                return ts.get_node_text(r, buf)
            end
        )
        :filter(
            ---@param t string
            function(t)
                if already_seen[t] then
                    return false
                end
                already_seen[t] = true
                return true
            end
        )
        :totable()

    ---@type refactor.QfItem
    local declarations_inside_range = iter(declarations)
        :filter(
            ---@param s refactor.QfItem
            function(s)
                local start_symbol = { s.lnum - 1, s.col - 1 }
                local end_symbol = { s.end_lnum - 1, s.end_col - 1 }
                local contains_start = contains(extract_range, start_symbol)
                local contains_end = contains(extract_range, end_symbol)
                return contains_start and contains_end
            end
        )
        :map(
            ---@param s refactor.QfItem
            function(s)
                return s.text:match("^%[[^%]]+%] (.*)$")
            end
        )
        :totable()

    -- TODO: maybe check that all the treesitter captures are not empty(?
    ---@type TSNode[]
    local scopes_for_range = iter(scopes):filter(
        ---@param s TSNode
        function(s)
            local scope_range = { s:range() }
            return contains(scope_range, { extract_range[1], extract_range[2] })
                and contains(
                    scope_range,
                    { extract_range[3], extract_range[4] }
                )
        end
    ):totable()
    ---@type refactor.QfItem
    local declarations_before_output_range = iter(declarations)
        :filter(
            ---@param d refactor.QfItem
            function(d)
                local start_symbol = { d.lnum - 1, d.col - 1 }
                local end_symbol = { d.end_lnum - 1, d.end_col - 1 }

                ---@type TSNode|nil
                local declaration_scope = iter(scopes):filter(
                    ---@param s TSNode
                    function(s)
                        local scope_range = { s:range() }
                        return contains(scope_range, start_symbol)
                            and contains(scope_range, end_symbol)
                    end
                ):fold(
                    nil,
                    ---@param acc nil|TSNode
                    ---@param s TSNode
                    function(acc, s)
                        if not acc then
                            return s
                        end
                        if s:byte_length() < acc:byte_length() then
                            return s
                        end
                        return acc
                    end
                )

                local is_in_scope = declaration_scope
                    and iter(scopes_for_range):find(
                        ---@param s TSNode
                        function(s)
                            return s:equal(declaration_scope)
                        end
                    )

                local start_output = { output_range[1], output_range[2] }
                local compare_start = compare(start_symbol, start_output)
                local compare_end = compare(end_symbol, start_output)
                return compare_start ~= 1 and compare_end ~= 1 and is_in_scope
            end
        )
        :map(
            ---@param s refactor.QfItem
            function(s)
                return s.text:match("^%[[^%]]+%] (.*)$")
            end
        )
        :totable()
    ---@type refactor.QfItem
    local declarations_before_range = iter(declarations)
        :filter(
            ---@param d refactor.QfItem
            function(d)
                local start_symbol = { d.lnum - 1, d.col - 1 }
                local end_symbol = { d.end_lnum - 1, d.end_col - 1 }

                ---@type TSNode|nil
                local declaration_scope = iter(scopes):filter(
                    ---@param s TSNode
                    function(s)
                        local scope_range = { s:range() }
                        return contains(scope_range, start_symbol)
                            and contains(scope_range, end_symbol)
                    end
                ):fold(
                    nil,
                    ---@param acc nil|TSNode
                    ---@param s TSNode
                    function(acc, s)
                        if not acc then
                            return s
                        end
                        if s:byte_length() < acc:byte_length() then
                            return s
                        end
                        return acc
                    end
                )
                local is_in_scope = declaration_scope
                    and iter(scopes_for_range):find(
                        ---@param s TSNode
                        function(s)
                            return s:equal(declaration_scope)
                        end
                    )

                local start_extract = { extract_range[1], extract_range[2] }
                local compare_start = compare(start_symbol, start_extract)
                local compare_end = compare(end_symbol, start_extract)
                return compare_start ~= 1 and compare_end ~= 1 and is_in_scope
            end
        )
        :map(
            ---@param s refactor.QfItem
            function(s)
                return s.text:match("^%[[^%]]+%] (.*)$")
            end
        )
        :totable()

    local args = iter(references_inside_range):filter(
        ---@param r string
        function(r)
            return not vim.tbl_contains(declarations_inside_range, r)
                and not vim.tbl_contains(declarations_before_output_range, r)
                and vim.tbl_contains(declarations_before_range, r)
        end
    ):totable()

    already_seen = {}
    local references_after_range = iter(reference_nodes)
        :filter(
            ---@param r TSNode
            function(r)
                local start_row, start_col, end_row, end_col = r:range()
                local start_node = { start_row, start_col }
                local end_node = { end_row, end_col }

                ---@type TSNode|nil
                local declaration_scope = iter(scopes):filter(
                    ---@param s TSNode
                    function(s)
                        local scope_range = { s:range() }
                        return contains(scope_range, start_node)
                            and contains(scope_range, end_node)
                    end
                ):fold(
                    nil,
                    ---@param acc nil|TSNode
                    ---@param s TSNode
                    function(acc, s)
                        if not acc then
                            return s
                        end
                        if s:byte_length() < acc:byte_length() then
                            return s
                        end
                        return acc
                    end
                )
                local is_in_scope = declaration_scope
                    and iter(scopes_for_range):find(
                        ---@param s TSNode
                        function(s)
                            return s:equal(declaration_scope)
                        end
                    )

                local extract_end = { extract_range[3], extract_range[4] }
                local compare_start = compare(start_node, extract_end)
                local compare_end = compare(end_node, extract_end)
                return compare_start == 1 and compare_end == 1 and is_in_scope
            end
        )
        :map(
            ---@param r TSNode
            function(r)
                return ts.get_node_text(r, buf)
            end
        )
        :filter(
            ---@param t string
            function(t)
                if already_seen[t] then
                    return false
                end
                already_seen[t] = true
                return true
            end
        )
        :totable()
    local return_values = iter(references_after_range):filter(
        ---@param r string
        function(r)
            -- TODO: maybe limit this to write references somehow
            return vim.tbl_contains(references_inside_range, r)
        end
    ):totable()

    local body = table.concat(lines, "\n")
    local body_indent ---@type integer
    body, body_indent = vim.text.indent(0, body)
    local lang = nested_lang_tree:lang()
    if #return_values > 0 then
        local return_statement = code_generation.return_statement[lang]({
            return_values = return_values,
        })
        body = body .. return_statement
    end
    local indent_width = vim.bo[buf].shiftwidth > 0 and vim.bo[buf].shiftwidth
        or vim.bo[buf].tabstop
    body = vim.text.indent(1 * indent_width, body)
    local function_definition = code_generation.function_declaration[lang]({
        args = args,
        body = body,
        name = fn_name,
        return_values = return_values,
        method = opts.method,
        struct_name = opts.struct_name,
        struct_var_name = opts.struct_var_name,
    }) .. "\n\n"
    function_definition = vim.text.indent(
        (opts.method and 1 or 0) * indent_width,
        function_definition
    )
    local function_call = code_generation.function_call[lang]({
        args = args,
        name = fn_name,
        return_values = return_values,
        method = opts.method,
    })
    function_call = vim.text.indent(body_indent, function_call)

    api.nvim_buf_set_text(
        buf,
        extract_range[1],
        extract_range[2],
        extract_range[3],
        extract_range[4],
        vim.split(function_call, "\n")
    )

    local function_definition_lines = vim.split(function_definition, "\n")
    if opts.method then
        -- NOTE: treesitter nodes don't include whitespace. So, output region's
        -- first line it's (probably) already indented
        function_definition_lines[1] =
            vim.text.indent(0, function_definition_lines[1])
        -- TODO: manually indent (without `vim.text.indent`) the last (empty)
        -- line
    end
    api.nvim_buf_set_text(
        out_buf,
        output_range[1],
        output_range[2],
        output_range[1],
        output_range[2],
        function_definition_lines
    )

    -- TODO: maybe use snippets to expand the generated function and
    -- navigate through type placeholders?
end

---@param range_type 'v'|'V'|''
---@return Range4, string[]
local function get_extracted_range(range_type)
    local buf = api.nvim_get_current_buf()
    local range_start = vim.fn.getpos("'[")
    local range_end = vim.fn.getpos("']")

    local range_last_line =
        api.nvim_buf_get_lines(buf, range_end[2] - 1, range_end[2], true)[1]

    local extract_range = {
        range_start[2] - 1,
        range_type ~= "V" and range_start[3] - 1 or 0,
        range_end[2] - 1,
        range_type ~= "V" and range_end[3] - 1 or #range_last_line,
    }
    local lines =
        vim.fn.getregion(range_start, range_end, { type = range_type })

    return extract_range, lines
end

---@param buf integer
---@param extract_range Range4
---@return vim.treesitter.LanguageTree?, vim.treesitter.Query?
local function ts_parse(buf, extract_range)
    local lang_tree, err1 = ts.get_parser(buf, nil, { error = false })
    if not lang_tree then
        vim.notify(err1, vim.log.levels.ERROR)
        return
    end
    -- TODO: use async parsing
    lang_tree:parse(true)
    local nested_lang_tree = lang_tree:language_for_range(extract_range)
    local lang = nested_lang_tree:lang()
    local query = ts.query.get(lang, "refactor")
    if not query then
        vim.notify(
            ("There is no `refactor` query file for language %s"):format(lang),
            vim.log.levels.ERROR
        )
        return
    end

    return nested_lang_tree, query
end

-- TODO: support all languages
-- TODO: remove `buf` (first var) from all calls after the rewrite is finished
---@param _ integer
---@param range_type 'v' | 'V' | ''
M.extract_func = function(_, range_type)
    local buf = api.nvim_get_current_buf()
    local extract_range, lines = get_extracted_range(range_type)

    local task = async.run(function()
        local fn_name = input({ prompt = "Function name: " })
        if not fn_name then
            return
        end

        local nested_lang_tree, query = ts_parse(buf, extract_range)
        if not nested_lang_tree or not query then
            return
        end

        local output_node, opts =
            get_output_node(nested_lang_tree, query, buf, extract_range)
        -- TODO: default to some range (current location?) if no `output_node` found
        -- TODO: define treesitter fallback captures (like root node or current
        -- statement) to use as default location. Or maybe nearest top level statement (?
        if not output_node then
            vim.notify(
                "Couldn't find an output range in which to extract the function"
            )
            return
        end
        local output_range = { output_node:range() }

        -- TODO: clangd, gopls, jdt.ls, phpactor, powershell_es  and roslyn
        -- don't return symbols for local variables. So, fallback to treesitter
        -- somehow (or maybe don't use symbols at all)
        local declarations = get_symbols()
        extract_func(
            declarations,
            extract_range,
            buf,
            output_range,
            lines,
            buf,
            fn_name,
            nested_lang_tree,
            query,
            {
                method = opts and opts.method,
                struct_name = opts and opts.struct_name,
                struct_var_name = opts and opts.struct_var_name,
            }
        )
    end)
    task:raise_on_error()
end

-- TODO: maybe also generate the import logic(?
---@param _ integer
---@param range_type 'v' | 'V' | ''
M.extract_func_to_file = function(_, range_type)
    local buf = api.nvim_get_current_buf()
    local extract_range, lines = get_extracted_range(range_type)

    local task = async.run(function()
        local file_name = input({
            prompt = "New file name: ",
            completion = "files",
            default = vim.fn.expand("%:.:h") .. "/",
        })
        if not file_name then
            return
        end
        local fn_name = input({ prompt = "Function name: " })
        if not fn_name then
            return
        end

        local nested_lang_tree, query = ts_parse(buf, extract_range)
        if not nested_lang_tree or not query then
            return
        end

        -- NOTE: `lua_ls` sends a ContentModified error if `out_buf` is created
        -- before this. That makes the callback of `get_symbols` never be
        -- called. So, we call it before creating `out_buf`
        local declarations = get_symbols()

        local out_buf = vim.fn.bufadd(file_name)
        if not api.nvim_buf_is_loaded(out_buf) then
            vim.fn.bufload(out_buf)
        end
        local out_nested_lang_tree = ts_parse(out_buf, extract_range)
        if not out_nested_lang_tree then
            return
        end
        local output_node, opts =
            get_output_node(out_nested_lang_tree, query, out_buf, extract_range)
        local output_range = output_node and { output_node:range() }
            or { 0, 0, 0, 0 }

        extract_func(
            declarations,
            extract_range,
            buf,
            output_range,
            lines,
            out_buf,
            fn_name,
            nested_lang_tree,
            query,
            {
                method = opts and opts.method,
                struct_name = opts and opts.struct_name,
                struct_var_name = opts and opts.struct_var_name,
            }
        )
    end)
    task:raise_on_error()
end

return M
