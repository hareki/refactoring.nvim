local utils = require("refactoring.utils")
local Pipeline = require("refactoring.pipeline")
local tasks = require("refactoring.tasks")
local code_utils = require("refactoring.code_generation.utils")
local Region = require("refactoring.region")
local text_edits_utils = require("refactoring.text_edits_utils")
local Query = require("refactoring.query")
local ui = require("refactoring.ui")
local indent = require("refactoring.indent")
local notify = require("refactoring.notify")

local api = vim.api

local M = {}

---@param refactor refactor.Refactor
---@return string[]
local function get_return_vals(refactor)
    ---@param node TSNode
    ---@return TSNode[]
    local function node_to_parent_if_needed(node)
        if refactor.ts.should_check_parent_node(node) then
            local parent = assert(node:parent()) -- assert may return multiple values when running inside of plenary, causing errors on the iter pipeline
            return parent
        end
        return node
    end

    local local_declarations =
        refactor.ts:get_local_declarations(refactor.scope)

    local region_declarations = vim.iter(local_declarations)
        :filter(function(node)
            return utils.region_intersect(node, refactor.region)
        end)
        :map(
            ---@param node TSNode
            ---@return TSNode
            function(node)
                return refactor.ts:get_local_var_names(node)[1]
            end
        )
        :filter(
            ---@param node TSNode
            function(node)
                return not not node
            end
        )
        :map(node_to_parent_if_needed)
        :totable()

    local refs = vim.iter(refactor.ts:get_references(refactor.scope))
        :filter(function(node)
            return utils.after_region(node, refactor.region)
        end)
        :map(node_to_parent_if_needed)
        :totable()

    local bufnr = refactor.buffers[1]
    local region_var_map = utils.nodes_to_text_set(bufnr, region_declarations)

    local ref_map = utils.nodes_to_text_set(bufnr, refs)
    local return_vals =
        vim.tbl_keys(utils.table_key_intersect(region_var_map, ref_map))
    table.sort(return_vals)

    return return_vals
end

local function get_function_return_type()
    local function_return_type =
        ui.input("106: Extract Function return type > ")
    if function_return_type == "" then
        function_return_type = code_utils.default_func_return_type()
    end
    return function_return_type
end

---@param refactor refactor.Refactor
---@param args string[]
---@return table<string, string|nil>
local function get_function_param_types(refactor, args)
    local args_types = {} ---@type table<string, string>

    local local_types = refactor.ts:get_local_types(refactor.scope)

    for _, arg in pairs(args) do
        ---@type string|nil
        local function_param_type
        local curr_arg = refactor.ts.get_arg_type_key(arg)

        if local_types[curr_arg] ~= nil then
            function_param_type = local_types[curr_arg]
        elseif
            refactor.config:get_prompt_func_param_type(refactor.filetype)
        then
            function_param_type = ui.input(
                ("106: Extract Function param type for %s > "):format(arg)
            )

            if function_param_type == "" then
                function_param_type = code_utils.default_func_param_type()
            end
        else
            function_param_type = code_utils.default_func_param_type()
        end
        ---@type string|nil
        args_types[curr_arg] = function_param_type
    end

    return args_types
end

---@param refactor refactor.Refactor
local function get_func_header_prefix(refactor)
    local indent_width = indent.buf_indent_width(refactor.bufnr)
    local scope_region = Region:from_node(refactor.scope, refactor.bufnr)
    local min_indent = math.min(scope_region.end_col, scope_region.start_col)
    local baseline_indent = math.floor(min_indent / indent_width)
    return indent.indent(baseline_indent, refactor.bufnr)
end

---@param refactor refactor.Refactor
local function get_indent_prefix(refactor)
    local ident_width = indent.buf_indent_width(refactor.bufnr)
    local first_node_in_row, _ = utils.get_first_node_in_row(refactor.scope)
    local scope_region = Region:from_node(first_node_in_row, refactor.bufnr)
    local scope_start_col = scope_region.start_col
    local baseline_indent = math.floor(scope_start_col / ident_width)
    local total_indents = baseline_indent + 1
    return indent.indent(total_indents, refactor.bufnr)
