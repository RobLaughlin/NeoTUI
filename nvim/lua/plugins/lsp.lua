-- ============================================================
-- LSP Configuration (mason + lspconfig)
-- ============================================================
return {
  -- Mason: manages LSP server installations
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup({
        ui = {
          border = "rounded",
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      })
    end,
  },

  -- Bridge between mason and lspconfig
  -- Pinned to v1.x for Neovim 0.10 compatibility (v2+ needs 0.11)
  {
    "williamboman/mason-lspconfig.nvim",
    version = "^1",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "gopls",           -- Go
          "pyright",         -- Python
          "ts_ls",           -- TypeScript/JavaScript
          "bashls",          -- Bash/Shell
          "clangd",          -- C/C++
          "lua_ls",          -- Lua (for Neovim config)
        },
        automatic_installation = true,
      })
    end,
  },

  -- LSP configuration
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Diagnostic display settings
      vim.diagnostic.config({
        virtual_text = { spacing = 4, prefix = "●" },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = "rounded",
          source = "always",
        },
      })

      -- Diagnostic signs
      local signs = { Error = " ", Warn = " ", Hint = "󰌵 ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
      end

      -- LSP keymaps (attached per-buffer when LSP connects)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local map = vim.keymap.set
          local o = { buffer = ev.buf, silent = true }

          map("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", o, { desc = "Go to definition" }))
          map("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", o, { desc = "Go to declaration" }))
          map("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", o, { desc = "Go to implementation" }))
          map("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", o, { desc = "Find references" }))
          map("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", o, { desc = "Hover info" }))
          map("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", o, { desc = "Rename symbol" }))
          map("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", o, { desc = "Code action" }))
          map("n", "<leader>f", function()
            vim.lsp.buf.format({ async = true })
          end, vim.tbl_extend("force", o, { desc = "Format file" }))
          map("n", "<leader>sh", vim.lsp.buf.signature_help, vim.tbl_extend("force", o, { desc = "Signature help" }))
        end,
      })

      -- Server configurations
      local servers = {
        gopls = {
          settings = {
            gopls = {
              analyses = {
                unusedparams = true,
                shadow = true,
              },
              staticcheck = true,
              gofumpt = true,
            },
          },
        },
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic",
                autoImportCompletions = true,
              },
            },
          },
        },
        ts_ls = {},
        bashls = {},
        clangd = {
          cmd = { "clangd", "--background-index", "--clang-tidy" },
        },
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = { globals = { "vim" } },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = false,
              },
              telemetry = { enable = false },
              completion = { callSnippet = "Replace" },
            },
          },
        },
      }

      for server, config in pairs(servers) do
        config.capabilities = capabilities
        lspconfig[server].setup(config)
      end
    end,
  },
}
