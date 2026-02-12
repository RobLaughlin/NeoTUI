-- ============================================================
-- Treesitter (syntax highlighting & more)
-- ============================================================
return {
  "nvim-treesitter/nvim-treesitter",
  tag = "v0.9.2",  -- Pinned for Neovim 0.10 (latest removed configs module)
  build = ":TSUpdate",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        -- Target languages
        "go", "gomod", "gosum",
        "python",
        "typescript", "tsx", "javascript",
        "bash",
        "c", "cpp",
        "lua",
        -- Common config/data formats
        "json", "yaml", "toml",
        "html", "css",
        "markdown", "markdown_inline",
        -- Neovim
        "vim", "vimdoc", "query",
        -- Other
        "regex",
        "dockerfile",
        "gitignore", "gitcommit", "diff",
        "sql",
        "make",
      },

      auto_install = true,

      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },

      indent = {
        enable = true,
      },

      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = false,
          node_decremental = "<bs>",
        },
      },
    })
  end,
}
