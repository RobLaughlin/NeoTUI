# TUI Dev Environment

A complete terminal-based IDE experience built from composable tools: tmux, Neovim, lf, and opencode. Features an IDE-like tab bar, interactive file explorer sidebar, full LSP support, and intelligent shell completion -- all launchable with a single command.

## Quick Start

```bash
# Clone / enter the project
cd ~/projects/tui

# Install all dependencies
./install.sh

# Reload shell to pick up new config
source ~/.bashrc

# Launch the environment
tui
```

## What Gets Installed

| Tool | Purpose |
|------|---------|
| **Neovim** | Editor with LSP, autocomplete, treesitter |
| **lf** | Terminal file manager (interactive sidebar) |
| **fzf** | Fuzzy finder (history, files, directories) |
| **ripgrep** | Fast code search (used by Telescope) |
| **fd** | Fast file finder (used by Telescope + fzf) |
| **bat** | Syntax-highlighted file viewer |
| **eza** | Modern `ls` replacement with icons |
| **carapace** | Shell completion engine (1400+ commands) |
| **opencode** | AI coding assistant for the terminal |

All tools install to `~/.local/bin` (no root required).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Tab Bar (tmux status)         [main] [shell] [opencode]    │
├──────────────┬──────────────────────────────────────────────┤
│              │                                              │
│  lf sidebar  │  Main pane                                   │
│  (file tree) │  (shell / neovim / opencode)                 │
│              │                                              │
│  Auto-syncs  │  Bash with vi-mode + carapace completion     │
│  with shell  │  Neovim with LSP for Go/Python/TS/Bash/C    │
│  directory   │                                              │
│              │                                              │
├──────────────┴──────────────────────────────────────────────┤
│  Neovim statusline (lualine)         branch  diag  filetype │
└─────────────────────────────────────────────────────────────┘
```

## Key Bindings

### tmux (prefix: Ctrl+b)

| Key | Action |
|-----|--------|
| `prefix + T` | Toggle tab bar visibility |
| `prefix + E` | Toggle file explorer sidebar |
| `prefix + O` | Open opencode in new window |
| `prefix + v` | Open Neovim in current directory |
| `prefix + h/j/k/l` | Navigate between panes (vim-style) |
| `prefix + H/J/K/L` | Resize panes |
| `prefix + \|` | Split pane vertically |
| `prefix + -` | Split pane horizontally |
| `prefix + c` | New window (tab) |
| `prefix + n/p` | Next/previous window |
| `prefix + r` | Reload tmux config |

### Neovim (leader: Space)

| Key | Action |
|-----|--------|
| `Space + ff` | Find files (Telescope) |
| `Space + fg` | Live grep (Telescope) |
| `Space + fb` | Find buffers |
| `Space + fr` | Recent files |
| `Space + fs` | Document symbols |
| `Space + fd` | Diagnostics |
| `gd` | Go to definition |
| `gr` | Find references |
| `K` | Hover documentation |
| `Space + rn` | Rename symbol |
| `Space + ca` | Code action |
| `Space + f` | Format file |
| `Space + w` | Save file |
| `Space + q` | Quit |
| `Space + gc` | Git commits |
| `Space + gs` | Git status |
| `Space + hp` | Preview git hunk |
| `Shift + h/l` | Previous/next buffer |

### Shell (Bash vi-mode)

| Key | Action |
|-----|--------|
| `Esc` | Switch to normal mode |
| `i / a` | Switch to insert mode |
| `Ctrl+R` | Fuzzy history search (fzf) |
| `Ctrl+T` | Fuzzy file search (fzf) |
| `Alt+C` | Fuzzy directory jump (fzf) |

Cursor shape changes to indicate mode: beam for insert, block for normal.

### lf (File Explorer)

| Key | Action |
|-----|--------|
| `Enter / o` | Open file in Neovim |
| `dd` | Trash file |
| `yy` | Copy file |
| `yp` | Copy file path to clipboard |
| `pp` | Paste file |
| `md` | Create directory |
| `mf` | Create file |
| `r` | Rename |
| `R` | Bulk rename |
| `.` | Toggle hidden files |
| `gh` | Go to home |
| `gp` | Go to ~/projects |

## LSP Support

Language servers are auto-installed via mason.nvim on first Neovim launch:

| Language | Server |
|----------|--------|
| Go | gopls |
| Python | pyright |
| TypeScript/JS | ts_ls |
| Bash/Shell | bash-language-server |
| C/C++ | clangd |
| Lua | lua_ls |

## File Structure

```
tui/
├── install.sh              # Dependency installer
├── README.md               # This file
├── tmux/
│   └── tmux.conf           # tmux configuration (tab bar, keybinds)
├── nvim/
│   ├── init.lua            # Neovim entry point
│   └── lua/
│       ├── core/
│       │   ├── options.lua # Editor settings
│       │   ├── keymaps.lua # Key mappings
│       │   └── autocmds.lua# Auto commands
│       └── plugins/
│           ├── lsp.lua     # LSP + mason configuration
│           ├── cmp.lua     # Autocompletion
│           ├── treesitter.lua # Syntax highlighting
│           ├── telescope.lua  # Fuzzy finder
│           └── ui.lua      # Theme, statusline, git signs
├── lf/
│   ├── lfrc               # lf configuration
│   └── preview.sh         # File previewer script
├── shell/
│   ├── env.sh             # Environment variables, tool init
│   ├── vi-mode.sh         # Bash vi-mode + prompt
│   ├── hooks.sh           # Directory sync hooks
│   └── aliases.sh         # Shell aliases
└── bin/
    ├── tui                # Main launcher
    └── tui-toggle-sidebar # Sidebar toggle helper
```

## Configuration

All config files live in this repo. The installer creates symlinks:

- `tmux/tmux.conf` -> `~/.tmux.conf`
- `nvim/` -> `~/.config/nvim/`
- `lf/lfrc` -> `~/.config/lf/lfrc`
- `lf/preview.sh` -> `~/.config/lf/preview.sh`
- Shell scripts are sourced from `~/.bashrc`

Edit the files in this repo and changes take effect immediately (tmux: `prefix + r` to reload, Neovim: restart).

## WSL2 Notes

- **Nerd Font**: Must be installed on the Windows side. Go to [nerdfonts.com](https://www.nerdfonts.com/font-downloads), download JetBrainsMono Nerd Font, install it, then set it in Windows Terminal settings (Profiles > Appearance > Font Face).
- **Clipboard**: Configured to use `clip.exe` for copy operations.
- **True Color**: Works automatically with Windows Terminal.

## Troubleshooting

**Neovim plugins not installing**: Run `:Lazy` in Neovim to see plugin status. Run `:Lazy sync` to force install.

**LSP servers not found**: Run `:Mason` in Neovim to check server status. Run `:MasonInstall <server>` to manually install.

**Icons look broken**: Install a Nerd Font and set it in your terminal emulator.

**lf sidebar not syncing**: Make sure `shell/hooks.sh` is sourced in your `.bashrc`. Check with `echo $PROMPT_COMMAND`.

**Tab bar not visible**: Press `Ctrl+b, T` to toggle it back on.
