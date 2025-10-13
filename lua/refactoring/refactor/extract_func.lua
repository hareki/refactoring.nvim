local async = require "async"
local iter = vim.iter
local ts = vim.treesitter
local api = vim.api

local M = {}

---@type fun(opts: table): string
local input = async.wrap(2, function(opts, cb)
  vim.ui.input(opts, cb)
end)

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

---@class refactor.extract_func.code_generation
---@field function_declaration {[string]: nil|fun(opts: refactor.extract_func.code_generation.function_declaration.Opts): string}
---@field function_call {[string]: nil|fun(opts: refactor.extract_func.code_generation.function_call.Opts): string}
---@field return_statement {[string]: nil|fun(opts: refactor.extract_func.code_generation.return_statement.Opts): string}

-- TODO: move these common functions
---@param missing_code_gen string
---@param lang string
local function code_gen_error(missing_code_gen, lang)
  vim.notify(
    ("There's no `%s` code generation defined for language %s"):format(missing_code_gen, lang),
    vim.log.levels.ERROR
  )
end

---@type refactor.extract_func.code_generation
local code_generation = {
  function_declaration = {
    lua = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      local has_arg_types = iter(opts.args):any(
        ---@param v refactor.Variable
        function(v)
          return v.type ~= nil
        end
      )
      local annotations = not has_arg_types and ""
        or iter(opts.args)
            :filter(
              ---@param v refactor.Variable
              function(v)
                return v.type ~= nil
              end
            )
            :map(
              ---@param v refactor.Variable
              function(v)
                return ("---@param %s %s"):format(v.identifier, v.type)
              end
            )
            :join "\n"
          .. "\n"

      return ([[
%slocal function %s(%s)
%s
end]]):format(annotations, opts.name, args, opts.body)
    end,
    c = function(opts)
      local return_type = #opts.return_values == 1 and (opts.return_values[1].type or "P") or "void"
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return ("%s %s"):format(v.type or "P", v.identifier)
          end
        )
        :join ", "
      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.type and ("%s *%s"):format(v.type, v.identifier) or ("P *%s"):format(v.identifier)
          end
        )
        :join ", "
      local in_n_out = args ~= "" and table.concat({ args, return_values }, ", ") or return_values

      return ([[
%s %s(%s) {
%s
}]]):format(return_type, opts.name, #opts.return_values < 2 and args or in_n_out, opts.body)
    end,
    c_sharp = function(opts)
      local return_type = #opts.return_values == 1 and (opts.return_values[1].type or "P")
        or #opts.return_values == 0 and "void"
        or ("(%s)"):format(iter(opts.return_values)
          :map(
            ---@param v refactor.Variable
            function(v)
              return v.type or "P"
            end
          )
          :join ", ")

      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return ("%s %s"):format(v.type or "P", v.identifier)
          end
        )
        :join ", "

      return ([[
public %s %s(%s) {
%s
}]]):format(return_type, opts.name, args, opts.body)
    end,
    javascript = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      local has_arg_types = iter(opts.args):any(
        ---@param v refactor.Variable
        function(v)
          return v.type ~= nil
        end
      )
      local annotations = ""

      if has_arg_types then
        annotations = iter(opts.args)
          :filter(
            ---@param v refactor.Variable
            function(v)
              return v.type ~= nil
            end
          )
          :map(
            ---@param v refactor.Variable
            function(v)
              return ("* @param {%s} %s"):format(v.type, v.identifier)
            end
          )
          :join "\n"
        annotations = ([[
/**
%s
*/
]]):format(annotations)
      end
      return ([[
%s%s%s(%s){
%s
}]]):format(annotations, opts.method and "" or "function ", opts.name, args, opts.body)
    end,
    typescript = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.type and ("%s: %s"):format(v.identifier, v.type) or v.identifier
          end
        )
        :join ", "
      return ([[
%s%s(%s){
%s
}]]):format(opts.method and "" or "function ", opts.name, args, opts.body)
    end,
    go = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return ("%s %s"):format(v.identifier, v.type or "P")
          end
        )
        :join ", "
      local struct = (opts.struct_name and opts.struct_var_name)
          and (" (%s *%s)"):format(opts.struct_var_name, opts.struct_name)
        or ""
      local return_type = opts.return_values == 0 and ""
        or opts.return_values == 1 and (" %s"):format(opts.return_values[1].type or "P")
        or (" (%s)"):format(iter(opts.return_values)
          :map(
            ---@param v refactor.Variable
            function(v)
              return v.type or "P"
            end
          )
          :join ", ")
      return ([[
func%s %s(%s)%s {
%s
}]]):format(struct, opts.name, args, return_type, opts.body)
    end,
    java = function(opts)
      local return_type = #opts.return_values == 0 and "void" or (opts.return_values[1].type or "P")
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return ("%s %s"):format(v.type or "P", v.identifier)
          end
        )
        :join ", "
      return ([[
private %s %s(%s) {
%s
}]]):format(return_type, opts.name, args, opts.body)
    end,
    php = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.type and ("%s %s"):format(v.type, v.identifier) or v.identifier
          end
        )
        :join ", "
      return ([[
%sfunction %s(%s)
{
%s
}]]):format(opts.method and "private " or "", opts.name, args, opts.body)
    end,
    powershell = function(opts)
      if opts.method then
        local args = iter(opts.args)
          :map(
            ---@param v refactor.Variable
            function(v)
              return v.identifier
            end
          )
          :join ", "
        return ([[
[%s] %s(%s)
{
%s
}]]):format(
          opts.return_values == 0 and "Void" or (opts.return_values[1].type or "P"),
          opts.name,
          args,
          opts.body
        )
      end
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ",\n"
      return ([[
function %s
{
param (%s)
%s
}]]):format(opts.name, args, opts.body)
    end,
    python = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      if opts.method then args = "self, " .. args end
      return ([[
def %s(%s):
%s]]):format(opts.name, args, opts.body)
    end,
    ruby = function(opts)
      local name = opts.singleton and "self." .. opts.name or opts.name
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ([[
def %s(%s):
%s
end]]):format(name, args, opts.body)
    end,
    vim = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param a refactor.Variable
          function(a)
            return a.identifier
          end
        )
        :join ", "
      return ([[
function! s:%s(%s) abort
%s
endfunction]]):format(opts.name, args, opts.body)
    end,
  },
  function_call = {
    lua = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "

      if #opts.return_values == 0 then return ("%s(%s)"):format(opts.name, args) end

      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("local %s = %s(%s)"):format(return_values, opts.name, args)
    end,
    c = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      if #opts.return_values == 0 then return ("%s(%s);"):format(opts.name, args) end
      if #opts.return_values == 1 then
        return ("%s %s = %s(%s);"):format(
          opts.return_values[1].type or "P",
          opts.return_values[1].identifier,
          opts.name,
          args
        )
      end
      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return "&" .. v.identifier
          end
        )
        :join ", "
      local in_n_out = args ~= "" and table.concat({ args, return_values }, ", ") or return_values
      return ("%s(%s);"):format(opts.name, in_n_out)
    end,
    c_sharp = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      if #opts.return_values == 0 then return ("%s(%s);"):format(opts.name, args) end
      if #opts.return_values == 1 then
        return ("%s %s = %s(%s);"):format(
          opts.return_values[1].type or "var",
          opts.return_values[1].identifier,
          opts.name,
          args
        )
      end
      return ("var out = %s(%s);"):format(opts.name, args)
    end,
    javascript = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      local name = opts.method and ("this.%s"):format(opts.name) or opts.name

      if #opts.return_values == 0 then return ("%s(%s);"):format(name, args) end
      if #opts.return_values == 1 then
        return ("let %s = %s(%s);"):format(opts.return_values[1].identifier, name, args)
      end
      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("let [%s] = %s(%s);"):format(return_values, name, args)
    end,
    go = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      local name = opts.struct_var_name and ("%s.%s"):format(opts.struct_var_name, opts.name) or opts.name
      if #opts.return_values == 0 then return ("%s(%s)"):format(name, args) end

      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("%s := %s(%s)"):format(return_values, name, args)
    end,
    java = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      if #opts.return_values == 0 then return ("%s(%s);"):format(opts.name, args) end

      if #opts.return_values > 1 then
        vim.notify(
          "The extracted function requires multiple return values, but Java lacks support doing it",
          vim.log.levels.WARN
        )
      end

      return ("var %s = %s(%s);"):format(opts.return_values[1].identifier, opts.name, args)
    end,
    php = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      local name = opts.method and "self->" .. opts.name or opts.name
      if #opts.return_values == 0 then return ("%s(%s);"):format(name, args) end
      if #opts.return_values == 1 then return ("%s = %s(%s);"):format(opts.return_values[1].identifier, name, args) end

      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("[%s] = %s(%s);"):format(return_values, name, args)
    end,
    powershell = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join " "
      if #opts.return_values == 0 then return ("%s %s"):format(opts.name, args) end
      if #opts.return_values == 1 then
        return ("%s = %s %s"):format(opts.return_values[1].identifier, opts.name, args)
      end

      return ("$out = %s %s"):format(opts.name, args)
    end,
    python = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      local name = opts.method and "self." .. opts.name or opts.name
      if #opts.return_values == 0 then return ("%s(%s)"):format(name, args) end
      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("%s = %s(%s)"):format(return_values, name, args)
    end,
    ruby = function(opts)
      local args = iter(opts.args)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      if #opts.return_values == 0 then return ("%s(%s)"):format(opts.name, args) end
      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("%s = %s(%s)"):format(return_values, opts.name, args)
    end,
    vim = function(opts)
      local return_values = #opts.return_values == 0 and "call"
        or #opts.return_values == 1 and ("let %s ="):format(opts.return_values[1].identifier)
        or ("let [%s] ="):format(iter(opts.return_values)
          :map(
            ---@param r refactor.Variable
            function(r)
              return r.identifier
            end
          )
          :join ", ")
      local args = iter(opts.args)
        :map(
          ---@param a refactor.Variable
          function(a)
            return a.identifier
          end
        )
        :join ", "
      return ([[%s %s(%s)]]):format(return_values, opts.name, args)
    end,
  },
  return_statement = {
    lua = function(opts)
      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("\n\nreturn %s"):format(return_values)
    end,
    c = function(opts)
      if #opts.return_values > 1 then return "" end

      return ("\n\nreturn %s;"):format(opts.return_values[1].identifier)
    end,
    c_sharp = function(opts)
      if #opts.return_values == 1 then return ("\n\nreturn %s;"):format(opts.return_values[1].identifier) end
      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("\n\nreturn (%s);"):format(return_values)
    end,
    javascript = function(opts)
      if #opts.return_values == 1 then return ("\n\nreturn %s;"):format(opts.return_values[1]) end
      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("\n\nreturn [%s];"):format(return_values)
    end,
    go = function(opts)
      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("\n\nreturn %s"):format(return_values)
    end,
    java = function(opts)
      return ("\n\nreturn %s;"):format(opts.return_values[1].identifier)
    end,
    php = function(opts)
      if #opts.return_values == 1 then return ("\n\nreturn %s;"):format(opts.return_values[1].identifier) end

      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("\n\nreturn [%s];"):format(return_values)
    end,
    powershell = function(opts)
      if #opts.return_values == 1 then return ("\n\nreturn %s"):format(opts.return_values[1]) end

      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("\n\nreturn @(%s)"):format(return_values)
    end,
    python = function(opts)
      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("\n\nreturn %s"):format(return_values)
    end,
    ruby = function(opts)
      local return_values = iter(opts.return_values)
        :map(
          ---@param v refactor.Variable
          function(v)
            return v.identifier
          end
        )
        :join ", "
      return ("\n\nreturn %s"):format(return_values)
    end,
    vim = function(opts)
      local return_values = #opts.return_values == 1 and opts.return_values[1].identifier
        or ("[%s]"):format(iter(opts.return_values)
          :map(
            ---@param r refactor.Variable
            function(r)
              return r.identifier
            end
          )
          :join ", ")
      return ([[return %s]]):format(return_values)
    end,
  },
}
code_generation.function_declaration.cpp = code_generation.function_declaration.c
code_generation.function_call.cpp = code_generation.function_call.c
code_generation.return_statement.cpp = code_generation.return_statement.c
code_generation.function_call.typescript = code_generation.function_call.javascript
code_generation.return_statement.typescript = code_generation.return_statement.javascript

