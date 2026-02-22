local M = {}

function M.setup()
  require("neotui.ide.options").setup()
  require("neotui.ide.keymaps").setup()
  require("neotui.ide.lazy").setup()
end

return M
