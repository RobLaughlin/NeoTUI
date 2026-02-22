local M = {}

function M.setup()
  require("neotui.ide.options").setup()
  local explorer = require("neotui.ide.explorer")

  vim.api.nvim_create_user_command("NeoTUIExplorerEnable", function()
    explorer.enable()
    vim.notify("Neo-tree sticky mode enabled.")
  end, { desc = "Open Neo-tree explorer" })

  vim.api.nvim_create_user_command("NeoTUIExplorerDisable", function()
    explorer.disable()
    vim.notify("Neo-tree sticky mode disabled.")
  end, { desc = "Close Neo-tree explorer" })

  vim.api.nvim_create_user_command("NeoTUIExplorerToggle", function()
    explorer.toggle()
  end, { desc = "Toggle Neo-tree explorer" })

  vim.api.nvim_create_autocmd("TabEnter", {
    callback = function()
      explorer.on_tab_enter()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    callback = function()
      explorer.capture_from_current_buffer()
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
    pattern = "*",
    callback = function()
      if vim.bo.filetype == "neo-tree" then
        explorer.capture_from_neotree_cursor()
      end
    end,
  })

  require("neotui.ide.keymaps").setup()
  require("neotui.ide.lazy").setup()
end

return M
