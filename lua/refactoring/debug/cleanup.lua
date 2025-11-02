local api = vim.api
local iter = vim.iter
local async = require "async"
local range = require "refactoring.range"
local pos = require "refactoring.pos"
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
---@param config refactor.Config
function M.cleanup(range_type, config)
  local get_extracted_range = require("refactoring.utils").get_extracted_range
  local apply_text_edits = require("refactoring.utils").apply_text_edits

  local opts = config.debug.cleanup

  local buf = api.nvim_get_current_buf()
  local last_line = vim.fn.line "$"
  local extracted_range = get_extracted_range(buf, range_type)

  local task = async.run(function()
    local lang_tree, err1 = ts.get_parser(buf, nil, { error = false })
    if not lang_tree then
      vim.notify(err1, vim.log.levels.ERROR)
      return
    end
    -- TODO: use async parsing
    lang_tree:parse(true)
    local nested_lang_tree = lang_tree:language_for_range { extracted_range:to_treesitter() }
    local lang = nested_lang_tree:lang()
    local query = ts.query.get(lang, "cleanup")
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
    ---@type vim.Range[]
    local ranges_to_cleanup = iter(comments)
      :filter(
        ---@param comment TSNode
        function(comment)
          local comment_range = range.treesitter(buf, comment:range())
          return extracted_range:has(comment_range)
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
          if is_start then return "start", pos.treesitter(buf, "start", comment:start()) end
          local is_end = iter(opts.types):any(
            ---@param name 'print_var'|'print_loc'|'print_exp'
            function(name)
              return text:find(opts.markers[name]["end"]) ~= nil
            end
          )
          if is_end then return "end", pos.treesitter(buf, "end", comment:end_()) end
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
        ---@param acc vim.Range|{current_start: vim.Pos}
        ---@param kind 'start'|'end'
        ---@param position vim.Pos
        function(acc, kind, position)
          if kind == "start" then acc.current_start = position end
          if kind == "end" and acc.current_start ~= nil then
            table.insert(acc, range(acc.current_start, position))
            acc.current_start = nil
          end

          return acc
        end
      )

    ---@type {[integer]: refactor.TextEdit[]}
    local text_edits_by_buf = {}
    text_edits_by_buf[buf] = {}
    iter(ipairs(ranges_to_cleanup)):each(
      ---@param r vim.Range
      function(_, r)
        table.insert(text_edits_by_buf[buf], { range = r, lines = {} })
      end
    )

    apply_text_edits(text_edits_by_buf)
  end)
  task:raise_on_error()
end

return M
