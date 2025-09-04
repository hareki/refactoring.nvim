local iter = vim.iter
local ts = vim.treesitter

-- TODO: move this into another lua file in order to lazy load it with require
---@type {[string]: nil|fun(opts: {value: TSNode}): string|vim.NIL}
local infer_type = {
    lua = function(opts)
        local type ---@type string|vim.NIL
        local node_type = opts.value:type()
        if node_type == "number" then
            type = "number"
        elseif node_type == "string" then
            type = "string"
        elseif node_type == "true" or node_type == "false" then
            type = "boolean"
        elseif node_type == "nil" then
            type = "nil"
        elseif node_type == "function_definition" then
            type = "function"
        elseif node_type == "table_constructor" then
            type = "table"
        else
            type = vim.NIL
        end
        return type
    end,
}

ts.query.add_directive(
    "infer-type!",
    function(match, pattern, source, predicate, metadata)
        local lang = predicate[2] --[[@as string]]
        local values_id = predicate[3]

        local values = match[values_id]
        local infer_type_lang = infer_type[lang]
        if not infer_type_lang then
            return
        end
        local types = iter(values):map(function(value)
            return infer_type_lang({ value = value })
        end):totable()
        metadata.types = types
    end,
    { force = true, all = true }
)

-- TODO: move this into another lua file in order to lazy load it with require
---@type {[string]: nil|fun(opts: {types: TSNode[], identifiers: TSNode[], source: integer|string}): string[]}
local get_type = {
    c = function(opts)
        local types ---@type string[]
        if #opts.types == #opts.identifiers then
            types = iter(opts.types):map(
                ---@param n TSNode
                function(n)
                    return ts.get_node_text(n, opts.source)
                end
            ):totable()
        else
            local type = ts.get_node_text(opts.types[1], opts.source)
            types = iter(opts.identifiers):map(function()
                return type
            end):totable()
        end
        return types
    end,
}

ts.query.add_directive(
    "set-type!",
    function(match, pattern, source, predicate, metadata)
        local lang = predicate[2] --[[@as string]]
        local type_id = predicate[3]
        local identifier_id = predicate[4]
        local get_type_lang = get_type[lang]
        if not get_type_lang then
            return
        end
        local types = get_type_lang({
            types = match[type_id],
            identifiers = match[identifier_id],
            source = source,
        })
        metadata.types = types
    end,
    { force = true, all = true }
)
