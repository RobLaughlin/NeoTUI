local M = {}

function M.setup()
  vim.opt.number = true
  vim.opt.relativenumber = true
  vim.opt.termguicolors = true
  vim.opt.expandtab = true
  vim.opt.shiftwidth = 2
  vim.opt.tabstop = 2
  vim.opt.signcolumn = "yes"
  vim.opt.updatetime = 250
  vim.opt.completeopt = "menu,menuone,noselect"
  vim.opt.showtabline = 2

  vim.g.mapleader = " "
end

return M
