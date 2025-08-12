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

---@class refactor.code_generation
---@field function_declaration {[string]: fun(opts: {args: string[], name: string, body: string, return_values: string[], indent_width: integer}):string}
---@field function_call {[string]: fun(opts: {args: string[], name: string, return_values: string[]}):string}

-- TODO: move into it's own file or something(?
---@type refactor.code_generation
local code_generation = {
    function_declaration = {
        lua = function(opts)
            local args = table.concat(opts.args, ", ")

            return ([[
local function %s(%s)
%s%s
end]]):format(
                opts.name,
                args,
                opts.body,
                not vim.tbl_isempty(opts.return_values)
                        and vim.text.indent(
                            1 * opts.indent_width,
                            ("\n\nreturn %s"):format(
                                table.concat(opts.return_values, ",")
                            )
                        )
                    or ""
            )
        end,
        -- TODO: handle multiple return values
        c = function(opts)
            -- TODO: infer types somehow

            local has_return_value = #opts.return_values == 1
            local return_type = has_return_value and "void" or "P"
            local args = iter(opts.args):map(function(a)
                return "P " .. a
            end):join(", ")
            return ([[
%s %s(%s) {
%s%s
}]]):format(
                return_type,
                opts.name,
                args,
                opts.body,
                has_return_value
                        and ("\n\nreturn %s"):format(opts.return_values[1])
                    or ""
            )
        end,
    },
    function_call = {
        lua = function(opts)
            local args = table.concat(opts.args, ", ")

            local has_return_values = not vim.tbl_isempty(opts.return_values)
            return ("%s%s(%s)"):format(
                has_return_values
                        and ("local %s = "):format(
                            table.concat(opts.return_values, ",")
                        )
                    or "",
                opts.name,
                args
            )
        end,
        -- TODO: handle mutiple return values
        c = function(opts)
            local has_return_value = #opts.return_values == 1
            return ("%s%s(%s);"):format(
                has_return_value and ("P %s = "):format(opts.return_values[1])
                    or "",
                opts.name,
                table.concat(opts.args, ", ")
            )
        end,
    },
}

---@class refactor.Output
---@field comment TSNode[]?
---@field fn TSNode

