local servers = {
  bashls = {},
  jsonls = {},
  lua_ls = {
    settings = {
      Lua = {
        diagnostics = { globals = { "vim" } },
      },
    },
  },
  marksman = {},
  taplo = {},
  yamlls = {},
}

return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "saghen/blink.cmp",
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
    },
    config = function()
      require("mason").setup()
      require("mason-lspconfig").setup({
        ensure_installed = vim.tbl_keys(servers),
        automatic_installation = true,
      })

      require("mason-tool-installer").setup({
        ensure_installed = {
          "stylua",
          "shfmt",
          "shellcheck",
          "prettier",
        },
        auto_update = false,
        run_on_start = true,
      })

      local capabilities = require("blink.cmp").get_lsp_capabilities()

      for name, config in pairs(servers) do
        config.capabilities = capabilities
        if vim.lsp and vim.lsp.config and vim.lsp.enable then
          vim.lsp.config(name, config)
          vim.lsp.enable(name)
        else
          local lspconfig = require("lspconfig")
          lspconfig[name].setup(config)
        end
      end
    end,
  },
  {
    "saghen/blink.cmp",
    version = "*",
    opts = {
      keymap = { preset = "default" },
      completion = {
        documentation = { auto_show = true },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
  },
  {
    "L3MON4D3/LuaSnip",
    event = "InsertEnter",
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local ok, treesitter = pcall(require, "nvim-treesitter")
      if not ok then
        return
      end

      treesitter.setup({
        ensure_installed = {
          "bash",
          "json",
          "lua",
          "markdown",
          "markdown_inline",
          "toml",
          "vim",
          "yaml",
        },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = {},
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        bash = { "shfmt" },
        json = { "prettier" },
        lua = { "stylua" },
        markdown = { "prettier" },
        sh = { "shfmt" },
        toml = { "taplo" },
        yaml = { "prettier" },
        zsh = { "shfmt" },
      },
      format_on_save = {
        timeout_ms = 1000,
        lsp_fallback = true,
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        bash = { "shellcheck" },
        sh = { "shellcheck" },
        zsh = { "shellcheck" },
      }

      local group = vim.api.nvim_create_augroup("neotui_nvim_lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group = group,
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },
  {
    "Exafunction/codeium.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("codeium").setup({
        enable_chat = false,
        enable_cmp_source = false,
      })
    end,
  },
}
