-- ============================================================
-- Autocompletion (nvim-cmp)
-- ============================================================
return {
  "hrsh7th/nvim-cmp",
  event = { "InsertEnter", "CmdlineEnter" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",        -- LSP completions
    "hrsh7th/cmp-buffer",           -- Buffer word completions
    "hrsh7th/cmp-path",             -- File path completions
    "hrsh7th/cmp-cmdline",          -- Command-line completions
    "L3MON4D3/LuaSnip",            -- Snippet engine
    "saadparwaiz1/cmp_luasnip",     -- Snippet completions
    "rafamadriz/friendly-snippets", -- Snippet collection
  },
  config = function()
    local cmp = require("cmp")
    local luasnip = require("luasnip")

    -- Load VSCode-style snippets
    require("luasnip.loaders.from_vscode").lazy_load()

    -- Kind icons for completion menu
    local kind_icons = {
      Text = "󰉿", Method = "󰆧", Function = "󰊕", Constructor = "",
      Field = "󰜢", Variable = "󰀫", Class = "󰠱", Interface = "",
      Module = "", Property = "󰜢", Unit = "󰑭", Value = "󰎠",
      Enum = "", Keyword = "󰌋", Snippet = "", Color = "󰏘",
      File = "󰈙", Reference = "󰈇", Folder = "󰉋", EnumMember = "",
      Constant = "󰏿", Struct = "󰙅", Event = "", Operator = "󰆕",
      TypeParameter = "",
    }

    cmp.setup({
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },

      window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
      },

      mapping = cmp.mapping.preset.insert({
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<CR>"] = cmp.mapping.confirm({ select = false }),

        -- Tab to cycle through completions
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          else
            fallback()
          end
        end, { "i", "s" }),

        -- Shift-Tab to cycle backwards
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      }),

      formatting = {
        format = function(entry, vim_item)
          vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind] or "", vim_item.kind)
          vim_item.menu = ({
            nvim_lsp = "[LSP]",
            luasnip = "[Snip]",
            buffer = "[Buf]",
            path = "[Path]",
          })[entry.source.name]
          return vim_item
        end,
      },

      sources = cmp.config.sources({
        { name = "nvim_lsp", priority = 1000 },
        { name = "luasnip", priority = 750 },
        { name = "path", priority = 500 },
      }, {
        { name = "buffer", priority = 250 },
      }),
    })

    -- Command-line completion for ':'
    cmp.setup.cmdline(":", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({
        { name = "path" },
      }, {
        { name = "cmdline" },
      }),
    })

    -- Search completion for '/'
    cmp.setup.cmdline("/", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = {
        { name = "buffer" },
      },
    })
  end,
}