end

---@param function_params refactor.FuncParams
---@param has_return_vals boolean
---@param refactor refactor.Refactor
local function indent_func_code(function_params, has_return_vals, refactor)
    if refactor.ts:is_indent_scope(refactor.scope) then
        local func_header_indent = get_func_header_prefix(refactor)
        function_params.func_header = func_header_indent
    end

    -- Removing indent_chars up to initial indent
    -- Not removing indent for return statement like rest of func body
    local lines_to_remove = #function_params.body
    if has_return_vals then
        lines_to_remove = lines_to_remove - 1
    end
    indent.lines_remove_indent(
        function_params.body,
        1,
        lines_to_remove,
        refactor.whitespace.func_call,
        refactor.bufnr
    )

    local indent_prefix = get_indent_prefix(refactor)
    for i = 1, #function_params.body do
        if function_params.body[i] ~= "" then
            function_params.body[i] =
                table.concat({ indent_prefix, function_params.body[i] }, "")
        end
    end
end

---@class refactor.FuncParams
---@field func_header? string
---@field args_types? table<string, string>
---@field contains_jsx? boolean
---@field class_name? string
---@field visibility? string
---@field name? string
---@field args? string[]
---@field body? string[]
---@field scope_type? string
---@field region_type? string

---@param extract_params refactor.ExtractParams
---@param refactor refactor.Refactor
---@return refactor.FuncParams
local function get_func_params_opts(extract_params, refactor)
    local func_params = {
        name = extract_params.function_name,
        args = extract_params.args,
        body = extract_params.function_body,
        scope_type = extract_params.scope_type,
        region_type = refactor.region:to_ts_node(refactor.ts:get_root()):type(),
        visibility = refactor.config:get_visibility_for(refactor.filetype),
    }

    if refactor.ts.require_param_types then
        func_params.args_types =
            get_function_param_types(refactor, func_params.args)
    end

    if
        extract_params.has_return_vals
        and refactor.config:get_prompt_func_return_type(refactor.filetype)
    then
        func_params.return_type = get_function_return_type()
    end

    if refactor.ts:indent_scopes_support() then
        indent_func_code(func_params, extract_params.has_return_vals, refactor)
    end
    return func_params
end

---@param refactor refactor.Refactor
---@param extract_params refactor.ExtractParams
---@return string
local function get_function_code(refactor, extract_params)
    ---@type string
    local function_code
    local func_params_opts = get_func_params_opts(extract_params, refactor)

    if extract_params.is_class then
        func_params_opts.class_name = refactor.ts:get_class_name(refactor.scope)
        func_params_opts.visibility =
            refactor.config:get_visibility_for(refactor.filetype)
        if extract_params.has_return_vals then
            function_code =
                refactor.code.class_function_return(func_params_opts)
        else
            function_code = refactor.code.class_function(func_params_opts)
        end
    elseif extract_params.has_return_vals then
        function_code = refactor.code.function_return(func_params_opts)
    else
        function_code = refactor.code["function"](func_params_opts)
    end
    return function_code
end

---@param refactor refactor.Refactor
---@param extract_params refactor.ExtractParams
---@return string
local function get_func_call(refactor, extract_params)
    ---@type string
    local func_call
    if extract_params.is_class then
        func_call = refactor.code.call_class_function({
            name = extract_params.function_name,
            args = extract_params.args,
            class_type = refactor.ts:get_class_type(refactor.scope),
        })
    else
        -- TODO (TheLeoP): jsx specific logic
        local ok, ocurrences = pcall(
            Query.find_occurrences,
            refactor.scope,
            "(jsx_element) @tmp_capture",
            refactor.bufnr
        )
        local contains_jsx = ok and #ocurrences > 0
        func_call = refactor.code.call_function({
            name = extract_params.function_name,
            args = extract_params.args,
            region_type = extract_params.region_type,
            contains_jsx = contains_jsx,
        })
    end

    -- in some languages (like typescript and javascript), you can return
    -- multiple values in an object, but treesitter still sees that as multiple
    -- values instead of just one object, which causes odd behaviour
    local exception_languages = {
        typescript = true,
        javascript = true,
        typescriptreact = true,
    }

    if extract_params.has_return_vals then
        if
            #extract_params.return_vals > 1
            and exception_languages[refactor.filetype] == nil
        then
            func_call = refactor.code.constant({
                multiple = true,
                identifiers = extract_params.return_vals,
                values = { func_call },
            })
        else
            func_call = refactor.code.constant({
                name = extract_params.return_vals,
                value = func_call,
            })
        end
    else
        func_call = refactor.code.terminate(func_call)
    end

    local starting_pos = refactor.region:get_start_point()
    local current_statement_line = api.nvim_buf_get_lines(
        refactor.bufnr,
        starting_pos.row - 1,
        starting_pos.row,
        true
    )[1]
    local indent_amount =
        indent.line_indent_amount(current_statement_line, refactor.bufnr)
    local indentation = indent.indent(indent_amount, refactor.bufnr)

    func_call = table.concat({ indentation, func_call })

    return func_call
