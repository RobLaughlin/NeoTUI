-- ============================================================
-- Neovim Key Mappings
-- ============================================================
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- ─── Window Navigation ─────────────────────────────────────
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- ─── Window Resizing ───────────────────────────────────────
map("n", "<C-Up>", ":resize +2<CR>", opts)
map("n", "<C-Down>", ":resize -2<CR>", opts)
map("n", "<C-Left>", ":vertical resize -2<CR>", opts)
map("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- ─── Buffer Navigation ─────────────────────────────────────
map("n", "<S-l>", ":bnext<CR>", { desc = "Next buffer" })
map("n", "<S-h>", ":bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>bd", ":bdelete<CR>", { desc = "Close buffer" })

-- ─── Search ─────────────────────────────────────────────────
map("n", "<leader>h", ":nohlsearch<CR>", { desc = "Clear search highlight" })
-- Center screen after search navigation
map("n", "n", "nzzzv", opts)
map("n", "N", "Nzzzv", opts)

-- ─── Visual Mode ────────────────────────────────────────────
-- Stay in visual mode after indenting
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)

-- Move selected lines up/down
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- ─── Quality of Life ───────────────────────────────────────
-- Save
map("n", "<leader>w", ":w<CR>", { desc = "Save file" })
map("n", "<leader>W", ":wa<CR>", { desc = "Save all files" })

-- Quit
map("n", "<leader>q", ":q<CR>", { desc = "Quit" })
map("n", "<leader>Q", ":qa<CR>", { desc = "Quit all" })

-- Don't yank on paste in visual mode
map("v", "p", '"_dP', opts)

-- Don't yank on x
map("n", "x", '"_x', opts)

-- Join lines without moving cursor
map("n", "J", "mzJ`z", opts)

-- Center screen on half-page jumps
map("n", "<C-d>", "<C-d>zz", opts)
map("n", "<C-u>", "<C-u>zz", opts)

-- ─── Diagnostics ────────────────────────────────────────────
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Float diagnostics" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>dl", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })

-- ─── Terminal ───────────────────────────────────────────────
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
