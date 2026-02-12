-- ============================================================
-- NeoTUI - Neovim Configuration
-- ============================================================

-- Set leader key before anything else
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load core settings
require("core.options")
require("core.keymaps")
require("core.autocmds")

-- Bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load plugins (auto-discovers all files in lua/plugins/)
require("lazy").setup("plugins", {
  ui = { border = "rounded" },
  checker = { enabled = false },
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
