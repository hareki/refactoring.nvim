vim.cmd "set rtp+=."

vim.cmd "set rtp+=deps/mini.nvim"
vim.cmd "set rtp+=deps/async.nvim"
vim.cmd "set rtp+=deps/mason.nvim"
vim.cmd "set rtp+=deps/nvim-treesitter"

require("mini.test").setup()
require("mason").setup {
  install_root_dir = vim.fn.getcwd() .. "/deps/bin",
}
require("nvim-treesitter").setup {
  install_dir = vim.fn.getcwd() .. "/deps/parsers",
}

vim.lsp.config("lua_ls", {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = {
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    ".stylua.toml",
    "stylua.toml",
    "selene.toml",
    "selene.yml",
    ".git",
  },
})
vim.lsp.config("clangd", {
  cmd = { "clangd" },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  root_markers = {
    ".clangd",
    ".clang-tidy",
    ".clang-format",
    "compile_commands.json",
    "compile_flags.txt",
    ".git",
  },
  capabilities = {
    textDocument = {
      completion = {
        editsNearCursor = true,
      },
    },
    offsetEncoding = { "utf-8", "utf-16" },
  },
  on_init = function(client, init_result)
    if init_result.offsetEncoding then client.offset_encoding = init_result.offsetEncoding end
  end,
})
vim.lsp.enable { "lua_ls", "clangd" }

vim.g.mapleader = " "
vim.keymap.set("n", "<leader>ai", function()
  return require("refactoring").refactor "Inline Variable"
end, { expr = true })
vim.keymap.set("n", "<leader>ae", function()
  return require("refactoring").refactor "Extract Function"
end, { expr = true })
vim.keymap.set("n", "<leader>av", function()
  return require("refactoring").refactor "Extract Variable"
end, { expr = true })