-- TODO: check if I can replace this with the has-parent treesitter predicate
---@type {[string]: {fn: integer, method?: integer}}
local parents_till_nil = {
  lua = {
    fn = 2,
  },
  c = {
    fn = 2,
  },
  c_sharp = {
    fn = 2,
    method = 4,
  },
  javascript = {
    fn = 2,
    method = 4,
  },
  go = {
    fn = 2,
  },
  java = {
    method = 4,
  },
  php = {
    fn = 2,
    method = 4,
  },
  powershell = {
    fn = 3,
    method = 4,
  },
  python = {
    fn = 2,
    method = 4,
  },
  ruby = {
    fn = 2,
    method = 4,
  },
  vim = {
    fn = 2,
  },
}
parents_till_nil.cpp = parents_till_nil.c
parents_till_nil.typescript = parents_till_nil.javascript

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

---@param first Range2
---@param second Range2
---@param range Range2
---@return boolean
local function is_first_closer(first, second, range)
  local first_row_distance = math.abs(first[1] - range[1])
  local second_row_distance = math.abs(second[1] - range[1])
  if second_row_distance < first_row_distance then return false end

  local first_col_distance = math.abs(first[2] - range[2])
  local second_col_distance = math.abs(second[2] - range[2])
  if second_row_distance == first_row_distance and second_col_distance < first_col_distance then return false end
  return true
