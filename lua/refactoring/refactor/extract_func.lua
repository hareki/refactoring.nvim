local async = require "async"
local pos = require "refactoring.pos"
local range = require "refactoring.range"
local iter = vim.iter
local ts = vim.treesitter
local api = vim.api

local M = {}

---@class refactor.extract_func.code_generation.function_declaration.Opts
---@field args refactor.Variable[]
---@field name string
---@field body string
---@field return_values refactor.Variable[]
---@field method boolean?
---@field singleton boolean?
---@field struct_var_name string?
---@field struct_name string?

---@class refactor.extract_func.code_generation.function_call.Opts
---@field args string[]
---@field name string
---@field return_values refactor.Variable[]
---@field method boolean?
---@field struct_var_name string?

---@class refactor.extract_func.code_generation.return_statement.Opts
---@field return_values refactor.Variable[]

---@class refactor.extract_func.CodeGeneration
---@field function_declaration {[string]: nil|fun(opts: refactor.extract_func.code_generation.function_declaration.Opts): string}
---@field function_call {[string]: nil|fun(opts: refactor.extract_func.code_generation.function_call.Opts): string}
---@field return_statement {[string]: nil|fun(opts: refactor.extract_func.code_generation.return_statement.Opts): string}

---@class refactor.extract_func.UserCodeGeneration
---@field function_declaration? {[string]: nil|fun(opts: refactor.extract_func.code_generation.function_declaration.Opts): string}
---@field function_call? {[string]: nil|fun(opts: refactor.extract_func.code_generation.function_call.Opts): string}
---@field return_statement? {[string]: nil|fun(opts: refactor.extract_func.code_generation.return_statement.Opts): string}

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
---@param extracted_range vim.Range
---@return TSNode?
---@return {method: boolean?, singleton: boolean?, struct_name: string?, struct_var_name: string?}
local function get_output_node(nested_lang_tree, query, buf, extracted_range)
  local is_first_closer = require("refactoring.utils").is_first_closer

  local outputs = {} ---@type refactor.Output[]
  for _, tree in ipairs(nested_lang_tree:trees()) do
    for _, match, metadata in query:iter_matches(tree:root(), buf) do
      local output ---@type table|refactor.Output|nil
      for capture_id, nodes in pairs(match) do
        local name = query.captures[capture_id]

        -- TODO: split input.info and output location
        if name == "output.comment" then
          output = output or {}
          output.comment = nodes
        elseif name == "output.function" then
          output = output or {}
          output.fn = nodes[1]
          output.method = metadata.method ~= nil
          output.singleton = metadata.singleton ~= nil

          local struct_name = metadata.struct_name
          if struct_name then output.struct_name = ts.get_node_text(match[struct_name][1], buf) end
          local struct_var_name = metadata.struct_var_name
          if struct_var_name then output.struct_var_name = ts.get_node_text(match[struct_var_name][1], buf) end
        end
      end
      if output then table.insert(outputs, output) end
    end
  end

  ---@type refactor.Output|nil
  local selected_output = iter(outputs)
    :filter(
      ---@param o refactor.Output
      function(o)
        local n = choose_output(o)
        local n_start = pos.treesitter(buf, "start", n:start())
        return n_start < extracted_range.start
      end
    )
    :fold(
      nil,
      ---@param acc refactor.Output|nil
      ---@param o refactor.Output
      function(acc, o)
        if not acc then return o end

        local n = choose_output(o)
        local o_start = pos.treesitter(buf, "start", n:start())
        local acc_n = choose_output(acc)
        local acc_start = pos.treesitter(buf, "start", acc_n:start())

        local is_o_closer = is_first_closer(o_start, acc_start, extracted_range.start)
        if is_o_closer then return o end
        return acc
      end
    )

  if not selected_output then return nil, {} end

  return choose_output(selected_output),
    {
      method = selected_output.method,
      singleton = selected_output.singleton,
      struct_name = selected_output.struct_name,
      struct_var_name = selected_output.struct_var_name,
    }
end