end

---@param refactor refactor.Refactor
---@return boolean, refactor.Refactor|string
local function extract_setup(refactor)
    local function_name = ui.input("106: Extract Function Name > ")
    if not function_name or function_name == "" then
        return false, "Error: Must provide function name"
    end
    local function_body = refactor.region:get_text()

    -- NOTE: How do we think about this if we have to pass through multiple
    -- functions (method extraction)
    local ok, locals = pcall(utils.get_selected_locals, refactor)
    if not ok then
        return ok, locals
    end
    local args = vim.tbl_keys(locals) --[=[@as string[]]=]
    table.sort(args)

    local first_line = function_body[1]

    refactor.whitespace.func_call =
        indent.line_indent_amount(first_line, refactor.bufnr)

    local ok2, return_vals = pcall(get_return_vals, refactor)
    if not ok2 then
        return ok2, return_vals
    end
    local has_return_vals = #return_vals > 0
    if has_return_vals then
        table.insert(
            function_body,
            refactor.code["return"](refactor.code.pack(return_vals))
        )
    end

    local is_class = refactor.ts:is_class_function(refactor.scope)

    ---@class refactor.ExtractParams
    local extract_params = {
        return_vals = return_vals,
        has_return_vals = has_return_vals,
        is_class = is_class,
        args = args,
        function_name = function_name,
        function_body = function_body,
        ---@type string
        scope_type = refactor.scope:type(),
        ---@type string
        region_type = refactor.region:to_ts_node(refactor.ts:get_root()):type(),
    }

    local ok3, function_code =
        pcall(get_function_code, refactor, extract_params)
    if not ok3 then
        return ok3, function_code
    end
    local region_above_scope = utils.get_non_comment_region_above_node(refactor)

    ---@type refactor.TextEdit
    local extract_function
    if is_class then
        extract_function = text_edits_utils.insert_new_line_text(
            region_above_scope,
            function_code,
            { below = true, _end = true }
        )
    else
        extract_function = text_edits_utils.insert_new_line_text(
            region_above_scope,
            function_code,
            { below = true }
        )
        ---@type integer
        extract_function.bufnr = refactor.buffers[2]
    end

    refactor.text_edits = {}
    -- NOTE: there is going to be a bunch of edge cases we haven't thought
    -- about
    table.insert(refactor.text_edits, extract_function)

    local lang = refactor.lang

    local selected_code = table.concat(refactor.region:get_text(), "\n")
    local parser = vim.treesitter.get_string_parser(selected_code, lang)
    local languagetree = parser:parse()
    local root = languagetree[1]:root()
    local has_error = root:has_error() --[[@as boolean]]

    local ok4, func_call = pcall(get_func_call, refactor, extract_params)
    if not ok4 then
        return ok4, func_call
    end

    -- PHP parser needs the PHP tag to parse code, so it's imposible to generate
    -- an adecuate sexpr with only the selected text
    --
    -- C# parser parses expresions without a surrounding scope as childs of the
    -- `global_statement` node, so it's imposibble to match them against
    -- non-global statements
    --
    -- TSX/JSX parser parses isolated tags as having an expression parent
    local number_of_function_calls = 0
    if
        not has_error
        and refactor.filetype ~= "php"
        and refactor.filetype ~= "cs"
        and refactor.filetype ~= "typescriptreact"
        and refactor.filetype ~= "javascriptreact"
    then
        ---@type string[]
        local body_sexprs = {}
        do
            local i = 1
            for node in root:iter_children() do
                table.insert(body_sexprs, node:sexpr() .. " @temp" .. i)
                i = i + 1
            end
        end

        local body_sexpr = "(" .. table.concat(body_sexprs, " . ") .. ")"
        local query = vim.treesitter.query.parse(lang, body_sexpr)

        local matches = query:iter_matches(
            refactor.root,
            refactor.bufnr,
            0,
            -1,
            { all = false }
        )
        for _, match in matches do
            if match then
                local first = match[1] --[[@as TSNode]]
                local last = match[#match] --[[@as TSNode]]
                local start_row, _, _, _ = first:range()
                local _, _, end_row, end_col = last:range()

                local region = Region:from_values(
                    refactor.bufnr,
                    start_row + 1,
                    1,
                    end_row + 1,
                    end_col
                )

                if
                    table.concat(region:get_text(), "")
                    == table.concat(refactor.region:get_text(), "")
                then
                    number_of_function_calls = number_of_function_calls + 1
                    table.insert(
                        refactor.text_edits,
                        text_edits_utils.replace_text(region, func_call)
                    )
                end
            end
        end
    else
        number_of_function_calls = 1
        table.insert(
            refactor.text_edits,
            text_edits_utils.replace_text(refactor.region, func_call)
        )
    end
    refactor.success_message = ("Function extracted. Inlined %s function calls"):format(
        number_of_function_calls
    )

    return true, refactor
end

local ensure_code_gen_list = {
    "return",
    "pack",
    "call_function",
    "constant",
    "function",
    "function_return",
    "terminate",
}

local class_code_gen_list = {
    "class_function",
    "class_function_return",
    "call_class_function",
}

---@param refactor refactor.Refactor
local function ensure_code_gen_106(refactor)
    local list = {}
    for _, func in ipairs(ensure_code_gen_list) do
        table.insert(list, func)
    end

    if refactor.ts:class_support() then
        for _, func in ipairs(class_code_gen_list) do
            table.insert(list, func)
        end
    end

    return tasks.ensure_code_gen(refactor, list)
end

---@param bufnr integer
---@param region_type 'v' | 'V' | '' | nil
---@param opts refactor.Config
M.extract_to_file = function(bufnr, region_type, opts)
    local seed = tasks.refactor_seed(bufnr, region_type, opts)
    Pipeline:from_task(tasks.operator_setup)
        :add_task(ensure_code_gen_106)
        :add_task(tasks.create_file_from_input)
        :add_task(extract_setup)
        :after(tasks.multiple_files_post_refactor)
        :run(nil, notify.error, seed)
end

-- NOTE: post-rewrite

local contains = require("refactoring.range").contains
local compare = require("refactoring.range").compare
local async = require("async")
local lsp = vim.lsp
local iter = vim.iter
local ts = vim.treesitter

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
---@field function_declaration {[string]: fun(opts: {args: string[], name: string, body: string, return_values: string[]}):string}
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
                        and ("\nreturn %s\n"):format(
                            table.concat(opts.return_values, ",")
                        )
                    or ""
            )
        end,
    },
    function_call = {
        lua = function(opts)
            local args = table.concat(opts.args, ", ")

            return ("%s%s(%s)"):format(
                not vim.tbl_isempty(opts.return_values)
                        and ("local %s ="):format(
                            table.concat(opts.return_values, ",")
                        )
                    or "",
                opts.name,
                args
            )
        end,
    },
}

