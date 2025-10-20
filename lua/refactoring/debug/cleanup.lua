local api = vim.api
local iter = vim.iter
local async = require "async"
local ts = vim.treesitter

-- TODO: Search inside strings (using treesitter) on `printf` (and
-- maybe also `print_var`) when updating the count. That would mean
-- decoupling the `code_generation` for the content of the string and
-- the whole print statement

local M = {}

---@param a TSNode
---@param b TSNode
---@return boolean
local function node_comp_asc(a, b)
  local a_row, a_col, a_bytes = a:start()
  local b_row, b_col, b_bytes = b:start()
  if a_row ~= b_row then return a_row < b_row end

  return (a_col < b_col or a_col + a_bytes < b_col + b_bytes)
end

-- TODO: add some kind of success message of how many statements where cleared
-- like in inline_var/extract_var
---@param range_type 'v' | 'V' | ''
---@param opts refactor.debug.cleanup.Opts
function M.cleanup(range_type, opts)
  local get_extracted_range = require("refactoring.range").get_extracted_range
  local apply_text_edits = require("refactoring.utils").apply_text_edits
  local contains_range = require("refactoring.range").contains_range

  -- TODO: generalize setting default opts and use `vim.tbl_deep_extend` to
  -- extend the default options with the provided ones (everywhere)
  opts = opts or {}
  opts.types = opts.types or { "print_var", "print_loc", "print_exp" }
  opts.markers = opts.markers
    or {
      print_var = { start = "__PRINT_VAR_START", ["end"] = "__PRINT_VAR_END" },
      print_exp = { start = "__PRINT_EXP_START", ["end"] = "__PRINT_EXP_END" },
      print_loc = { start = "__PRINT_LOC_START", ["end"] = "__PRINT_LOC_END" },
    }

  local buf = api.nvim_get_current_buf()
  local last_line = vim.fn.line "$"
  local extracted_range = get_extracted_range(range_type)

  local task = async.run(function()
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

    local comments = {} ---@type TSNode[]
    for _, tree in ipairs(nested_lang_tree:trees()) do
      for _, match, _ in query:iter_matches(tree:root(), buf) do
        for capture_id, nodes in pairs(match) do
          local name = query.captures[capture_id]

          if name == "comment" then table.insert(comments, nodes[1]) end
        end
      end
    end

    table.sort(comments, node_comp_asc)
    ---@type Range4[]
    local ranges_to_cleanup = iter(comments)
      :filter(
        ---@param comment TSNode
        function(comment)
          local comment_range = { comment:range() }
          return contains_range(extracted_range, comment_range)
        end
      )
      :map(
        ---@param comment TSNode
        function(comment)
          local text = ts.get_node_text(comment, buf)

          local is_start = iter(opts.types):any(
            ---@param name 'print_var'|'print_loc'|'print_exp'
            function(name)
              return text:find(opts.markers[name].start) ~= nil
            end
          )
          if is_start then return "start", { comment:start() } end
          local comment_end = { comment:end_() }
          if comment_end[1] ~= last_line - 1 then
            comment_end[1], comment_end[2] = comment_end[1] + 1, 0
          end
          local is_end = iter(opts.types):any(
            ---@param name 'print_var'|'print_loc'|'print_exp'
            function(name)
              return text:find(opts.markers[name]["end"]) ~= nil
            end
          )
          if is_end then return "end", comment_end end
          -- TODO: I'll need to generalize the handling of 0-based/1-based
          -- end-exclusive/end-inclusive/end_row-inclusive_col-exclusive/end_row_exclusive-_col-0
          -- ranges everywhere x2
        end
      )
      :filter(
        ---@param kind 'start'|'end'|nil
        function(kind)
          return kind ~= nil
        end
      )
      :fold(
        {},
        ---@param acc Range4[]|{current_start: Range2}
        ---@param kind 'start'|'end'
        ---@param range Range2
        function(acc, kind, range)
          if kind == "start" then acc.current_start = range end
          if kind == "end" and acc.current_start ~= nil then
            table.insert(acc, { acc.current_start[1], acc.current_start[2], range[1], range[2] })
            acc.current_start = nil
          end

          return acc
        end
      )

    ---@type {[integer]: refactor.TextEdit[]}
    local text_edits_by_buf = {}
    text_edits_by_buf[buf] = {}
    iter(ipairs(ranges_to_cleanup)):each(
      ---@param range Range4
      function(_, range)
        table.insert(text_edits_by_buf[buf], { range = range, lines = {} })
      end
    )

    apply_text_edits(text_edits_by_buf)
  end)
  task:raise_on_error()
end

return M