---@param buf integer
---@param extracted_range Range4
---@return vim.treesitter.LanguageTree?, vim.treesitter.Query?
local function ts_parse(buf, extracted_range)
  local lang_tree, err1 = ts.get_parser(buf, nil, { error = false })
  if not lang_tree then
    vim.notify(err1, vim.log.levels.ERROR)
    return
  end
  -- TODO: use async parsing
  lang_tree:parse(true)
  local nested_lang_tree = lang_tree:language_for_range(extracted_range)
  local lang = nested_lang_tree:lang()
  local query = ts.query.get(lang, "refactor")
  if not query then
    vim.notify(("There is no `refactor` query file for language %s"):format(lang), vim.log.levels.ERROR)
    return
  end

  return nested_lang_tree, query
end

---@class refactor.Reference
---@field identifier TSNode
---@field type string|{identifier: string}|vim.NIL|nil
---@field reference_type 'read'|'write'
---@field declaration boolean

---@class refactor.Variable
---@field identifier string
---@field type string|nil

---@class refactor.extract_func.Opts
---@field extracted_range vim.Range
---@field in_buf integer
---@field lines string[]
---@field out_buf integer
---@field fn_name string
---@field config_opts refactor.refactor.extract_func.Opts

---@param opts refactor.extract_func.Opts
local function extract_func(opts)
  local apply_text_edits = require("refactoring.utils").apply_text_edits
  local code_gen_error = require("refactoring.utils").code_gen_error
  local is_unique = require("refactoring.utils").is_unique
  local indent = require("refactoring.utils").indent
  local get_declarations_by_scope = require("refactoring.utils").get_declarations_by_scope
  local scopes_for_range = require("refactoring.utils").scopes_for_range
  local get_declaration_scope = require("refactoring.utils").get_declaration_scope

  local code_generation = opts.config_opts.code_generation

  local extracted_range = opts.extracted_range
  local in_buf = opts.in_buf
  local lines = opts.lines
  local out_buf = opts.out_buf
  local fn_name = opts.fn_name

  local extracted_range_ts = { extracted_range:to_treesitter() }
  local nested_lang_tree, in_query = ts_parse(in_buf, extracted_range_ts)
  if not nested_lang_tree or not in_query then return end

  local out_nested_lang_tree, out_query = ts_parse(out_buf, extracted_range_ts)
  if not out_nested_lang_tree or not out_query then return end
  -- TODO: this doesn't work for `extract_func_to_file` (unless that, because
  -- of a coincidence, the information is available in that file). Instead,
  -- split `get_output_node` and `get_output/input_opts` to get it from
  -- `in_buf` (that will always have the information available instead)
  local output_node, output_opts = get_output_node(out_nested_lang_tree, out_query, out_buf, extracted_range)
  ---@type vim.Range
  local output_range
  if output_node then
    local output_start = pos.treesitter(in_buf, "start", output_node:start())
    local row, col = output_start:to_api()
    output_range = range.api(out_buf, row, col, row, col)
  elseif in_buf == out_buf then
    output_range = range(
      extracted_range.start.row,
      extracted_range.start.col,
      extracted_range.start.row,
      extracted_range.start.col,
      { buf = extracted_range.start.buf }
    )
  else
    output_range = range.api(out_buf, 0, 0, 0, 0)
  end

  local references = {} ---@type refactor.Reference[]
  local scopes = {} ---@type TSNode[]
  for _, tree in ipairs(nested_lang_tree:trees()) do
    for _, match, metadata in in_query:iter_matches(tree:root(), in_buf) do
      for capture_id, nodes in pairs(match) do
        local name = in_query.captures[capture_id]
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
  -- TODO: maybe check that all the treesitter captures are not empty(?

  local scopes_for_extracted_range = scopes_for_range(in_buf, scopes, extracted_range)

  local declarations = iter(references)
    :filter(
      ---@param r refactor.Reference
      function(r)
        return r.declaration
      end
    )
    :totable()

  local declarations_by_scope = get_declarations_by_scope(references, scopes, in_buf)

  ---@type refactor.Reference[]
  local typed_references = iter(references)
    :filter(
      ---@param r refactor.Reference
      function(r)
        return r.type ~= nil and r.type ~= vim.NIL
      end
    )
    :totable()
  table.sort(
    typed_references,
    ---@param a refactor.Reference
    ---@param b refactor.Reference
    function(a, b)
      -- TODO: don't I already have a function to sort nodes in utils?
      local a_range = range.treesitter(in_buf, a.identifier:range())
      local b_range = range.treesitter(in_buf, b.identifier:range())

      return a_range < b_range
    end
  )
  ---@type {[TSNode]: {scope: TSNode, types: {[string]: string|{identifier: string}}}}
  local types_by_scope_up_to_extracted_range_end = iter(typed_references)
    :filter(
      ---@param r refactor.Reference
      function(r)
        -- TODO: maybe extract this filter into some function, there are
        -- similar ones for all the `before_` variables
        local declaration_scope = get_declaration_scope(declarations_by_scope, scopes, r, in_buf)

        local is_in_scope = declaration_scope
            and iter(scopes_for_extracted_range):any(
              ---@param s TSNode
              function(s)
                return s:equal(declaration_scope)
              end
            )
          or false

        local node_range = range.treesitter(in_buf, r.identifier:range())
        return node_range.start <= extracted_range.end_ and node_range.end_ <= extracted_range.end_ and is_in_scope
      end
    )
    :fold(
      {},
      ---@param acc {[TSNode]: {scope: TSNode, types: {[string]: string|{identifier: string}}}}
      ---@param r refactor.Reference
      function(acc, r)
        if r.type == nil or r.type == vim.NIL then return acc end

        local scope = get_declaration_scope(declarations_by_scope, scopes, r, in_buf)
        if not scope then return acc end

        acc[scope] = acc[scope] or {}
        acc[scope].types = acc[scope].types or {}
        local identifier = ts.get_node_text(r.identifier, in_buf)
        acc[scope].types[identifier] = r.type
        acc[scope].scope = scope
        return acc
      end
    )

  ---@type {scope: TSNode, types: {[string]: string|{identifier: string}}}[]
  local types_with_scope_up_to_extracted_range_end = vim.tbl_values(types_by_scope_up_to_extracted_range_end)
  table.sort(types_with_scope_up_to_extracted_range_end, function(a, b)
    -- TODO: don't I already have a function to sort nodes in utils?
    local a_range = range.treesitter(in_buf, a.scope:range())
    local b_range = range.treesitter(in_buf, b.scope:range())

    return a_range < b_range
  end)
  ---@type {[string]: string|{identifier: string}}[]
  local scoped_types_up_to_extracted_range_end = iter(types_with_scope_up_to_extracted_range_end)
    :map(
      ---@param a {scope: TSNode, types: {[string]: string}}
      function(a)
        return a.types
      end
    )
    :totable()
  iter(scoped_types_up_to_extracted_range_end):rev():each(
    ---@param t {[string]: string|{identifier: string}}
    function(t)
      for identifier, identifier_type in pairs(t) do
        if type(identifier_type) == "table" then
          local types = iter(scoped_types_up_to_extracted_range_end):find(
            ---@param types {[string]: string}
            function(types)
              return types[identifier_type.identifier] ~= nil
            end
          )
          local type = types and types[identifier_type.identifier]
          -- TODO: check for recursive variable references or
          -- something like that?
          t[identifier] = type
        end
      end
    end
  )
  ---@cast scoped_types_up_to_extracted_range_end{[string]: string}[]

  ---@type refactor.Reference[]
  local references_inside_extracted_range = iter(references)
    :filter(
      ---@param r refactor.Reference
      function(r)
        local n = r.identifier
        local node_range = range.treesitter(in_buf, n:range())
        return extracted_range:has(node_range)
      end
    )
    :totable()

  local reference_to_variable =
    ---@param r refactor.Reference
    function(r)
      local identifier = ts.get_node_text(r.identifier, in_buf)

      ---@type {[string]: string}|nil
      local types = iter(scoped_types_up_to_extracted_range_end):find(
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

  ---@type refactor.Variable[]
  local variables_inside_extracted_range = iter(references_inside_extracted_range)
    :map(reference_to_variable)
    :filter(is_unique(
      ---@param v refactor.Variable
      function(v)
        return v.identifier
      end
    ))
    :totable()

  local reference_to_text =
    ---@param reference refactor.Reference
    function(reference)
      return ts.get_node_text(reference.identifier, in_buf)
    end
  ---@type string[]
  local write_identifiers_inside_extracted_range = iter(references_inside_extracted_range)
    :filter(
      ---@param r refactor.Reference
      function(r)
        return r.reference_type == "write"
      end
    )
    :map(reference_to_text)
    :filter(is_unique())
    :totable()

  ---@type string[]
  local declarations_inside_extracted_range = iter(declarations)
    :filter(
      ---@param r refactor.Reference
      function(r)
        local r_range = range.treesitter(in_buf, r.identifier:range())
        return extracted_range:has(r_range)
      end
    )
    :map(reference_to_text)
    :totable()

  ---@type string[]
  local declarations_before_output_range = iter(declarations)
    :filter(
      ---@param r refactor.Reference
      function(r)
        local declaration_scope = get_declaration_scope(declarations_by_scope, scopes, r, in_buf)

        local is_in_scope = declaration_scope
            and iter(scopes_for_extracted_range):any(
              ---@param s TSNode
              function(s)
                return s:equal(declaration_scope)
              end
            )
          or false

        local node_range = range.treesitter(in_buf, r.identifier:range())
        return node_range <= output_range and is_in_scope
      end
    )
    :map(reference_to_text)
    :totable()
  ---@type string[]
  local declarations_before_extracted_range = iter(declarations)
    :filter(
      ---@param r refactor.Reference
      function(r)
        local declaration_scope = get_declaration_scope(declarations_by_scope, scopes, r, in_buf)

        local is_in_scope = declaration_scope
            and iter(scopes_for_extracted_range):any(
              ---@param s TSNode
              function(s)
                return s:equal(declaration_scope)
              end
            )
          or false

        local node_range = range.treesitter(in_buf, r.identifier:range())
        return node_range <= extracted_range and is_in_scope
      end
    )
    :map(reference_to_text)
    :totable()

  ---@type refactor.Variable[]
  local args = iter(variables_inside_extracted_range)
    :filter(
      ---@param r refactor.Variable
      function(r)
        -- TODO: not only check if there are declarations inside the extracted
        -- range. Check if the first usage of the identifier is after the end
        -- of the first declaration inside the extracted range
        return not vim.list_contains(declarations_inside_extracted_range, r.identifier)
          and not vim.list_contains(declarations_before_output_range, r.identifier)
          and vim.list_contains(declarations_before_extracted_range, r.identifier)
      end
    )
    :totable()

  ---@type string[]
  local variables_after_extracted_range = iter(references)
    :filter(
      ---@param r refactor.Reference
      function(r)
        local declaration_scope = get_declaration_scope(declarations_by_scope, scopes, r, in_buf)
        local is_in_scope = declaration_scope
            and iter(scopes_for_extracted_range):any(
              ---@param s TSNode
              function(s)
                return s:equal(declaration_scope)
              end
            )
          or false

        local node_range = range.treesitter(in_buf, r.identifier:range())
        return node_range > extracted_range and is_in_scope
      end
    )
    :map(reference_to_variable)
    :filter(is_unique(
      ---@param v refactor.Variable
      function(v)
        return v.identifier
      end
    ))
    :totable()
  ---@type refactor.Variable[]
  local return_values = iter(variables_after_extracted_range)
    :filter(
      ---@param v refactor.Variable
      function(v)
        -- TODO: maybe limit to write_identifiers that are not declarations
        return vim.list_contains(write_identifiers_inside_extracted_range, v.identifier)
      end
    )
    :totable()

  local expandtab = vim.bo[out_buf].expandtab

  local body = table.concat(lines, "\n")
  local body_indent ---@type integer
  body, body_indent = indent(expandtab, 0, body)
  local lang = nested_lang_tree:lang()
  local get_return_statement = code_generation.return_statement[lang]
  if not get_return_statement then return code_gen_error("return_statement", lang) end
  local get_function_declaration = code_generation.function_declaration[lang]
  if not get_function_declaration then return code_gen_error("function_declaration", lang) end
  local get_function_call = code_generation.function_call[lang]
  if not get_function_call then return code_gen_error("function_call", lang) end
  if #return_values > 0 then
    local return_statement = get_return_statement {
      return_values = return_values,
    }
    body = body .. return_statement
  end
  local indent_width = vim.bo[in_buf].shiftwidth > 0 and vim.bo[in_buf].shiftwidth or vim.bo[in_buf].tabstop
  body = indent(expandtab, expandtab and 1 * indent_width or 1, body)
  local function_definition = get_function_declaration {
    args = args,
    body = body,
    name = fn_name,
    return_values = return_values,
    method = output_opts.method,
    singleton = output_opts.singleton,
    struct_name = output_opts.struct_name,
    struct_var_name = output_opts.struct_var_name,
  } .. "\n\n"
  function_definition = vim.text.indent((output_opts.method and 1 or 0) * indent_width, function_definition)
  if not expandtab then function_definition:gsub("^(%s+)", function(spaces)
    return ("\t"):rep(#spaces)
  end) end
  local function_call = get_function_call {
    args = args,
    name = fn_name,
    return_values = return_values,
    method = output_opts.method,
    struct_var_name = output_opts.struct_var_name,
  }
  function_call = indent(expandtab, body_indent, function_call)

  ---@type {[integer]: refactor.TextEdit[]}
  local text_edits_by_buf = {}
  text_edits_by_buf[in_buf] = {}
  table.insert(text_edits_by_buf[in_buf], { range = extracted_range, lines = vim.split(function_call, "\n") })

  local function_definition_lines = vim.split(function_definition, "\n")
  if output_opts.method then
    -- NOTE: treesitter nodes don't include whitespace. So, output region's
    -- first line it's (probably) already indented
    function_definition_lines[1] = indent(expandtab, 0, function_definition_lines[1])

    -- NOTE: `vim.text.indent` doesn't add indent for empty lines, but we are
    -- inserting text before already indented lines, so we'll remove their
    -- indentation if we don't do it manually
    local last_line_indent = expandtab and (" "):rep(indent_width) or "\t"
    local length = #function_definition_lines
    function_definition_lines[length] = function_definition_lines[length] .. last_line_indent
  end
  text_edits_by_buf[out_buf] = text_edits_by_buf[out_buf] or {}
  table.insert(text_edits_by_buf[out_buf], {
    range = output_range,
    lines = function_definition_lines,
  })
  apply_text_edits(text_edits_by_buf)

  -- TODO: maybe use snippets to expand the generated function and
  -- navigate through type placeholders?
end

---@param range_type 'v' | 'V' | ''
---@param config refactor.Config
M.extract_func = function(range_type, config)
  local get_extracted_range = require("refactoring.utils").get_extracted_range
  local get_extracted_lines = require("refactoring.utils").get_extracted_lines
  local input = require("refactoring.utils").input

  local opts = config.refactor.extract_func

  local buf = api.nvim_get_current_buf()
  local extracted_range = get_extracted_range(buf, range_type)
  local lines = get_extracted_lines(range_type)

  local task = async.run(function()
    local fn_name = opts.input and table.remove(opts.input, 1) or input { prompt = "Function name: " }
    if not fn_name then return end

    extract_func {
      in_buf = buf,
      out_buf = buf,
      extracted_range = extracted_range,
      lines = lines,
      fn_name = fn_name,
      config_opts = opts,
    }
  end)
  task:raise_on_error()
end

---@param range_type 'v' | 'V' | ''
---@param config refactor.Config
M.extract_func_to_file = function(range_type, config)
  local get_extracted_range = require("refactoring.utils").get_extracted_range
  local get_extracted_lines = require("refactoring.utils").get_extracted_lines
  local input = require("refactoring.utils").input

  local opts = config.refactor.extract_func

  local buf = api.nvim_get_current_buf()
  local extracted_range = get_extracted_range(buf, range_type)
  local lines = get_extracted_lines(range_type)

  local task = async.run(function()
    local file_name = opts.input and table.remove(opts.input)
      or input {
        prompt = "New file name: ",
        completion = "files",
        default = vim.fn.expand "%:.:h" .. "/",
      }
    if not file_name then return end
    local fn_name = opts.input and table.remove(opts.input) or input { prompt = "Function name: " }
    if not fn_name then return end

    local out_buf = vim.fn.bufadd(file_name)
    if not api.nvim_buf_is_loaded(out_buf) then vim.fn.bufload(out_buf) end

    extract_func {
      in_buf = buf,
      out_buf = out_buf,
      extracted_range = extracted_range,
      lines = lines,
      fn_name = fn_name,
      config_opts = opts,
    }
  end)
  task:raise_on_error()
end

return M
