local iter = vim.iter
local ts = vim.treesitter

-- TODO: move this into another lua file in order to lazy load ir with require
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
        local lang = predicate[2]
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
