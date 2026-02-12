-- ============================================================
-- Neovim Auto Commands
-- ============================================================
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ─── Highlight on Yank ─────────────────────────────────────
augroup("YankHighlight", { clear = true })
autocmd("TextYankPost", {
  group = "YankHighlight",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})

-- ─── Remove Trailing Whitespace on Save ─────────────────────
augroup("TrimWhitespace", { clear = true })
autocmd("BufWritePre", {
  group = "TrimWhitespace",
  pattern = "*",
  command = [[%s/\s\+$//e]],
})

-- ─── Return to Last Edit Position ───────────────────────────
augroup("LastPosition", { clear = true })
autocmd("BufReadPost", {
  group = "LastPosition",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- ─── Auto-resize Splits on Terminal Resize ──────────────────
augroup("ResizeSplits", { clear = true })
autocmd("VimResized", {
  group = "ResizeSplits",
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- ─── Filetype-Specific Settings ─────────────────────────────
augroup("FileTypeSettings", { clear = true })

-- 2-space indent for web languages
autocmd("FileType", {
  group = "FileTypeSettings",
  pattern = { "javascript", "typescript", "typescriptreact", "javascriptreact", "json", "yaml", "html", "css", "lua" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2
  end,
})

-- Go: use tabs
autocmd("FileType", {
  group = "FileTypeSettings",
  pattern = "go",
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})

-- ─── Auto-create Parent Directories on Save ────────────────
augroup("AutoMkdir", { clear = true })
autocmd("BufWritePre", {
  group = "AutoMkdir",
  callback = function(event)
    if event.match:match("^%w%w+://") then
      return
    end
    local file = vim.loop.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})
