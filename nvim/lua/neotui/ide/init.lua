local M = {}

function M.setup()
  require("neotui.ide.options").setup()
  local explorer = require("neotui.ide.explorer")
  local ai_insert = require("neotui.ide.ai_insert")

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

  vim.api.nvim_create_user_command("NeoTUIAIProvider", function()
    ai_insert.select_provider()
  end, { desc = "AI prompt provider/auth menu" })

  vim.api.nvim_create_user_command("NeoTUIAIModel", function()
    ai_insert.select_model()
  end, { desc = "Select AI prompt insertion model route" })

  vim.api.nvim_create_user_command("NeoTUIAIStatus", function()
    ai_insert.show_status()
  end, { desc = "Show AI prompt insertion provider status" })

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
