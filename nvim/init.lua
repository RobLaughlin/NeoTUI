local init_file = debug.getinfo(1, "S").source:sub(2)
local config_root = vim.fn.fnamemodify(init_file, ":p:h")
vim.opt.rtp:prepend(config_root)

local state_root = vim.env.XDG_STATE_HOME or vim.fn.stdpath("state")
local ide_flag = state_root .. "/nvim/ide-profile-enabled"

if vim.fn.filereadable(ide_flag) == 1 then
  require("neotui.ide").setup()
else
  require("neotui.minimal").setup()
end
