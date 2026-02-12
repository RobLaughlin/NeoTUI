-- ============================================================
-- Telescope (fuzzy finder)
-- ============================================================
return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  cmd = "Telescope",
  keys = {
    { "<leader>ff", desc = "Find files" },
    { "<leader>fg", desc = "Live grep" },
    { "<leader>fb", desc = "Find buffers" },
    { "<leader>fh", desc = "Help tags" },
    { "<leader>fr", desc = "Recent files" },
    { "<leader>fs", desc = "Document symbols" },
    { "<leader>fd", desc = "Diagnostics" },
    { "<leader>gc", desc = "Git commits" },
    { "<leader>gs", desc = "Git status" },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")
    local builtin = require("telescope.builtin")

    telescope.setup({
      defaults = {
        path_display = { "truncate" },
        sorting_strategy = "ascending",
        layout_config = {
          horizontal = {
            prompt_position = "top",
            preview_width = 0.55,
          },
          width = 0.87,
          height = 0.80,
        },
        mappings = {
          i = {
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
            ["<Esc>"] = actions.close,
          },
        },
        file_ignore_patterns = {
          "node_modules/",
          ".git/",
          "vendor/",
          "__pycache__/",
          "%.o",
          "%.a",
          "%.out",
        },
      },
      pickers = {
        find_files = { hidden = true },
        live_grep = {
          additional_args = function()
            return { "--hidden" }
          end,
        },
      },
    })

    -- Load fzf extension for faster sorting
    telescope.load_extension("fzf")

    -- Keymaps
    local map = vim.keymap.set
    map("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
    map("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
    map("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
    map("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
    map("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
    map("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Document symbols" })
    map("n", "<leader>fd", builtin.diagnostics, { desc = "Diagnostics" })
    map("n", "<leader>gc", builtin.git_commits, { desc = "Git commits" })
    map("n", "<leader>gs", builtin.git_status, { desc = "Git status" })
  end,
}