end

---@param nested_lang_tree vim.treesitter.LanguageTree
---@param query vim.treesitter.Query
---@param buf integer
---@param extracted_range Range4
---@return TSNode?
---@return {method: boolean?, singleton: boolean?, struct_name: string?, struct_var_name: string?}
local function get_output_node(nested_lang_tree, query, buf, extracted_range)
  local compare = require("refactoring.range").compare

  local outputs = {} ---@type refactor.Output[]
  for _, tree in ipairs(nested_lang_tree:trees()) do
    for _, match in query:iter_matches(tree:root(), buf) do
      local output ---@type table|refactor.Output|nil
      for capture_id, nodes in pairs(match) do
        local name = query.captures[capture_id]

        if name == "output.comment" then
          output = output or {}
          output.comment = nodes
        elseif name == "output.function" then
          output = output or {}
          output.fn = nodes[1]
        elseif name == "output.function.singleton" then
          output = output or {}
          output.fn = nodes[1]
          output.singleton = true
        elseif name == "output.method" then
          output = output or {}
          output.fn = nodes[1]
          output.method = true
        elseif name == "output.method.singleton" then
          output = output or {}
          output.fn = nodes[1]
          output.method = true
          output.singleton = true
        elseif name == "output.struct_name" then
          output = output or {}
          output.struct_name = ts.get_node_text(nodes[1], buf)
        elseif name == "output.struct_var_name" then
          output = output or {}
          output.struct_var_name = ts.get_node_text(nodes[1], buf)
        end
      end
      if output then table.insert(outputs, output) end
    end
  end

  local lang = nested_lang_tree:lang()
  ---@type refactor.Output|nil
  local selected_output = iter(outputs)
    :filter(
      ---@param o refactor.Output
      function(o)
        local expected = o.method and parents_till_nil[lang].method or parents_till_nil[lang].fn

        local current = o.fn ---@type TSNode|nil
        local p_till_nil = 0
        while current do
          current = current:parent()
          p_till_nil = p_till_nil + 1
        end

        return p_till_nil == expected
      end
    )
    :filter(
      ---@param o refactor.Output
      function(o)
        local n = choose_output(o)
        local start_row, start_col = n:start()
        return compare({ start_row, start_col }, { extracted_range[1], extracted_range[2] }) == -1
      end
    )
    :fold(
      nil,
      ---@param acc refactor.Output|nil
      ---@param o refactor.Output
      function(acc, o)
        if not acc then return o end

        local n = choose_output(o)
        local o_start_row, o_start_col = n:start()
        local acc_n = choose_output(acc)
        local acc_start_row, acc_start_col = acc_n:start()

        local is_o_closer = is_first_closer(
          { o_start_row, o_start_col },
          { acc_start_row, acc_start_col },
          { extracted_range[1], extracted_range[2] }
        )
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

---@param get_key nil|fun(value: any): any
---@return fun(value: any): boolean
local function is_unique(get_key)
  ---@type {[string]: boolean}
  local already_seen = {}

  ---@param value any
  return function(value)
    local key = get_key and get_key(value) or value
    if already_seen[key] then return false end
    already_seen[key] = true
    return true
  end
end

---@param scopes TSNode[]
---@param start Range2
---@param end_ Range2
---@return TSNode|nil
local function smaller_containing_scope(scopes, start, end_)
  local contains = require("refactoring.range").contains

  local declaration_scope = iter(scopes)
    :filter(
      ---@param s TSNode
      function(s)
        local scope_range = { s:range() }
        return contains(scope_range, start) and contains(scope_range, end_)
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

  return declaration_scope
end

---@param all_scopes TSNode[]
---@param range Range4
---@return TSNode[]
local function scopes_for_range(all_scopes, range)
  local contains = require("refactoring.range").contains

  return iter(all_scopes)
    :filter(
      ---@param s TSNode
      function(s)
        local scope_range = { s:range() }
        return contains(scope_range, { range[1], range[2] }) and contains(scope_range, { range[3], range[4] })
      end
    )
    :totable()
end

---@param a TSNode
---@param b TSNode
---@return boolean
local function node_comp_desc(a, b)
  local a_row, a_col, a_bytes = a:start()
  local b_row, b_col, b_bytes = b:start()
  if a_row ~= b_row then return a_row > b_row end

  return (a_col > b_col or a_col + a_bytes > b_col + b_bytes)
end

---@param declarations_by_scope refactor.declaration_by_scope
---@param all_scopes refactor.Scope[]
---@param reference refactor.Reference
---@param buf integer
---@return TSNode|nil
local function get_declaration_scope(declarations_by_scope, all_scopes, reference, buf)
  local compare = require("refactoring.range").compare

  local reference_range = { reference.identifier:range() }
  local scopes_for_reference = scopes_for_range(all_scopes, reference_range)
  table.sort(scopes_for_reference, node_comp_desc)

  local identifier = ts.get_node_text(reference.identifier, buf)
  local reference_start_row, reference_start_col = reference.identifier:start()
  local reference_start = { reference_start_row, reference_start_col }
  return iter(scopes_for_reference):find(
    ---@param s TSNode
    function(s)
      local scope_declarations = declarations_by_scope[s]
      if not scope_declarations then return end
      local identifier_declarations = scope_declarations[identifier]
      if not identifier_declarations then return end

      return iter(identifier_declarations)
        :filter(
          ---@param d refactor.Reference
          function(d)
            local d_start_row, d_start_col = d.identifier:start()
            return compare(reference_start, { d_start_row, d_start_col }) ~= -1
          end
        )
        :fold(
          nil,
          ---@param acc refactor.Reference|nil
          ---@param d refactor.Reference
          function(acc, d)
            if not acc then return d end

            local d_start_row, d_start_col = d.identifier:start()
            local acc_start_row, acc_start_col = acc.identifier:start()

            local is_d_closer = is_first_closer(
              { d_start_row, d_start_col },
              { acc_start_row, acc_start_col },
              reference_start
            )
            if is_d_closer then return d end
            return acc
          end
        )
    end
  )
end

---@param expandtab boolean
---@param size integer
---@param text string
---@param opts {expandtab: number}?
local function indent(expandtab, size, text, opts)
  local indented, previous_size = vim.text.indent(size, text, opts)

  if not expandtab then
    indented = indented:gsub("^( +)", function(spaces)
      return ("\t"):rep(#spaces)
    end)
    indented = indented:gsub("\n( +)", function(spaces)
      return "\n" .. ("\t"):rep(#spaces)
    end)
  end
  return indented, previous_size
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
---@field extracted_range Range4
---@field in_buf integer
---@field lines string[]
---@field out_buf integer
---@field fn_name string

---@param opts refactor.extract_func.Opts
local function extract_func(opts)
  local contains = require("refactoring.range").contains
  local compare = require("refactoring.range").compare

  local extracted_range = opts.extracted_range
  local in_buf = opts.in_buf
  local lines = opts.lines
  local out_buf = opts.out_buf
  local fn_name = opts.fn_name

  local nested_lang_tree, in_query = ts_parse(in_buf, extracted_range)
  if not nested_lang_tree or not in_query then return end

  local out_nested_lang_tree, out_query = ts_parse(out_buf, extracted_range)
  if not out_nested_lang_tree or not out_query then return end
  -- TODO: this doesn't work for `extract_func_to_file` (unless that, because
  -- of a coincidence, the information is available in that file). Instead,
  -- split `get_output_node` and `get_output/input_opts` to get it from
  -- `in_buf` (that will always have the information available instead)
  local output_node, output_opts = get_output_node(out_nested_lang_tree, out_query, out_buf, extracted_range)
  local output_range = output_node and { output_node:range() }
    or in_buf == out_buf and extracted_range
    or { 0, 0, 0, 0 }

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

  local scopes_for_extracted_range = scopes_for_range(scopes, extracted_range)

  local declarations = iter(references)
    :filter(
      ---@param r refactor.Reference
      function(r)
        return r.declaration
      end
    )
    :totable()

  ---@alias refactor.declaration_by_scope {[TSNode]: {[string]: refactor.Reference[]}}
  ---@type refactor.declaration_by_scope
  local declarations_by_scope = iter(declarations):fold(
    {},
    ---@param acc refactor.declaration_by_scope
    ---@param d refactor.Reference
    function(acc, d)
      local start_row, start_col, end_row, end_col = d.identifier:range()
      local scope = smaller_containing_scope(scopes, { start_row, start_col }, { end_row, end_col })
      local identifier = ts.get_node_text(d.identifier, in_buf)
      assert(scope)
      acc[scope] = acc[scope] or {}
      acc[scope][identifier] = acc[scope][identifier] or {}
      table.insert(acc[scope][identifier], d)

      return acc
    end
  )

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
      local compare_start = compare(
        ---@diagnostic disable-next-line: missing-fields
        { a.identifier:start() },
        ---@diagnostic disable-next-line: missing-fields
        { b.identifier:start() }
      )
      if compare_start == -1 then
        return true
      elseif compare_start == 1 then
        return false
      end
      local compare_end = compare(
        ---@diagnostic disable-next-line: missing-fields
        { a.identifier:end_() },
        ---@diagnostic disable-next-line: missing-fields
        { b.identifier:end_() }
      )
      return compare_end == -1
    end
  )
  ---@type {[TSNode]: {scope: TSNode, types: {[string]: string|{identifier: string}}}}
  local types_by_scope_up_to_extracted_range = iter(typed_references)
    :filter(
      ---@param r refactor.Reference
      function(r)
        -- TODO: maybe extract this filter into some function, there are
        -- similar ones for all the `before_` variables
        local start_node = { r.identifier:start() }
        local end_node = { r.identifier:end_() }

        local declaration_scope = get_declaration_scope(declarations_by_scope, scopes, r, in_buf)

        local is_in_scope = declaration_scope
            and iter(scopes_for_extracted_range):any(
              ---@param s TSNode
              function(s)
                return s:equal(declaration_scope)
              end
            )
          or false

        local end_extract = { extracted_range[3], extracted_range[4] }
        local compare_start = compare(start_node, end_extract)
        local compare_end = compare(end_node, end_extract)
        return compare_start ~= 1 and compare_end ~= 1 and is_in_scope
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
  local types_with_scope_up_to_extracted_range = vim.tbl_values(types_by_scope_up_to_extracted_range)
  table.sort(
    types_with_scope_up_to_extracted_range,
    ---@param a {scope: TSNode, types: {[string]: string|{identifier: string}}}
    ---@param b {scope: TSNode, types: {[string]: string|{identifier: string}}}
    function(a, b)
      local compare_start = compare(
        ---@diagnostic disable-next-line: missing-fields
        { a.scope:start() },
        ---@diagnostic disable-next-line: missing-fields
        { b.scope:start() }
      )
      if compare_start == -1 then
        return false
      elseif compare_start == 1 then
        return true
      end
      local compare_end = compare(
        ---@diagnostic disable-next-line: missing-fields
        { a.scope:end_() },
        ---@diagnostic disable-next-line: missing-fields
        { b.scope:end_() }
      )
      return compare_end ~= -1
    end
  )
  ---@type {[string]: string|{identifier: string}}[]
  local scoped_types_up_to_extracted_range = iter(types_with_scope_up_to_extracted_range)
    :map(
      ---@param a {scope: TSNode, types: {[string]: string}}
      function(a)
        return a.types
      end
    )
    :totable()
  iter(scoped_types_up_to_extracted_range):rev():each(
    ---@param t {[string]: string|{identifier: string}}
    function(t)
      for identifier, identifier_type in pairs(t) do
        if type(identifier_type) == "table" then
          local types = iter(scoped_types_up_to_extracted_range):find(
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
  ---@cast scoped_types_up_to_extracted_range{[string]: string}[]

  ---@type refactor.Reference[]
  local references_inside_extracted_range = iter(references)
    :filter(
      ---@param r refactor.Reference
      function(r)
        local n = r.identifier
        local start_node = { n:start() }
        local end_node = { n:end_() }
        local contains_start = contains(extracted_range, start_node)
        local contains_end = contains(extracted_range, end_node)
        return contains_start and contains_end
      end
    )
    :totable()

  local reference_to_variable =
    ---@param r refactor.Reference
    function(r)
      local identifier = ts.get_node_text(r.identifier, in_buf)

      ---@type {[string]: string}|nil
      local types = iter(scoped_types_up_to_extracted_range):find(
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
        local contains_start =
          ---@diagnostic disable-next-line: missing-fields
          contains(extracted_range, { r.identifier:start() })
        local contains_end =
          ---@diagnostic disable-next-line: missing-fields
          contains(extracted_range, { r.identifier:end_() })
        return contains_start and contains_end
      end
    )
    :map(reference_to_text)
    :totable()

  ---@type string[]
  local declarations_before_output_range = iter(declarations)
    :filter(
      ---@param r refactor.Reference
      function(r)
        local start_node = { r.identifier:start() }
        local end_node = { r.identifier:end_() }

        local declaration_scope = get_declaration_scope(declarations_by_scope, scopes, r, in_buf)

        local is_in_scope = declaration_scope
            and iter(scopes_for_extracted_range):any(
              ---@param s TSNode
              function(s)
                return s:equal(declaration_scope)
              end
            )
          or false

        local start_output = { output_range[1], output_range[2] }
        local compare_start = compare(start_node, start_output)
        local compare_end = compare(end_node, start_output)
        return compare_start ~= 1 and compare_end ~= 1 and is_in_scope
      end
    )
    :map(reference_to_text)
    :totable()
  ---@type string[]
  local declarations_before_extracted_range = iter(declarations)
    :filter(
      ---@param r refactor.Reference
      function(r)
        local start_node = { r.identifier:start() }
        local end_node = { r.identifier:end_() }

        local declaration_scope = get_declaration_scope(declarations_by_scope, scopes, r, in_buf)

        local is_in_scope = declaration_scope
            and iter(scopes_for_extracted_range):any(
              ---@param s TSNode
              function(s)
                return s:equal(declaration_scope)
              end
            )
          or false

        local start_extract = { extracted_range[1], extracted_range[2] }
        local compare_start = compare(start_node, start_extract)
        local compare_end = compare(end_node, start_extract)
        return compare_start ~= 1 and compare_end ~= 1 and is_in_scope
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
        return not vim.tbl_contains(declarations_inside_extracted_range, r.identifier)
          and not vim.tbl_contains(declarations_before_output_range, r.identifier)
          and vim.tbl_contains(declarations_before_extracted_range, r.identifier)
      end
    )
    :totable()

  ---@type string[]
  local variables_after_extracted_range = iter(references)
    :filter(
      ---@param r refactor.Reference
      function(r)
        local n = r.identifier
        local start_node = { n:start() }
        local end_node = { n:end_() }

        local declaration_scope = get_declaration_scope(declarations_by_scope, scopes, r, in_buf)
        local is_in_scope = declaration_scope
            and iter(scopes_for_extracted_range):any(
              ---@param s TSNode
              function(s)
                return s:equal(declaration_scope)
              end
            )
          or false

        local extract_end = { extracted_range[3], extracted_range[4] }
        local compare_start = compare(start_node, extract_end)
        local compare_end = compare(end_node, extract_end)
        return compare_start == 1 and compare_end == 1 and is_in_scope
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
        return vim.tbl_contains(write_identifiers_inside_extracted_range, v.identifier)
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

  api.nvim_buf_set_text(
    in_buf,
    extracted_range[1],
    extracted_range[2],
    extracted_range[3],
    extracted_range[4],
    vim.split(function_call, "\n")
  )

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
  api.nvim_buf_set_text(
    out_buf,
    output_range[1],
    output_range[2],
    output_range[1],
    output_range[2],
    function_definition_lines
  )

  -- TODO: maybe use snippets to expand the generated function and
  -- navigate through type placeholders?
end

-- TODO: remove `buf` (first var) from all calls after the rewrite is finished
---@param _ integer
---@param range_type 'v' | 'V' | ''
M.extract_func = function(_, range_type)
  local get_extracted_range = require("refactoring.range").get_extracted_range

  local buf = api.nvim_get_current_buf()
  local extracted_range, lines = get_extracted_range(range_type)

  local task = async.run(function()
    local fn_name = input { prompt = "Function name: " }
    if not fn_name then return end

    extract_func {
      in_buf = buf,
      out_buf = buf,
      extracted_range = extracted_range,
      lines = lines,
      fn_name = fn_name,
    }
  end)
  task:raise_on_error()
end

-- TODO: maybe also generate the import logic(?
---@param _ integer
---@param range_type 'v' | 'V' | ''
M.extract_func_to_file = function(_, range_type)
  local get_extracted_range = require("refactoring.range").get_extracted_range

  local buf = api.nvim_get_current_buf()
  local extracted_range, lines = get_extracted_range(range_type)

  local task = async.run(function()
    local file_name = input {
      prompt = "New file name: ",
      completion = "files",
      default = vim.fn.expand "%:.:h" .. "/",
    }
    if not file_name then return end
    local fn_name = input { prompt = "Function name: " }
    if not fn_name then return end

    local out_buf = vim.fn.bufadd(file_name)
    if not api.nvim_buf_is_loaded(out_buf) then vim.fn.bufload(out_buf) end

    extract_func {
      in_buf = buf,
      out_buf = out_buf,
      extracted_range = extracted_range,
      lines = lines,
      fn_name = fn_name,
    }
  end)
  task:raise_on_error()
end

return M
