local M = {}

function M.setup()
  local state_root = vim.env.XDG_STATE_HOME or vim.fn.stdpath("state")
  local ai_prompt_disabled_flag = state_root .. "/nvim/ai-prompt-insertion-disabled"
  local debugger_disabled_flag = state_root .. "/nvim/debugger-disabled"
  local ai_prompt_enabled = vim.fn.filereadable(ai_prompt_disabled_flag) ~= 1
  local debugger_enabled = vim.fn.filereadable(debugger_disabled_flag) ~= 1

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

  if debugger_enabled then
    vim.keymap.set("n", "<leader>db", function()
      require("dap").toggle_breakpoint()
    end, { silent = true, desc = "Debug toggle breakpoint" })
    vim.keymap.set("n", "<leader>dc", function()
      require("dap").continue()
    end, { silent = true, desc = "Debug continue" })
    vim.keymap.set("n", "<leader>di", function()
      require("dap").step_into()
    end, { silent = true, desc = "Debug step into" })
    vim.keymap.set("n", "<leader>do", function()
      require("dap").step_over()
    end, { silent = true, desc = "Debug step over" })
    vim.keymap.set("n", "<leader>dO", function()
      require("dap").step_out()
    end, { silent = true, desc = "Debug step out" })
    vim.keymap.set("n", "<leader>du", function()
      require("dapui").toggle()
    end, { silent = true, desc = "Debug UI toggle" })
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(event)
      local opts = { buffer = event.buf }
      local function map(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, vim.tbl_extend("force", opts, { desc = desc }))
      end

      map("gd", vim.lsp.buf.definition, "Goto definition")
      map("gr", vim.lsp.buf.references, "Goto references")
      map("K", vim.lsp.buf.hover, "Hover")
      map("<leader>rn", vim.lsp.buf.rename, "Rename")
      map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    end,
  })
end

return M
