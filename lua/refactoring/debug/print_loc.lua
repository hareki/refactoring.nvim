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
  local get_ts_info = require("refactoring.utils").get_ts_info
  local get_statement_output_range = require("refactoring.debug.utils").get_statement_output_range

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
    local nested_lang_tree = lang_tree:language_for_range {
      extracted_range.start_row,
      extracted_range.start_col,
      extracted_range.end_row,
      extracted_range.end_col,
    }
    local lang = nested_lang_tree:lang()
    local query = ts.query.get(lang, "print_loc")
    if not query then
      return vim.notify(("There is no `print_loc` query file for language %s"):format(lang), vim.log.levels.ERROR)
    end

    local get_print_loc = code_generation.print_loc[lang]
    if not get_print_loc then return code_gen_error("print_loc", lang) end

    local ts_info = get_ts_info(buf, nested_lang_tree, query)
    local debug_paths = ts_info.debug_paths
    local output_statements = ts_info.output_statements

    -- NOTE: treesitter nodes usualy do not include leading whitespace
    local srow = extracted_range:to_extmark()
    local extracted_range_start_line = api.nvim_buf_get_lines(buf, srow, srow + 1, true)[1]
    local _, extracted_start_line_first_non_white = extracted_range_start_line:find "^%s*"
    extracted_start_line_first_non_white = extracted_start_line_first_non_white or 0
    local extracted_reference_pos = opts.output_location == "below"
        and pos(extracted_range.end_row, math.max(extracted_start_line_first_non_white, extracted_range.end_col))
      or pos(extracted_range.start_row, extracted_start_line_first_non_white)
    local output_range, inserted_at =
      get_statement_output_range(buf, output_statements, opts.output_location, extracted_range, extracted_reference_pos)
    if not output_range or not inserted_at then return end

    ---@type refactor.DebugPath[]
    local debug_paths_for_range = iter(debug_paths)
      :filter(
        ---@param dp refactor.DebugPath
        function(dp)
          local dp_srow, dp_scol, dp_erow, dp_ecol = dp.debug_path:range()
          local dp_range = range(dp_srow, dp_scol, dp_erow, dp_ecol, { buf = buf })

          return dp_range:has(output_range)
        end
      )
      :totable()

    table.sort(debug_paths_for_range, function(a, b)
      local a_srow, a_scol = a.debug_path:range()
      local a_start_pos = pos(a_srow, a_scol, { buf = buf })
      local b_srow, b_scol = b.debug_path:range()
      local b_start_pos = pos(b_srow, b_scol, { buf = buf })
      return a_start_pos < b_start_pos
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

    local srow = output_range:to_extmark()
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
