local contains = require("refactoring.range").contains
local compare = require("refactoring.range").compare
local async = require("async")
local lsp = vim.lsp
local iter = vim.iter
local ts = vim.treesitter
local api = vim.api

local M = {}

---@type fun(opts: table): string
local input = async.wrap(2, function(opts, cb)
    vim.ui.input(opts, cb)
end)

---@class refactor.code_generation.function_declaration.opts
---@field args refactor.Variable[]
---@field name string
---@field body string
---@field return_values string[]
---@field method boolean?
---@field singleton boolean?
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

-- TODO: add code_generation for `vimscript`
---@type refactor.code_generation
local code_generation = {
    function_declaration = {
        lua = function(opts)
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
            if
                iter(opts.args):any(
                    ---@param v refactor.Variable
                    function(v)
                        return v.type ~= nil
                    end
                )
            then
                local annotations = iter(opts.args)
                    :filter(
                        ---@param v refactor.Variable
                        function(v)
                            return v.type ~= nil
                        end
                    )
                    :map(
                        ---@param v refactor.Variable
                        function(v)
                            return ("---@param %s %s"):format(
                                v.identifier,
                                v.type
                            )
                        end
                    )
                    :join("\n")
                return ([[
%s
local function %s(%s)
%s
end]]):format(annotations, opts.name, args, opts.body)
            end

            return ([[
local function %s(%s)
%s
end]]):format(opts.name, args, opts.body)
        end,
        c = function(opts)
            local return_type = #opts.return_values == 1 and "P" or "void"
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return ("%s %s"):format(v.type or "P", v.identifier)
                end
            ):join(", ")
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

            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return ("%s %s"):format(v.type or "P", v.identifier)
                end
            ):join(", ")

            return ([[
public static %s %s(%s) {
%s
}]]):format(return_type, opts.name, args, opts.body)
        end,
        javascript = function(opts)
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
            return ([[
%s%s(%s){
%s
}]]):format(
                opts.method and "" or "function ",
                opts.name,
                args,
                opts.body
            )
        end,
        go = function(opts)
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return ("%s %s"):format(v.identifier, v.type or "P")
                end
            ):join(", ")
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
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return ("%s %s"):format(v.type or "P", v.identifier)
                end
            ):join(", ")
            return ([[
private %s %s(%s) {
%s
}]]):format(return_type, opts.name, args, opts.body)
        end,
        php = function(opts)
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
            return ([[
%sfunction %s(%s)
{
%s
}]]):format(
                opts.method and "private " or "",
                opts.name,
                args,
                opts.body
            )
        end,
        powershell = function(opts)
            if opts.method then
                local args = iter(opts.args):map(
                    ---@param v refactor.Variable
                    function(v)
                        return v.identifier
                    end
                ):join(", ")
                return ([[
[%s] %s(%s)
{
%s
}]]):format(
                    opts.return_values == 0 and "Void" or "P",
                    opts.name,
                    args,
                    opts.body
                )
            end
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(",\n")
            return ([[
function %s
{
param (%s)
%s
}]]):format(opts.name, args, opts.body)
        end,
        python = function(opts)
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
            if opts.method then
                args = "self, " .. args
            end
            return ([[
def %s(%s):
%s]]):format(opts.name, args, opts.body)
        end,
        ruby = function(opts)
            local name = opts.singleton and "self." .. opts.name or opts.name
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
            return ([[
def %s(%s):
%s]]):format(name, args, opts.body)
        end,
    },
    function_call = {
        lua = function(opts)
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")

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
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
            if #opts.return_values == 0 then
                return ("%s(%s);"):format(opts.name, args)
            end
            if #opts.return_values == 1 then
                return ("P %s = %s(%s);"):format(
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
            return ("%s(%s);"):format(opts.name, in_n_out)
        end,
        c_sharp = function(opts)
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
            if #opts.return_values == 0 then
                return ("%s(%s);"):format(opts.name, args)
            end
            if #opts.return_values == 1 then
                return ("var %s = %s(%s);"):format(
                    opts.return_values[1],
                    opts.name,
                    args
                )
            end
            return ("var out = %s(%s);"):format(opts.name, args)
        end,
        javascript = function(opts)
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
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
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
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
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
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
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
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
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(" ")
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
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
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
        ruby = function(opts)
            local args = iter(opts.args):map(
                ---@param v refactor.Variable
                function(v)
                    return v.identifier
                end
            ):join(", ")
            if #opts.return_values == 0 then
                return ("%s(%s)"):format(opts.name, args)
            end
            return ("%s = %s(%s)"):format(
                table.concat(opts.return_values, ", "),
                opts.name,
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
        ruby = function(opts)
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
    ruby = {
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
---@field singleton boolean?
---@field struct_name string?
---@field struct_var_name string?

---@param o refactor.Output
---@return TSNode
local function choose_output(o)
    return o.comment and o.comment[1] or o.fn
end

---@param nested_lang_tree vim.treesitter.LanguageTree
---@param query vim.treesitter.Query
---@param buf integer
---@param extract_range Range4
---@return TSNode?
---@return {method: boolean?, singleton: boolean?, struct_name: string?, struct_var_name: string?}?
local function get_output_node(nested_lang_tree, query, buf, extract_range)
    local outputs = {} ---@type refactor.Output[]
    for _, tree in ipairs(nested_lang_tree:trees()) do
        for _, match in query:iter_matches(tree:root(), buf) do
            local output ---@type table|refactor.Output|nil
            for capture_id, nodes in pairs(match) do
                local name = query.captures[capture_id]

                if name == "output.comment" then
                    output = output or {}
                    output.comment = nodes
                elseif name == "output.function" then
                    output = output or {}
                    output.fn = nodes[1]
                elseif name == "output.function.singleton" then
                    output = output or {}
                    output.fn = nodes[1]
                    output.singleton = true
                elseif name == "output.method" then
                    output = output or {}
                    output.fn = nodes[1]
                    output.method = true
                elseif name == "output.method.singleton" then
                    output = output or {}
                    output.fn = nodes[1]
                    output.method = true
                    output.singleton = true
                elseif name == "output.struct_name" then
                    output = output or {}
                    output.struct_name = ts.get_node_text(nodes[1], buf)
                elseif name == "output.struct_var_name" then
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
                local n = choose_output(o)
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
                local n = choose_output(o)
                local n_start_row, n_start_col = n:start()
                local acc_n = choose_output(o)
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

    return choose_output(selected_output),
        {
            method = selected_output.method,
            singleton = selected_output.singleton,
            struct_name = selected_output.struct_name,
            struct_var_name = selected_output.struct_var_name,
        }
end

---@param get_key nil|fun(value: any): any
---@return fun(value: any): boolean
local function is_unique(get_key)
    ---@type {[string]: boolean}
    local already_seen = {}

    ---@param value any
    return function(value)
        local key = get_key and get_key(value) or value
        if already_seen[key] then
            return false
        end
        already_seen[key] = true
        return true
    end
end

---@param scopes TSNode[]
---@param start Range2
---@param end_ Range2
---@return TSNode|nil
local function get_declaration_scope(scopes, start, end_)
    local declaration_scope = iter(scopes):filter(
        ---@param s TSNode
        function(s)
            local scope_range = { s:range() }
            return contains(scope_range, start) and contains(scope_range, end_)
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

    return declaration_scope
end

---@class refactor.Reference
---@field identifier TSNode
---@field type string|nil
---@field reference_type 'read'|'write'
---@field declaration boolean

---@class refactor.Variable
---@field identifier string
---@field type string|nil

---@param extract_range Range4
---@param in_buf integer
---@param output_range Range4
---@param lines string[]
---@param out_buf integer
---@param fn_name string
---@param nested_lang_tree vim.treesitter.LanguageTree
---@param query vim.treesitter.Query
---@param opts {method: boolean?, singleton: boolean?, struct_name: string?, struct_var_name: string?}
local function extract_func(
    extract_range,
    in_buf,
    output_range,
    lines,
    out_buf,
    fn_name,
    nested_lang_tree,
    query,
    opts
)
    local references = {} ---@type refactor.Reference[]
    local scopes = {} ---@type TSNode[]
    for _, tree in ipairs(nested_lang_tree:trees()) do
        for _, match, metadata in query:iter_matches(tree:root(), in_buf) do
            for capture_id, nodes in pairs(match) do
                local name = query.captures[capture_id]
                if name == "reference.identifier" then
                    for i, node in ipairs(nodes) do
                        table.insert(references, {
                            identifier = node,
                            reference_type = metadata.reference_type,
                            type = metadata.types and metadata.types[i],
                            declaration = metadata.declaration ~= nil,
                        })
                    end
                elseif name == "scope" then
                    for _, node in ipairs(nodes) do
                        table.insert(scopes, node)
                    end
                end
            end
        end
    end

    local typed_references = iter(references):filter(
        ---@param r refactor.Reference
        function(r)
            return r.type ~= nil
        end
    ):totable()
    table.sort(
        typed_references,
        ---@param a refactor.Reference
        ---@param b refactor.Reference
        function(a, b)
            local compare_start = compare(
                ---@diagnostic disable-next-line: missing-fields
                { a.identifier:start() },
                ---@diagnostic disable-next-line: missing-fields
                { b.identifier:start() }
            )
            if compare_start == -1 then
                return true
            elseif compare_start == 1 then
                return false
            end
            local compare_end = compare(
                ---@diagnostic disable-next-line: missing-fields
                { a.identifier:end_() },
                ---@diagnostic disable-next-line: missing-fields
                { b.identifier:end_() }
            )
            return compare_end == -1
        end
    )
    ---@type {[TSNode]: {scope: TSNode, types: {[string]: string}}}
    local types_by_scope = iter(typed_references):fold(
        {},
        ---@param acc {[TSNode]: {scope: TSNode, types: {[string]: string}}}
        ---@param r refactor.Reference
        function(acc, r)
            local start_row, start_col, end_row, end_col = r.identifier:range()
            local start_node = { start_row, start_col }
            local end_node = { end_row, end_col }

            local scope = get_declaration_scope(scopes, start_node, end_node)
            if not scope then
                return acc
            end

            acc[scope] = acc[scope] or {}
            acc[scope].types = acc[scope].types or {}
            local identifier = ts.get_node_text(r.identifier, in_buf)
            acc[scope].types[identifier] = r.type --[[@as string]]
            acc[scope].scope = scope
            return acc
        end
    )
    ---@type {scope: TSNode, types: {[string]: string}}[]
    local types_with_scopes = vim.tbl_values(types_by_scope)
    table.sort(
        types_with_scopes,
        ---@param a {scope: TSNode, types: {[string]: string}}
        ---@param b {scope: TSNode, types: {[string]: string}}
        function(a, b)
            local compare_start = compare(
                ---@diagnostic disable-next-line: missing-fields
                { a.scope:start() },
                ---@diagnostic disable-next-line: missing-fields
                { b.scope:start() }
            )
            if compare_start == -1 then
                return false
            elseif compare_start == 1 then
                return true
            end
            local compare_end = compare(
                ---@diagnostic disable-next-line: missing-fields
                { a.scope:end_() },
                ---@diagnostic disable-next-line: missing-fields
                { b.scope:end_() }
            )
            return compare_end ~= -1
        end
    )
    local scoped_types = iter(types_with_scopes):map(
        ---@param a {scope: TSNode, types: {[string]: string}}
        function(a)
            return a.types
        end
    ):totable()

    ---@type refactor.Reference[]
    local references_inside_range = iter(references):filter(
        ---@param r refactor.Reference
        function(r)
            local n = r.identifier
            local start_row, start_col, end_row, end_col = n:range()
            local start_node = { start_row, start_col }
            local end_node = { end_row, end_col }
            local contains_start = contains(extract_range, start_node)
            local contains_end = contains(extract_range, end_node)
            return contains_start and contains_end
        end
    ):totable()

    ---@type refactor.Variable[]
    local variables_inside_range = iter(references_inside_range)
        :map(
            ---@param r refactor.Reference
            function(r)
                local identifier = ts.get_node_text(r.identifier, in_buf)

                local start_row, start_col, end_row, end_col =
                    r.identifier:range()

                local scope = get_declaration_scope(
                    scopes,
                    { start_row, start_col },
                    { end_row, end_col }
                )
                ---@type {[string]: string}|nil
                local types = iter(scoped_types):find(
                    ---@param types {[string]: string}
                    function(types)
                        return types[identifier] ~= nil
                    end
                )
                local type = types and types[identifier]
                return {
                    identifier = identifier,
                    type = type,
                }
            end
        )
        :filter(is_unique(
            ---@param r refactor.Reference
            function(r)
                return r.identifier
            end
        ))
        :totable()

    local reference_to_text =
        ---@param reference refactor.Reference
        function(reference)
            return ts.get_node_text(reference.identifier, in_buf)
        end
    ---@type string[]
    local write_identifiers_inside_range = iter(references_inside_range)
        :filter(
            ---@param r refactor.Reference
            function(r)
                return r.reference_type == "write"
            end
        )
        :map(reference_to_text)
        :filter(is_unique())
        :totable()

    local declarations = iter(references):filter(
        ---@param r refactor.Reference
        function(r)
            return r.declaration
        end
    ):totable()
    ---@type string[]
    local declarations_inside_range = iter(declarations)
        :filter(
            ---@param r refactor.Reference
            function(r)
                local contains_start =
                    ---@diagnostic disable-next-line: missing-fields
                    contains(extract_range, { r.identifier:start() })
                local contains_end =
                    ---@diagnostic disable-next-line: missing-fields
                    contains(extract_range, { r.identifier:end_() })
                return contains_start and contains_end
            end
        )
        :map(reference_to_text)
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
            ---@param r refactor.Reference
            function(r)
                local start_symbol = { r.identifier:start() }
                local end_symbol = { r.identifier:end_() }

                local declaration_scope =
                    get_declaration_scope(scopes, start_symbol, end_symbol)

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
        :map(reference_to_text)
        :totable()
    ---@type refactor.QfItem
    local declarations_before_range = iter(declarations)
        :filter(
            ---@param r refactor.Reference
            function(r)
                local start_symbol = { r.identifier:start() }
                local end_symbol = { r.identifier:end_() }

                local declaration_scope =
                    get_declaration_scope(scopes, start_symbol, end_symbol)

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
        :map(reference_to_text)
        :totable()

    ---@type refactor.Variable[]
    local args = iter(variables_inside_range):filter(
        ---@param r refactor.Variable
        function(r)
            return not vim.tbl_contains(
                    declarations_inside_range,
                    r.identifier
                )
                and not vim.tbl_contains(
                    declarations_before_output_range,
                    r.identifier
                )
                and vim.tbl_contains(declarations_before_range, r.identifier)
        end
    ):totable()

    ---@type string[]
    local identifiers_after_range = iter(references)
        :filter(
            ---@param r refactor.Reference
            function(r)
                local n = r.identifier
                local start_row, start_col, end_row, end_col = n:range()
                local start_node = { start_row, start_col }
                local end_node = { end_row, end_col }

                local declaration_scope =
                    get_declaration_scope(scopes, start_node, end_node)
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
        :map(reference_to_text)
        :filter(is_unique())
        :totable()
    local return_values = iter(identifiers_after_range):filter(
        ---@param r string
        function(r)
            -- TODO: maybe limit to write_identifiers that are not declarations
            return vim.tbl_contains(write_identifiers_inside_range, r)
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
    local indent_width = vim.bo[in_buf].shiftwidth > 0
            and vim.bo[in_buf].shiftwidth
        or vim.bo[in_buf].tabstop
    body = vim.text.indent(1 * indent_width, body)
    local function_definition = code_generation.function_declaration[lang]({
        args = args,
        body = body,
        name = fn_name,
        return_values = return_values,
        method = opts.method,
        singleton = opts.singleton,
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
        in_buf,
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

        extract_func(
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
                singleton = opts and opts.singleton,
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
                singleton = opts and opts.singleton,
                struct_name = opts and opts.struct_name,
                struct_var_name = opts and opts.struct_var_name,
            }
        )
    end)
    task:raise_on_error()
end

return M
