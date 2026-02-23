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

local state_root = vim.env.XDG_STATE_HOME or vim.fn.stdpath("state")
local format_on_save_disabled_flag = state_root .. "/nvim/format-on-save-disabled"
local format_on_save_enabled = vim.fn.filereadable(format_on_save_disabled_flag) ~= 1

local function python_mason_ready()
  if vim.fn.executable("python3") ~= 1 then
    return false
  end

  vim.fn.system({ "python3", "-m", "ensurepip", "--version" })
  if vim.v.shell_error == 0 then
    return true
  end

  vim.fn.system({ "python3", "-m", "pip", "--version" })
  return vim.v.shell_error == 0
end

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
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
        ensure_installed = (function()
          local tools = {
            "stylua",
            "shfmt",
            "shellcheck",
            "prettier",
          }

          if python_mason_ready() then
            tools[#tools + 1] = "black"
            tools[#tools + 1] = "ruff"
          end

          return tools
        end)(),
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
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = { "Neotree" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      close_if_last_window = true,
      filesystem = {
        follow_current_file = {
          enabled = true,
        },
      },
      window = {
        width = 32,
        mappings = {
          ["<cr>"] = function(state)
            require("neotui.ide.explorer").open_in_tab_and_sync(state)
          end,
        },
      },
    },
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
        css = { "prettier" },
        go = { "gofmt" },
        html = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        lua = { "stylua" },
        markdown = { "prettier" },
        python = { "ruff_format", "black" },
        rust = { "rustfmt" },
        scss = { "prettier" },
        sh = { "shfmt" },
        toml = { "taplo" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        yaml = { "prettier" },
        zsh = { "shfmt" },
      },
      format_on_save = format_on_save_enabled and function(bufnr)
        local conform = require("conform")
        local formatters, lsp_available = conform.list_formatters_to_run(bufnr)
        if #formatters == 0 and not lsp_available then
          return nil
        end

        return {
          timeout_ms = 1000,
          lsp_fallback = true,
        }
      end or nil,
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
        virtual_text = {
          enabled = true,
          manual = false,
          default_filetype_enabled = true,
          map_keys = false,
          accept_fallback = "",
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

      local vt = require("codeium.virtual_text")
      vim.keymap.set("i", "<S-Tab>", function()
        return vt.accept()
      end, { expr = true, silent = true, desc = "Codeium accept" })
      vim.keymap.set("i", "<C-y>", function()
        return vt.accept()
      end, { expr = true, silent = true, desc = "Codeium accept" })
      vim.keymap.set("i", "<C-g>", function()
        return vt.accept_next_line()
      end, { expr = true, silent = true, desc = "Codeium accept line" })
      vim.keymap.set("i", "<M-]>", function()
        vt.cycle_completions(1)
      end, { silent = true, desc = "Codeium next" })
      vim.keymap.set("i", "<M-[>", function()
        vt.cycle_completions(-1)
      end, { silent = true, desc = "Codeium prev" })
      vim.keymap.set("i", "<C-x>", function()
        vt.clear()
      end, { silent = true, desc = "Codeium clear" })
    end,
  },
}
