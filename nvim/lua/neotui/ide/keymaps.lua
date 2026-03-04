local M = {}

function M.setup()
  local state_root = vim.env.XDG_STATE_HOME or vim.fn.stdpath("state")
  local ai_prompt_disabled_flag = state_root .. "/nvim/ai-prompt-insertion-disabled"
  local ai_prompt_enabled = vim.fn.filereadable(ai_prompt_disabled_flag) ~= 1

  vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Write file" })
  vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit window" })
  vim.keymap.set("n", "<leader>fm", function()
    require("conform").format({ async = true, lsp_fallback = true })
  end, { desc = "Format file" })

  vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
  vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

  vim.keymap.set("n", "<C-h>", "gT", { noremap = true, silent = true, desc = "Prev nvim tab" })
  vim.keymap.set("n", "<C-l>", "gt", { noremap = true, silent = true, desc = "Next nvim tab" })

  vim.keymap.set("n", "<leader>ff", function()
    require("telescope.builtin").find_files()
  end, { desc = "Find files" })
  vim.keymap.set("n", "<leader>fg", function()
    require("telescope.builtin").live_grep()
  end, { desc = "Live grep" })
  vim.keymap.set("n", "<leader>fb", function()
    require("telescope.builtin").buffers()
  end, { desc = "Buffers" })
  vim.keymap.set("n", "<leader>fh", function()
    require("telescope.builtin").help_tags()
  end, { desc = "Help tags" })
  vim.keymap.set("n", "<leader>e", function()
    require("neotui.ide.explorer").toggle()
  end, { desc = "Toggle Neo-tree explorer" })

  if ai_prompt_enabled then
    vim.keymap.set("n", "<leader>ap", function()
      require("neotui.ide.ai_insert").select_provider()
    end, { silent = true, desc = "AI provider/auth menu" })
    vim.keymap.set("n", "<leader>am", function()
      require("neotui.ide.ai_insert").select_model()
    end, { silent = true, desc = "AI model select" })
    vim.keymap.set("n", "<C-k>", function()
      require("neotui.ide.ai_insert").prompt_and_insert()
    end, { silent = true, desc = "AI prompt insert" })
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(event)
      local opts = { buffer = event.buf }
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Goto definition" }))
      vim.keymap.set("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "Goto references" }))
      vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover" }))
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename" }))
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
    end,
  })
end

return M
