local servers = {
  bashls = {},
  gopls = {},
  jsonls = {},
  lua_ls = {
    settings = {
      Lua = {
        diagnostics = { globals = { "vim" } },
      },
    },
  },
  marksman = {},
  rust_analyzer = {},
  taplo = {},
  ts_ls = {},
  yamlls = {},
}

local state_root = vim.env.XDG_STATE_HOME or vim.fn.stdpath("state")
local format_on_save_disabled_flag = state_root .. "/nvim/format-on-save-disabled"
local debugger_disabled_flag = state_root .. "/nvim/debugger-disabled"
local format_on_save_enabled = vim.fn.filereadable(format_on_save_disabled_flag) ~= 1
local debugger_enabled = vim.fn.filereadable(debugger_disabled_flag) ~= 1

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

local plugins = {
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

if debugger_enabled then
  plugins[#plugins + 1] = {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
      "jay-babu/mason-nvim-dap.nvim",
      "williamboman/mason.nvim",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      require("nvim-dap-virtual-text").setup({})
      dapui.setup({})

      local ok_registry, registry = pcall(require, "mason-registry")

      require("mason-nvim-dap").setup({
        ensure_installed = { "python", "delve" },
        automatic_installation = true,
      })

      local debugpy_python = vim.fn.exepath("python3")
      if ok_registry and registry.has_package("debugpy") then
        local debugpy = registry.get_package("debugpy")
        if debugpy:is_installed() then
          local candidate = debugpy:get_install_path() .. "/venv/bin/python"
          if vim.fn.executable(candidate) == 1 then
            debugpy_python = candidate
          end
        end
      end

      dap.adapters.python = {
        type = "executable",
        command = debugpy_python,
        args = { "-m", "debugpy.adapter" },
      }

      local dlv_cmd = vim.fn.exepath("dlv")
      if dlv_cmd == "" and ok_registry and registry.has_package("delve") then
        local delve = registry.get_package("delve")
        if delve:is_installed() then
          local candidate = delve:get_install_path() .. "/dlv"
          if vim.fn.executable(candidate) == 1 then
            dlv_cmd = candidate
          end
        end
      end
      if dlv_cmd == "" then
        dlv_cmd = "dlv"
      end

      dap.adapters.delve = {
        type = "server",
        port = "${port}",
        executable = {
          command = dlv_cmd,
          args = { "dap", "-l", "127.0.0.1:${port}" },
        },
      }

      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Debug current file",
          program = "${file}",
          console = "integratedTerminal",
        },
      }

      dap.configurations.go = {
        {
          type = "delve",
          name = "Debug current file",
          request = "launch",
          program = "${file}",
        },
      }

      dap.listeners.after.event_initialized["neotui_dapui"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["neotui_dapui"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["neotui_dapui"] = function()
        dapui.close()
      end
    end,
  }
end

return plugins