---@type {[string]: string[]}
local globals = {
    lua = {
        "dofile",
        "next",
        "print",
        "tonumber",
        "tostring",
        "type",
        "error",
        "collectgarbage",
        "getfenv",
        "getmetatable",
        "setmetatable",
        "ipairs",
        "pairs",
        "loadfile",
        "loadstring",
        "module",
        "package",
        "pcall",
        "xpcall",
        "rawequal",
        "rawget",
        "rawset",
        "require",
        "select",
        "setfenv",
        "unpack",

        "debug",
        "os",
        "coroutine",
        "math",
        "io",
        "string",
        "table",

        "vim",
    },
}

---@class refactor.Output
---@field comment TSNode[]?
---@field fn TSNode

-- TODO: `extract_to_file`
-- TODO: when using `extraact_to_file` maybe also generate the import logic
-- TODO: handle indentation (maybe using the builtin [Neo]vim functions)
-- TODO: remove `buf` from all calls after the rewrite is finished
---@param buf integer
---@param region_type 'v' | 'V' | ''
M.extract_func = function(buf, region_type)
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

    local task = async.run(function()
        local lang_tree, err1 = ts.get_parser(nil, nil, { error = false })
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
                ("There is no `refactor` query file for language %s"):format(
                    lang
                ),
                vim.log.levels.ERROR
            )
            return
        end
        local reference_nodes = {} ---@type TSNode[]
        local outputs = {} ---@type refactor.Output[]
        for _, tree in ipairs(nested_lang_tree:trees()) do
            for _, match in query:iter_matches(tree:root(), buf) do
                local output ---@type table|refactor.Output|nil
                for capture_id, nodes in pairs(match) do
                    local name = query.captures[capture_id]
                    local is_identifier = name == "reference.identifier"
                    local is_output_function = name == "output.function"
                    local is_output_comment = name == "output.comment"
                    if is_identifier then
                        for _, node in ipairs(nodes) do
                            table.insert(reference_nodes, node)
                        end
                    elseif is_output_comment then
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

                    local o_row_distance =
                        math.abs(n_start_row - extract_range[1])
                    local acc_row_distance =
                        math.abs(acc_start_row - extract_range[1])
                    if acc_row_distance < o_row_distance then
                        return acc
                    end

                    local o_col_distance =
                        math.abs(n_start_col - extract_range[2])
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
        if not selected_output_node then
            vim.notify(
                "Couldn't find an output region in which to extract the function"
            )
            return
        end
        local output_range = { selected_output_node:range() }

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

        local declarations = get_symbols()
        ---@type refactor.QfItem
        local declarations_inside_region = iter(declarations)
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
        ---@type refactor.QfItem
        local declarations_above_output_region = iter(declarations)
            :filter(
                ---@param s refactor.QfItem
                function(s)
                    local start_symbol = { s.lnum - 1, s.col - 1 }
                    local end_symbol = { s.end_lnum - 1, s.end_col - 1 }
                    local start_output = { output_range[1], output_range[2] }
                    local compare_start = compare(start_symbol, start_output)
                    local compare_end = compare(end_symbol, start_output)
                    return compare_start ~= 1 and compare_end ~= 1
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
                return not vim.tbl_contains(declarations_inside_region, r)
                    and not vim.tbl_contains(
                        declarations_above_output_region,
                        r
                    )
                    and not vim.tbl_contains(globals[lang], r)
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
                return vim.tbl_contains(declarations_inside_region, r)
            end
        ):totable()

        local body = table.concat(lines, "\n")
        local fn_name = input({ prompt = "Function name: " })
        local function_definition = code_generation.function_declaration[lang]({
            args = args,
            body = body,
            name = fn_name,
            return_values = return_values,
        }) .. "\n\n"
        local function_call = code_generation.function_call[lang]({
            args = args,
            name = fn_name,
            return_values = return_values,
        })

        api.nvim_buf_set_text(
            buf,
            extract_range[1],
            extract_range[2],
            extract_range[3],
            extract_range[4],
            vim.split(function_call, "\n")
        )

        local output_row, output_col = selected_output_node:start()
        api.nvim_buf_set_text(
            buf,
            output_row,
            output_col,
            output_row,
            output_col,
            vim.split(function_definition, "\n")
        )

        -- TODO: support all languages
        -- TODO: maybe use LSP to infer the types of parameters for code
        -- generation if possible(?
        -- TODO: maybe use snippets to expand the generated function and
        -- navigate through type placeholders?
    end)
    task:raise_on_error()
end

return M
