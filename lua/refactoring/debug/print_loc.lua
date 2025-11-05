local api = vim.api
local ts = vim.treesitter
local iter = vim.iter
local async = require "async"
local range = require "refactoring.range"
local pos = require "refactoring.pos"

local M = {}

---@class refactor.print_loc.code_generation.Opts
---@field debug_path string

---@class refactor.print_loc.CodeGeneration
---@field print_loc {[string]: nil|fun(opts: refactor.print_loc.code_generation.Opts): string}

---@class refactor.print_loc.UserCodeGeneration
---@field print_loc? {[string]: nil|fun(opts: refactor.print_loc.code_generation.Opts): string}

---@class refactor.DebugPath
---@field debug_path TSNode
---@field text string

---@class refactor.OutputStatement
---@field output_statement TSNode
---@field inside TSNode|nil

-- TODO: support count
---@param range_type 'v' | 'V' | ''
---@param config refactor.Config
function M.print_loc(range_type, config)
  local get_extracted_range = require("refactoring.utils").get_extracted_range
  local code_gen_error = require("refactoring.utils").code_gen_error
  local indent = require("refactoring.utils").indent
  local apply_text_edits = require("refactoring.utils").apply_text_edits

  local opts = config.debug.print_loc
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
    lang_tree:parse(true)
    local nested_lang_tree = lang_tree:language_for_range { extracted_range:to_treesitter() }
    local lang = nested_lang_tree:lang()
    local query = ts.query.get(lang, "print_loc")
    if not query then
      return vim.notify(("There is no `print_loc` query file for language %s"):format(lang), vim.log.levels.ERROR)
    end

    local get_print_loc = code_generation.print_loc[lang]
    if not get_print_loc then return code_gen_error("print_loc", lang) end

    -- TODO: change to a better name everywhere (debug_path_element?)
    local debug_paths = {} ---@type refactor.DebugPath[]
    local output_statements = {} ---@type refactor.OutputStatement[]
    for _, tree in ipairs(nested_lang_tree:trees()) do
      for _, match, metadata in query:iter_matches(tree:root(), buf) do
        local output_statement ---@type nil|refactor.OutputStatement
        for capture_id, nodes in pairs(match) do
          local name = query.captures[capture_id]
          if name == "debug_path" then
            for i, node in ipairs(nodes) do
              local text = type(metadata.text) == "string" and metadata.text
                or ts.get_node_text(match[metadata.text][i], buf)
              table.insert(debug_paths, { debug_path = node, text = text })
            end
          end

          if name == "output_statement" then
            output_statement = output_statement or {}
            output_statement.output_statement = nodes[1]
          elseif name == "output_statement.inside" then
            output_statement = output_statement or {}
            output_statement.inside = nodes[1]
          end
        end
        if output_statement then table.insert(output_statements, output_statement) end
      end
    end

    local extracted_range_api = { extracted_range:to_api() }
    -- NOTE: treesitter nodes usualy do not include leading whitespace
    local extracted_range_start_line =
      api.nvim_buf_get_lines(buf, extracted_range_api[1], extracted_range_api[1] + 1, true)[1]
    local _, extracted_range_start_line_first_non_white = extracted_range_start_line:find "^%s*"
    extracted_range_start_line_first_non_white = extracted_range_start_line_first_non_white or 0
    local extracted_reference_pos = pos(
      opts.output_location == "below" and extracted_range.end_.row or extracted_range.start.row,
      extracted_range_start_line_first_non_white
    )
    ---@type refactor.OutputStatement|nil
    local statement_for_range = iter(output_statements)
      :filter(
        ---@param os refactor.OutputStatement
        function(os)
          local os_range = range.treesitter(buf, os.output_statement:range())
          return os_range:has_pos(extracted_reference_pos)
        end
      )
      :fold(
        nil,
        ---@param acc nil|refactor.OutputStatement
        ---@param s refactor.OutputStatement
        function(acc, s)
          if not acc then return s end
          if s.output_statement:byte_length() < acc.output_statement:byte_length() then return s end
          return acc
        end
      )
    if not statement_for_range then
      return vim.notify("Couldn't find statement for extracted range using Treesitter", vim.log.levels.ERROR)
    end

    local statement_range = range.treesitter(buf, statement_for_range.output_statement:range())
    local statement_srow, statement_scol, statement_erow, statement_ecol = statement_range:to_api()
    local before_range = range.api(buf, statement_srow, statement_scol, statement_srow, statement_scol)
    local after_range = range.api(buf, statement_erow, statement_ecol, statement_erow, statement_ecol)
    local output_range ---@type vim.Range
    local inserted_at ---@type 'start'|'end'
    if statement_for_range.inside and opts.output_location == "above" then
      local inside_range = range.treesitter(buf, statement_for_range.inside:range())

      if extracted_range > inside_range then
        local _, _, inside_erow, inside_ecol = inside_range:to_api()
        output_range = range.api(buf, inside_erow, inside_ecol, inside_erow, inside_ecol)
        inserted_at = "end"
      else
        output_range = before_range
        inserted_at = "start"
      end
    elseif statement_for_range.inside and opts.output_location == "below" then
      local inside_range = range.treesitter(buf, statement_for_range.inside:range())

      if extracted_range < inside_range then
        local inside_srow, inside_scol = inside_range:to_api()
        output_range = range.api(buf, inside_srow, inside_scol, inside_srow, inside_scol)
        inserted_at = "start"
      else
        output_range = after_range
        inserted_at = "end"
      end
    else
      if opts.output_location == "above" then
        output_range = before_range
        inserted_at = "start"
      elseif opts.output_location == "below" then
        output_range = after_range
        inserted_at = "end"
      end
    end

    -- TODO: range {10, 6, 10, 6} shouldn't be considered to be inside of range
    -- {10, 6, 12, 9}. But, since {10, 6} is >= {10, 6} and {10, 6} is <= {12, 9},
    -- it's considered to be. Maybe upstream some check for this into `vim.Range`.
    -- The same thing shouldn' happen for {12, 9, 12, 9} and {10, 6, 12, 9}
    -- TODO: this breaks when cursor is at last col on the inside of a `@output_statment`
    local output_reference_pos = pos(
      output_range.start.row,
      inserted_at == "start" and output_range.start.col - 1 or output_range.start.col + 1,
      { buf = output_range.start.buf }
    )
    ---@type refactor.DebugPath[]
    local debug_paths_for_range = iter(debug_paths)
      :filter(
        ---@param dp refactor.DebugPath
        function(dp)
          local dp_range = range.treesitter(buf, dp.debug_path:range())

          return dp_range:has_pos(output_reference_pos)
        end
      )
      :totable()

    table.sort(debug_paths_for_range, function(a, b)
      local a_range = range.treesitter(buf, a.debug_path:range())
      local b_range = range.treesitter(buf, b.debug_path:range())
      return a_range.start < b_range.start
    end)

    local debug_path_for_range = iter(debug_paths_for_range)
      :map(
        ---@param dp refactor.DebugPath
        function(dp)
          return dp.text
        end
      )
      :join "#"

    local start_marker = opts.markers.print_loc.start
    local end_marker = opts.markers.print_loc["end"]
    -- TODO: commenstring isn't the correct one for injected languages
    local commentstring = vim.bo[buf].commentstring
    local print_loc_lines = {
      commentstring:format(start_marker),
      get_print_loc { debug_path = debug_path_for_range } .. commentstring:format(end_marker),
    }

    local srow = output_range:to_api()
    local expandtab = vim.bo[buf].expandtab
    local _, indent_amount = indent(expandtab, 0, api.nvim_buf_get_lines(buf, srow, srow + 1, true)[1])
    local print_text = table.concat(print_loc_lines, "\n")
    print_text = indent(expandtab, indent_amount, print_text)
    print_loc_lines = vim.split(print_text, "\n")
    if inserted_at == "end" then table.insert(print_loc_lines, 1, "") end
    if inserted_at == "start" then
      print_loc_lines[1] = indent(expandtab, 0, print_loc_lines[1])
      table.insert(print_loc_lines, (expandtab and " " or "\t"):rep(indent_amount))
    end

    ---@type {[integer]: refactor.TextEdit[]}
    local text_edits_by_buf = {}
    text_edits_by_buf[buf] = {}
    table.insert(text_edits_by_buf[buf], { range = output_range, lines = print_loc_lines })

    apply_text_edits(text_edits_by_buf)
  end)
  task:raise_on_error()
end

return M
