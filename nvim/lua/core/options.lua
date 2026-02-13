-- ============================================================
-- Neovim Options
-- ============================================================
local opt = vim.opt

-- ─── Line Numbers ───────────────────────────────────────────
opt.number = true
opt.relativenumber = true

-- ─── Tabs & Indentation ────────────────────────────────────
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true

-- ─── Search ─────────────────────────────────────────────────
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- ─── Appearance ─────────────────────────────────────────────
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.colorcolumn = "100"
opt.wrap = false
opt.showmode = false          -- Shown by lualine instead
opt.pumheight = 10            -- Popup menu height

-- ─── Split Behavior ────────────────────────────────────────
opt.splitright = true
opt.splitbelow = true

-- ─── Undo & Backup ─────────────────────────────────────────
opt.undofile = true
opt.swapfile = false
opt.backup = false
opt.writebackup = false

-- ─── Clipboard (WSL2, Wayland, X11 compatible) ───────────────
opt.clipboard = "unnamedplus"

if vim.fn.has("wsl") == 1 then
  vim.g.clipboard = {
    name = "WslClipboard",
    copy = {
      ["+"] = "clip.exe",
      ["*"] = "clip.exe",
    },
    paste = {
      ["+"] = 'powershell.exe -NoLogo -NoProfile -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
      ["*"] = 'powershell.exe -NoLogo -NoProfile -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    },
    cache_enabled = 0,
  }
elseif vim.fn.executable("wl-copy") == 1 then
  vim.g.clipboard = {
    name = "WaylandClipboard",
    copy = {
      ["+"] = "wl-copy",
      ["*"] = "wl-copy",
    },
    paste = {
      ["+"] = "wl-paste --no-newline",
      ["*"] = "wl-paste --no-newline",
    },
    cache_enabled = 0,
  }
end

-- ─── Performance ────────────────────────────────────────────
opt.updatetime = 250
opt.timeoutlen = 300
opt.lazyredraw = false

-- ─── Mouse ──────────────────────────────────────────────────
opt.mouse = "a"

-- ─── Completion ─────────────────────────────────────────────
opt.completeopt = { "menu", "menuone", "noselect" }

-- ─── Misc ───────────────────────────────────────────────────
opt.conceallevel = 0
opt.fileencoding = "utf-8"
opt.backspace = { "start", "eol", "indent" }
opt.iskeyword:append("-")
