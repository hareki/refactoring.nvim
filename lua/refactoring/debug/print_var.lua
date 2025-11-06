local api = vim.api
local ts = vim.treesitter
local iter = vim.iter
local async = require "async"
local range = require "refactoring.range"
local pos = require "refactoring.pos"

local M = {}

-- TODO: when rewriting `print_var` and `printf`, distinguish between
-- `print_expression` operator to print everything inside the selected region
-- and `print_var` operator to print ever variable inside the selected region
-- in the [some scope, I haven't think it through. Try to avoid loops and
-- things like that unless necessary. Maybe as close as possible to the last
-- declaration of the variables]
-- TODO: add some way to list/search/travel across all inserted statements
-- TODO: allow to filter function_calls (and maybe some arbitraty mechanism for
-- doing so)
-- TODO: allow specifying in reference captures which references do not need an
-- explicit declaration above (usually, object fields)

---@class refactor.print_var.code_generation.Opts
---@field identifier string

---@class refactor.print_var.CodeGeneration
---@field print_var {[string]: nil|fun(opts: refactor.print_var.code_generation.Opts): string}

---@class refactor.print_var.UserCodeGeneration
---@field print_var? {[string]: nil|fun(opts: refactor.print_var.code_generation.Opts): string}

-- TODO: support geting the location (e.g if#for#some_variable)
-- TODO: support for count of each occurrence (can I use treesitter with
-- a query of any node (1 or more times) between two comment nodes that match
-- the start and end pattern?). Or maybe don't support count at all and only
-- support it in `printf`?
---@param range_type 'v' | 'V' | ''
---@param config refactor.Config
function M.print_var(range_type, config)
  local get_extracted_range = require("refactoring.utils").get_extracted_range
  local is_unique = require("refactoring.utils").is_unique
  local code_gen_error = require("refactoring.utils").code_gen_error
  local apply_text_edits = require("refactoring.utils").apply_text_edits
  local get_declarations_by_scope = require("refactoring.utils").get_declarations_by_scope
  local scopes_for_range = require("refactoring.utils").scopes_for_range
  local get_declaration_scope = require("refactoring.utils").get_declaration_scope
  local indent = require("refactoring.utils").indent

  local opts = config.debug.print_var
  local code_generation = opts.code_generation

  local buf = api.nvim_get_current_buf()
  local extracted_range = get_extracted_range(buf, range_type)

  local task = async.run(function()
    local lang_tree, err1 = ts.get_parser(buf, nil, { error = false })
    if not lang_tree then
      ---@cast err1 -nil
      vim.notify(err1, vim.log.levels.ERROR)
      return
    end
    -- TODO: use async parsing
    -- TODO: check if using a range parses only when necessary (by peeking into
    -- the implementation, it does use `LanguageTree:valid`, but it always
    -- returns false when `range` is `true`)
    lang_tree:parse(true)
    local nested_lang_tree = lang_tree:language_for_range {
      extracted_range.start_row,
      extracted_range.start_col,
      extracted_range.end_row,
      extracted_range.end_col,
    }
    local lang = nested_lang_tree:lang()
    local query = ts.query.get(lang, "print_var")
    if not query then
      vim.notify(("There is no `print_var` query file for language %s"):format(lang), vim.log.levels.ERROR)
      return
    end

    local get_print_var = code_generation.print_var[lang]
    if not get_print_var then return code_gen_error("print_var", lang) end

    local references = {} ---@type refactor.ReferenceInfo[]
    local statements = {} ---@type TSNode[]
    local scopes = {} ---@type TSNode[]
    for _, tree in ipairs(nested_lang_tree:trees()) do
      for _, match, metadata in query:iter_matches(tree:root(), buf) do
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
          end

          if name == "statement" then table.insert(statements, nodes[1]) end
          if name == "scope" then
            for _, node in ipairs(nodes) do
              table.insert(scopes, node)
            end
          end
        end
      end
    end

    local extracted_range_api = { extracted_range:to_extmark() }
    -- NOTE: treesitter nodes usualy do not include leading whitespace
    local extracted_range_start_line =
      api.nvim_buf_get_lines(buf, extracted_range_api[1], extracted_range_api[1] + 1, true)[1]
    local _, extracted_range_start_line_first_non_white = extracted_range_start_line:find "^%s*"
    extracted_range_start_line_first_non_white = extracted_range_start_line_first_non_white or 0
    local extracted_reference_pos = opts.output_location == "below"
        and pos(extracted_range.end_row, extracted_range.end_col)
      or pos(extracted_range.start_row, extracted_range_start_line_first_non_white)
    ---@type TSNode|nil
    local statement_for_range = iter(statements)
      :filter(
        ---@param s TSNode
        function(s)
          local srow, scol, erow, ecol = s:range()
          local s_range = range(srow, scol, erow, ecol, { buf = buf })
          return s_range:has(extracted_reference_pos)
        end
      )
      :fold(
        nil,
        ---@param acc nil|TSNode
        ---@param s TSNode
        function(acc, s)
          if not acc then return s end
          if s:byte_length() < acc:byte_length() then return s end
          return acc
        end
      )
    if not statement_for_range then
      return vim.notify("Couldn't find statement for extracted range using Treesitter", vim.log.levels.ERROR)
    end

    local srow, scol, erow, ecol = statement_for_range:range()
    local statement_range = range(srow, scol, erow, ecol, { buf = buf })
    local statement_srow, statement_scol, statement_erow, statement_ecol = statement_range:to_extmark()
    local output_range = opts.output_location == "below"
        and range.extmark(statement_erow, statement_ecol, statement_erow, statement_ecol, { buf = buf })
      or range.extmark(statement_srow, statement_scol, statement_srow, statement_scol, { buf = buf })

    local output_start_pos = pos(output_range.start_row, output_range.start_col, { buf = output_range.buf })
    -- TODO: I also compute `declarations_before_output_range` in
    -- `extract_func`. Is there a cleaner wat to do all this in both places?
    local declarations_by_scope = get_declarations_by_scope(references, scopes, buf)
    local scopes_for_extracted_range = scopes_for_range(buf, scopes, extracted_range)
    local reference_to_text =
      ---@param reference refactor.ReferenceInfo
      function(reference)
        return ts.get_node_text(reference.identifier, buf)
      end
    local declarations_before_output_range = iter(references)
      :filter(
        ---@param r refactor.ReferenceInfo
        function(r)
          return r.declaration
        end
      )
      :filter(
        ---@param r refactor.ReferenceInfo
        function(r)
          local declaration_scope = get_declaration_scope(declarations_by_scope, scopes, r, buf)

          local is_in_scope = declaration_scope
              and iter(scopes_for_extracted_range):any(
                ---@param s TSNode
                function(s)
                  return s:equal(declaration_scope)
                end
              )
            or false

          local r_srow, r_scol, r_erow, r_ecol = r.identifier:range()
          local node_start = pos(r_srow, r_scol, { buf = buf })
          -- NOTE: I need to make end inclusive to be able to compare it with start
          if r_ecol == 0 then
            r_erow = r_erow - 1
            r_ecol = #api.nvim_buf_get_lines(buf, r_erow, r_erow + 1, true)[1]
          else
            r_ecol = r_ecol - 1
          end
          local node_end = pos(r_erow, r_ecol, { buf = buf })
          return node_start <= output_start_pos and node_end <= output_start_pos and is_in_scope
        end
      )
      :map(reference_to_text)
      :totable()

    ---@type {[string]: refactor.ReferenceInfo}
    local selected_references_by_start = iter(references)
      :filter(
        ---@param r refactor.ReferenceInfo
        function(r)
          local r_srow, r_scol, r_erow, r_ecol = r.identifier:range()
          local r_range = range(r_srow, r_scol, r_erow, r_ecol, { buf = buf })
          return extracted_range:has(r_range)
        end
      )
      :fold(
        {},
        ---@param acc {[string]: refactor.ReferenceInfo}
        ---@param r refactor.ReferenceInfo
        function(acc, r)
          local start_row, start_col = r.identifier:start()
          local key = ("%s%s"):format(start_row, start_col)
          local previous = acc[key]
          if not previous then acc[key] = r end
          if previous and r.identifier:byte_length() > previous.identifier:byte_length() then acc[key] = r end

          return acc
        end
      )
    ---@type refactor.ReferenceInfo[]
    local selected_references = iter(selected_references_by_start)
      :map(function(_, r)
        return r
      end)
      :totable()
    table.sort(selected_references, function(a, b)
      local a_srow, a_scol, a_erow, a_ecol = a.identifier:range()
      local a_range = range(a_srow, a_scol, a_erow, a_ecol, { buf = buf })
      local b_srow, b_scol, b_erow, b_ecol = b.identifier:range()
      local b_range = range(b_srow, b_scol, b_erow, b_ecol, { buf = buf })

      return a_range < b_range
    end)
    ---@type string[]
    local print_lines = iter(selected_references)
      :filter(
        ---@param r refactor.ReferenceInfo
        function(r)
          local r_srow, r_scol, r_erow, r_ecol = r.identifier:range()
          local r_range = range(r_srow, r_scol, r_erow, r_ecol, { buf = buf })
          return extracted_range:has(r_range)
        end
      )
      :map(
        ---@param r refactor.ReferenceInfo
        function(r)
          return ts.get_node_text(r.identifier, buf)
        end
      )
      :filter(is_unique())
      :filter(
        ---@param identifier string
        function(identifier)
          return vim.list_contains(declarations_before_output_range, identifier)
        end
      )
      :map(
        ---@param i string
        function(i)
          return get_print_var { identifier = i }
        end
      )
      :totable()
    if #print_lines == 0 then
      return vim.notify(
        "Couldn't found any reference inside of the extracted range with a declartion above output range using Treesitter",
        vim.log.levels.ERROR
      )
    end
    local start_marker = opts.markers.print_var.start
    local end_marker = opts.markers.print_var["end"]
    -- TODO: commenstring isn't the correct one for injected languages
    local commentstring = vim.bo[buf].commentstring
    table.insert(print_lines, 1, commentstring:format(start_marker))
    print_lines[#print_lines] = print_lines[#print_lines] .. commentstring:format(end_marker)

    local output_srow = output_range:to_extmark()
    local expandtab = vim.bo[buf].expandtab
    local _, indent_amount = indent(expandtab, 0, api.nvim_buf_get_lines(buf, output_srow, output_srow + 1, true)[1])
    local print_text = table.concat(print_lines, "\n")
    print_text = indent(expandtab, indent_amount, print_text)
    print_lines = vim.split(print_text, "\n")
    if opts.output_location == "below" then table.insert(print_lines, 1, "") end
    if opts.output_location == "above" then
      print_lines[1] = indent(expandtab, 0, print_lines[1])
      table.insert(print_lines, (expandtab and " " or "\t"):rep(indent_amount))
    end

    ---@type {[integer]: refactor.TextEdit[]}
    local text_edits_by_buf = {}
    text_edits_by_buf[buf] = {}
    table.insert(text_edits_by_buf[buf], { range = output_range, lines = print_lines })

    apply_text_edits(text_edits_by_buf)
  end)
  task:raise_on_error()
end

return M
