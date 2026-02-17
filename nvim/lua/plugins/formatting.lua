-- ============================================================
-- Formatting Configuration (conform.nvim)
--
-- <leader>f  - Format file manually
-- <leader>F  - Toggle format-on-save
--
-- Format-on-save is DISABLED by default.
-- ============================================================
return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>f",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        mode = "n",
        desc = "Format file",
      },
      {
        "<leader>F",
        function()
          vim.g.neotui_format_on_save = not vim.g.neotui_format_on_save
          local status = vim.g.neotui_format_on_save and "enabled" or "disabled"
          vim.notify("Format-on-save " .. status, vim.log.levels.INFO)
        end,
        mode = "n",
        desc = "Toggle format-on-save",
      },
    },
    config = function()
      require("conform").setup({
        -- Prettier for web languages; LSP handles the rest (gopls, lua_ls, clangd)
        formatters_by_ft = {
          javascript = { "prettier" },
          javascriptreact = { "prettier" },
          typescript = { "prettier" },
          typescriptreact = { "prettier" },
          css = { "prettier" },
          scss = { "prettier" },
          html = { "prettier" },
          json = { "prettier" },
          jsonc = { "prettier" },
          yaml = { "prettier" },
          markdown = { "prettier" },
          graphql = { "prettier" },
          vue = { "prettier" },
          svelte = { "prettier" },
        },

        -- Format-on-save: disabled unless vim.g.neotui_format_on_save is set
        format_on_save = function()
          if not vim.g.neotui_format_on_save then
            return
          end
          return {
            timeout_ms = 3000,
            lsp_fallback = true,
          }
        end,
      })
    end,
  },
}
