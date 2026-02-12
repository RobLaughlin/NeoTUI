-- ============================================================
-- Windsurf/Codeium - Free AI autocompletion (ghost text)
-- ============================================================
-- Setup:
--   1. Create a free account at https://windsurf.com
--   2. Run :Codeium Auth in Neovim and paste the token
--   3. Start typing — multi-line AI suggestions appear as ghost text
--
-- Keybindings (insert mode):
--   Tab         — accept the full suggestion
--   Alt+w       — accept just the next word
--   Alt+l       — accept just the next line
--   Alt+]       — cycle to next suggestion
--   Alt+[       — cycle to previous suggestion
--   Ctrl+e      — dismiss suggestion
--
-- Commands:
--   :Codeium Auth     — authenticate (one-time)
--   :Codeium Toggle   — enable/disable completions
--   :Codeium Chat     — open AI chat in browser
-- ============================================================
return {
  "Exafunction/windsurf.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "hrsh7th/nvim-cmp",
  },
  event = "InsertEnter",
  cmd = "Codeium",
  config = function()
    require("codeium").setup({
      -- Disable cmp source — we use ghost text instead for multi-line suggestions
      enable_cmp_source = false,
      -- Ghost text: shows multi-line suggestions inline, like Cursor
      virtual_text = {
        enabled = true,
        idle_delay = 75,
        virtual_text_priority = 65535,
        -- Don't map Tab here — we handle it in cmp.lua to avoid conflicts
        map_keys = false,
        key_bindings = {
          accept = false,
          accept_word = false,
          accept_line = false,
          clear = false,
          next = false,
          prev = false,
        },
      },
    })

    -- Ghost text style: faded blue with italics (Cursor-like)
    vim.api.nvim_set_hl(0, "CodeiumSuggestion", { fg = "#5b7ea6", italic = true })
    -- Re-apply after colorscheme changes
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        vim.api.nvim_set_hl(0, "CodeiumSuggestion", { fg = "#5b7ea6", italic = true })
      end,
    })

    -- Set up keybindings manually for better control
    local vt = require("codeium.virtual_text")
    local opts = { expr = true, silent = true }

    -- Alt+w: accept next word only
    vim.keymap.set("i", "<M-w>", function()
      return vt.accept_word()
    end, opts)

    -- Alt+l: accept next line only
    vim.keymap.set("i", "<M-l>", function()
      return vt.accept_line()
    end, opts)

    -- Alt+]: cycle to next suggestion
    vim.keymap.set("i", "<M-]>", function()
      return vt.cycle_or_complete()
    end, opts)

    -- Alt+[: cycle to previous suggestion
    vim.keymap.set("i", "<M-[>", function()
      return vt.cycle_completions(-1)
    end, opts)
  end,
}
