# NeoTUI

A modern, out-of-the-box terminal IDE for developers who want to code in the terminal with AI — without spending days configuring everything.

NeoTUI gives you a complete coding environment in one command: Neovim with LSP and AI autocompletion, a file explorer sidebar, tabbed windows, smart shell integration, and an AI coding assistant — all pre-configured and ready to go.

## Who is this for?

- Developers who want a **terminal-based IDE** that works immediately
- Anyone curious about **AI-assisted coding** in the terminal (Codeium + opencode)
- Vim/Neovim users who want a **batteries-included** setup without hours of config
- Developers on **remote servers or WSL2** where GUI editors aren't ideal

## Quick Start

```bash
# Clone the project
git clone https://github.com/YOUR_USERNAME/neotui.git
cd neotui

# Install everything (no root required for most tools)
./install.sh

# Start a zsh shell to pick up the new config
zsh

# Launch NeoTUI
neotui
```

On first launch, Neovim will auto-install plugins and language servers — give it a minute.

## Setting Up AI Autocompletion

NeoTUI comes with **Codeium** (by Windsurf) for free AI code suggestions — multi-line ghost text that appears as you type, similar to Cursor or Copilot.

1. Create a free account at [windsurf.com](https://windsurf.com)
2. Open Neovim: `nvim`
3. Run: `:Codeium Auth`
4. Sign in via browser, copy the token, paste it back into Neovim
5. Done — AI suggestions appear as faded blue ghost text as you type

**Tab** accepts the full suggestion. **Alt+w** accepts just the next word. **Alt+l** accepts just the next line.

## What Gets Installed

| Tool | Purpose |
|------|---------|
| **Neovim** | Editor with LSP, AI completion, treesitter syntax |
| **Codeium** | Free AI autocompletion (ghost text, like Cursor) |
| **opencode** | AI coding assistant (chat-based, in a split pane) |
| **lf** | Terminal file manager (interactive sidebar) |
| **zsh** | Shell with vi-mode, autosuggestions, syntax highlighting |
| **fzf** | Fuzzy finder (history, files, directories) |
| **ripgrep** | Fast code search |
| **fd** | Fast file finder |
| **bat** | Syntax-highlighted file viewer |
| **eza** | Modern `ls` replacement with icons |
| **glow** | Render Markdown beautifully in the terminal |
| **carapace** | Shell completion engine (1400+ commands) |

All tools install to `~/.local/bin` (no root required).

## What It Looks Like

```
┌──────────────────────────────────────────────────────────────┐
│  Tab Bar (tmux)              [main] [shell] [opencode]       │
├──────────────┬───────────────────────────────────────────────┤
│              │                                               │
│  lf sidebar  │  Main pane                                    │
│  (files)     │  (Neovim / shell / opencode)                  │
│              │                                               │
│  Syncs with  │  Neovim: LSP + AI ghost text completion       │
│  your shell  │  Zsh: vi-mode + autosuggestions               │
│  directory   │                                               │
│              │                                               │
├──────────────┴───────────────────────────────────────────────┤
│  Statusline (lualine)          branch  diagnostics  filetype │
└──────────────────────────────────────────────────────────────┘
```

## Key Bindings

Run `neotui -h` for the full reference. Here are the essentials:

### tmux (prefix: Ctrl+b)

| Key | Action |
|-----|--------|
| `prefix, c` | New window (with file explorer) |
| `prefix, E` | Toggle file explorer sidebar |
| `prefix, T` | Toggle tab bar |
| `prefix, O` | Open AI assistant (opencode) |
| `prefix, v` | Open Neovim |
| `prefix, h/j/k/l` | Navigate panes |
| `prefix, n/p` | Next / previous window |

### Neovim (leader: Space)

| Key | Action |
|-----|--------|
| `Space ff` | Find files |
| `Space fg` | Live grep (search text) |
| `gd` | Go to definition |
| `gr` | Find references |
| `K` | Hover docs |
| `Space rn` | Rename symbol |
| `Space ca` | Code action |
| `Space w` | Save |
| `Tab` | Accept AI suggestion |
| `Ctrl+Space` | Open LSP completion menu |

### lf (file explorer)

| Key | Action |
|-----|--------|
| `Enter` | Open file in Neovim |
| `Shift+Enter` | Open in new tab |
| `dd` | Trash file |
| `md / mf` | Create directory / file |
| `zp` | Toggle preview pane |

## LSP Support

Language servers auto-install on first Neovim launch via mason.nvim:

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
neotui/
├── install.sh                 # One-command installer
├── README.md
├── tmux/
│   └── tmux.conf              # Tab bar, panes, keybinds
├── nvim/
│   ├── init.lua               # Neovim entry point
│   └── lua/
│       ├── core/              # Options, keymaps, autocmds
│       └── plugins/           # LSP, completion, AI, UI, etc.
├── lf/
│   ├── lfrc                   # File explorer config
│   └── preview.sh             # File previewer
├── shell/
│   ├── env.sh                 # PATH, zsh options, fzf, carapace
│   ├── vi-mode.sh             # Vi-mode, prompt theme
│   ├── hooks.sh               # Bidirectional lf <-> shell sync
│   └── aliases.sh             # Shell aliases
└── bin/
    ├── neotui                 # Main launcher
    ├── neotui-toggle-sidebar  # Sidebar toggle
    └── neotui-new-window      # New window with sidebar
```

## Configuration

All config lives in this repo. The installer creates symlinks:

- `tmux/tmux.conf` -> `~/.tmux.conf`
- `nvim/` -> `~/.config/nvim/`
- `lf/` -> `~/.config/lf/`
- Shell scripts sourced from `~/.zshrc`

Edit files in the repo and changes take effect immediately (tmux: `prefix, r` to reload; Neovim: restart).

## WSL2 Notes

- **Nerd Font**: Install on the Windows side. Download [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads), then set it in Windows Terminal (Settings > Profiles > Appearance > Font Face).
- **Clipboard**: Yank in Neovim copies to Windows clipboard via `clip.exe`. Paste from Windows works too.
- **True Color**: Works automatically with Windows Terminal.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Neovim plugins not installing | Run `:Lazy sync` in Neovim |
| LSP servers not found | Run `:Mason` to check, `:MasonInstall <server>` to install |
| Icons look broken | Install a Nerd Font and set it in your terminal |
| AI completions not working | Run `:Codeium Auth` to sign in, `:Codeium Toggle` to enable |
| Tab bar disappeared | Press `Ctrl+b, T` to toggle it back |
| `neotui` command not found | Run `source ~/.zshrc` or start a new shell |

## License

MIT
