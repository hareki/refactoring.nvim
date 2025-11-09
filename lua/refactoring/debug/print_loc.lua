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

    local extracted_range_api = { extracted_range:to_extmark() }
    -- NOTE: treesitter nodes usualy do not include leading whitespace
    local extracted_range_start_line =
      api.nvim_buf_get_lines(buf, extracted_range_api[1], extracted_range_api[1] + 1, true)[1]
    local _, extracted_range_start_line_first_non_white = extracted_range_start_line:find "^%s*"
    extracted_range_start_line_first_non_white = extracted_range_start_line_first_non_white or 0
    local extracted_reference_pos = opts.output_location == "below"
        and pos(extracted_range.end_row, math.max(extracted_range_start_line_first_non_white, extracted_range.end_col))
      or pos(extracted_range.start_row, extracted_range_start_line_first_non_white)
    ---@type refactor.OutputStatement|nil
    local statement_for_range = iter(output_statements)
      :filter(
        ---@param os refactor.OutputStatement
        function(os)
          local os_srow, os_scol, os_erow, os_ecol = os.output_statement:range()
          local os_range = range(os_srow, os_scol, os_erow, os_ecol, { buf = buf })
          return os_range:has(extracted_reference_pos)
        end
      )
      :fold(
        nil,
        ---@param acc nil|refactor.OutputStatement
        ---@param os refactor.OutputStatement
        function(acc, os)
          if not acc then return os end
          if os.output_statement:byte_length() < acc.output_statement:byte_length() then return os end
          return acc
        end
      )
    if not statement_for_range then
      return vim.notify("Couldn't find statement for extracted range using Treesitter", vim.log.levels.ERROR)
    end

    local o_srow, o_scol, o_erow, o_ecol = statement_for_range.output_statement:range()
    local before_range = range(o_srow, o_scol, o_srow, o_scol, { buf = buf })
    local after_range = range(o_erow, o_ecol, o_erow, o_ecol, { buf = buf })
    local output_range ---@type vim.Range
    local inserted_at ---@type 'start'|'end'
    if statement_for_range.inside and opts.output_location == "above" then
      local i_srow, i_scol, i_erow, i_ecol = statement_for_range.inside:range()
      local inside_range = range(i_srow, i_scol, i_erow, i_ecol, { buf = buf })

      if extracted_range > inside_range then
        local _, _, inside_erow, inside_ecol = inside_range:to_extmark()
        output_range = range.extmark(inside_erow, inside_ecol, inside_erow, inside_ecol, { buf = buf })
        inserted_at = "end"
      else
        output_range = before_range
        inserted_at = "start"
      end
    elseif statement_for_range.inside and opts.output_location == "below" then
      local i_srow, i_scol, i_erow, i_ecol = statement_for_range.inside:range()
      local inside_range = range(i_srow, i_scol, i_erow, i_ecol, { buf = buf })

      if extracted_range < inside_range then
        local inside_srow, inside_scol = inside_range:to_extmark()
        output_range = range.extmark(inside_srow, inside_scol, inside_srow, inside_scol, { buf = buf })
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
