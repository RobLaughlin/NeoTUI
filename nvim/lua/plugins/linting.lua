-- ============================================================
-- Linting: nvim-lint + :Check command for project-wide linting
-- ============================================================
return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        terraform = { "terraform_validate" },
        tf = { "terraform_validate" },
        sh = { "shellcheck" },
        python = { "ruff" },
        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        go = { "golangcilint" },
        lua = { "luacheck" },
      }
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },

  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
}