---@param nested_lang_tree vim.treesitter.LanguageTree
---@param query vim.treesitter.Query
---@param buf integer
---@param extract_range Range4
---@return TSNode?
local function get_output_node(nested_lang_tree, query, buf, extract_range)
    local outputs = {} ---@type refactor.Output[]
    for _, tree in ipairs(nested_lang_tree:trees()) do
        for _, match in query:iter_matches(tree:root(), buf) do
            local output ---@type table|refactor.Output|nil
            for capture_id, nodes in pairs(match) do
                local name = query.captures[capture_id]
                local is_output_function = name == "output.function"
                local is_output_comment = name == "output.comment"
                if is_output_comment then
                    output = output or {}
                    output.comment = nodes
                elseif is_output_function then
                    output = output or {}
                    output.fn = nodes[1]
                end
            end
            if output then
                table.insert(outputs, output)
            end
        end
    end

    ---@type TSNode|nil
    local selected_output_node = iter(outputs)
        :filter(
            ---@param o refactor.Output
            function(o)
                local parent = o.fn:parent()
                if not parent then
                    return false
                end
                local grandparent = parent:parent()
                return grandparent == nil
            end
        )
        :map(
            ---@param o refactor.Output
            function(o)
                -- TODO: add decorators for languages like python
                return o.comment and o.comment[1] or o.fn
            end
        )
        :filter(
            ---@param n TSNode
            function(n)
                local start_row, start_col = n:start()
                return compare(
                    { start_row, start_col },
                    { extract_range[1], extract_range[2] }
                ) == -1
            end
        )
        :fold(
            nil,
            ---@param acc TSNode|nil
            ---@param n TSNode
            function(acc, n)
                if not acc then
                    return n
                end
                local n_start_row, n_start_col = n:start()
                local acc_start_row, acc_start_col = acc:start()

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
                return n
            end
        )

    return selected_output_node
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
local function extract_func(
    declarations,
    extract_range,
    buf,
    output_range,
    lines,
    out_buf,
    fn_name,
    nested_lang_tree,
    query
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
    local references_inside_region = iter(reference_nodes)
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
                local start_extract = { extract_range[1], extract_range[2] }
                local end_extract = { extract_range[3], extract_range[4] }

                ---@type TSNode|nil
                local declaration_scope = iter(scopes):filter(
                    ---@param s TSNode
                    function(s)
                        local scope_range = { s:range() }
                        return contains(scope_range, start_extract)
                            and contains(scope_range, end_extract)
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

                local start_symbol = { d.lnum - 1, d.col - 1 }
                local end_symbol = { d.end_lnum - 1, d.end_col - 1 }
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

    local args = iter(references_inside_region):filter(
        ---@param r string
        function(r)
            return not vim.tbl_contains(declarations_inside_range, r)
                and not vim.tbl_contains(declarations_before_output_range, r)
                and vim.tbl_contains(declarations_before_range, r)
        end
    ):totable()

    already_seen = {}
    local references_after_region = iter(reference_nodes)
        :filter(
            ---@param r TSNode
            function(r)
                local start_row, start_col, end_row, end_col = r:range()
                local start_node = { start_row, start_col }
                local end_node = { end_row, end_col }
                local extract_end = { extract_range[3], extract_range[4] }
                local compare_start = compare(start_node, extract_end)
                local compare_end = compare(end_node, extract_end)
                return compare_start == 1 and compare_end == 1
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
    local return_values = iter(references_after_region):filter(
        ---@param r string
        function(r)
            return vim.tbl_contains(declarations_inside_range, r)
        end
    ):totable()

    local indent_width = vim.bo[buf].shiftwidth > 0 and vim.bo[buf].shiftwidth
        or vim.bo[buf].tabstop
    local body = table.concat(lines, "\n")
    local body_indent ---@type integer
    body, body_indent = vim.text.indent(1 * indent_width, body)
    local lang = nested_lang_tree:lang()
    local function_definition = code_generation.function_declaration[lang]({
        args = args,
        body = body,
        name = fn_name,
        return_values = return_values,
        indent_width = indent_width,
    }) .. "\n\n"
    local function_call = code_generation.function_call[lang]({
        args = args,
        name = fn_name,
        return_values = return_values,
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

    api.nvim_buf_set_text(
        out_buf,
        output_range[1],
        output_range[2],
        output_range[1],
        output_range[2],
        vim.split(function_definition, "\n")
    )

    -- TODO: maybe use snippets to expand the generated function and
    -- navigate through type placeholders?
end

---@param region_type 'v'|'V'|''
---@return Range4, string[]
local function get_extracted_region(region_type)
    local buf = api.nvim_get_current_buf()
    local range_start = vim.fn.getpos("'[")
    local range_end = vim.fn.getpos("']")

    local range_last_line =
        api.nvim_buf_get_lines(buf, range_end[2] - 1, range_end[2], true)[1]

    local extract_range = {
        range_start[2] - 1,
        region_type ~= "V" and range_start[3] - 1 or 0,
        range_end[2] - 1,
        region_type ~= "V" and range_end[3] - 1 or #range_last_line,
    }
    local lines =
        vim.fn.getregion(range_start, range_end, { type = region_type })

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
-- TODO: remove `buf` from all calls after the rewrite is finished
---@param buf integer
---@param region_type 'v' | 'V' | ''
M.extract_func = function(buf, region_type)
    local buf = api.nvim_get_current_buf()
    local extract_range, lines = get_extracted_region(region_type)

    local task = async.run(function()
        local fn_name = input({ prompt = "Function name: " })
        if not fn_name then
            return
        end

        local nested_lang_tree, query = ts_parse(buf, extract_range)
        if not nested_lang_tree or not query then
            return
        end

        local output_node =
            get_output_node(nested_lang_tree, query, buf, extract_range)
        if not output_node then
            vim.notify(
                "Couldn't find an output region in which to extract the function"
            )
            return
        end
        local output_range = { output_node:range() }

        -- TODO: clangd doesn't return symbols for local variables. So,
        -- fallback to treesitter somehow
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
            query
        )
    end)
    task:raise_on_error()
end

-- TODO: maybe also generate the import logic(?
---@param buf integer
---@param region_type 'v' | 'V' | ''
M.extract_func_to_file = function(buf, region_type)
    local buf = api.nvim_get_current_buf()
    local extract_range, lines = get_extracted_region(region_type)

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
        local output_node =
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
            query
        )
    end)
    task:raise_on_error()
end

return M
