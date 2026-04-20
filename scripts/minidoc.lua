local minidoc = require "mini.doc"

minidoc.setup {
  hooks = {
    sections = {
      ["@class"] = function(s)
        s[1] = s[1]:gsub("(%S+)", "*%1*", 1)
      end,
      ["@field"] = function(s)
        s[1] = s[1]:gsub("^%s*(%S+)%s*(%S+)", "{%1} (`%2`)", 1)
      end,
      ["@param"] = function(s)
        s[1] = s[1]:gsub("^%s*(%S+)%s*(%S+)", "{%1} (`%2`)", 1)
      end,
    },
  },
}

MiniDoc.generate({ "./lua/refactoring.lua", "./lua/refactoring/debug.lua" }, "doc/refactoring.txt")
