# NeoTUI

A modern, out-of-the-box terminal. Includes Neovim with LSP and AI autocompletion, a file explorer sidebar, tabbed windows, smart shell integration, and Claude/OpenCode.

## Who is this for?

- Anyone curious about **AI-assisted coding** in the terminal (Codeium + opencode)
- Vim/Neovim users who want a **batteries-included** setup without hours of config
- Developers on **remote servers or WSL2** where GUI editors aren't ideal

## Quick Start

```bash
# Clone the project
git clone https://github.com/YOUR_USERNAME/neotui.git
cd neotui

# Install everything
./install.sh

# Launch NeoTUI
neotui
```

On first launch, Neovim will auto-install plugins and language servers — give it a minute.

## How It Works

The installer optionally offers to integrate NeoTUI features into your global configs (`~/.tmux.conf`, `~/.zshrc`, `~/.config/nvim/`, `~/.config/lf/`). It asks about each change individually and checks for keybind conflicts before making any modifications.

## Installer Options

```bash
./install.sh                    # Interactive installation
./install.sh --skip-unsupported # Skip tools unavailable for your architecture
./install.sh --yes              # Accept all defaults (scripted/CI use)
```

### Supported Architectures

| Architecture | Status |
|-------------|--------|
| x86_64 | Full support |
| ARM64 (aarch64) | Full support |
| ARMv7 | Most tools supported |

## Setting Up AI Autocompletion

NeoTUI comes with **Codeium** (by Windsurf) for free AI code suggestions — multi-line ghost text that appears as you type, similar to Cursor or Copilot.

1. Create a free account at [windsurf.com](https://windsurf.com)
2. Open Neovim inside a neotui session
3. Run: `:Codeium Auth`
4. Sign in via browser, copy the token, paste it back into Neovim
5. Done — AI suggestions appear as faded blue ghost text as you type

## What Gets Installed

| Tool | Purpose |
|------|---------|
| **Neovim** | Editor with LSP, AI completion, treesitter syntax |
| **Codeium** | Free AI autocompletion (ghost text, like Cursor) |
| **opencode** | AI coding assistant (chat-based, in a split pane) |
| **lf** | Terminal file manager (interactive sidebar) |
| **zsh** | Shell (with vi-mode inside NeoTUI sessions) |
| **fzf** | Fuzzy finder (history, files, directories) |
| **ripgrep** | Fast code search |
| **fd** | Fast file finder |
| **bat** | Syntax-highlighted file viewer |
| **eza** | Modern `ls` replacement with icons |
| **carapace** | Shell completion engine (1400+ commands) |

All tools install to `~/.local/bin` (no root required for most tools).

## What It Looks Like

```
┌──────────────────────────────────────────────────────────────┐
│  Tab Bar (tmux)              [main] [shell] [opencode]       │
├──────────────┬───────────────────────────────────────────────┤
│              │                                               │
│  lf sidebar  │  Main pane                                    │
│  (files)     │  (Neovim / shell / opencode)                  │
│              │                                               │
│              │  Neovim: LSP + AI ghost text completion       │
│              │  Zsh: vi-mode + autosuggestions               │
│              │                                               │
│              │                                               │
├──────────────┴───────────────────────────────────────────────┤
│  Statusline (lualine)          branch  diagnostics  filetype │
└──────────────────────────────────────────────────────────────┘
```

## NeoTUI Key Bindings

Run `neotui -h` for the full reference. These are the NeoTUI-specific defaults:

### tmux (prefix: Ctrl+b)

| Key | Action |
|-----|--------|
| `prefix, E` | Toggle file explorer sidebar |
| `prefix, T` | Toggle tab bar |
| `prefix, v` | Open Neovim in current directory |
| `prefix, O` | Open opencode (split below) |
| `prefix, C` | Open Claude Code (split below) |
| `prefix, c` | New window with lf sidebar |

### lf (file explorer)

| Key | Action |
|-----|--------|
| `S` | Sync shell pane to lf's directory |
| `Enter / o` | Open file in Neovim (via tmux) |
| `Shift+Enter / O` | Open file in new tmux tab |
| `zp` | Toggle preview pane |
| `dd` | Trash file |
| `dD` | Delete permanently |
| `md / mf` | Create directory / file |
| `yy / pp` | Copy / paste file |
| `yp` | Copy file path to clipboard |
| `gh` | Go to ~ |

### Neovim (leader: Space)

| Key | Action |
|-----|--------|
| `Space f` | Format file (prettier) |
| `Space F` | Toggle format-on-save (off by default) |
| `Tab` | Accept AI ghost text suggestion |
| `Alt+w` | Accept next word of AI suggestion |
| `Alt+l` | Accept next line of AI suggestion |
| `Alt+] / [` | Cycle AI suggestions |
| `Ctrl+e` | Dismiss AI suggestion |

### Shell

| Command | Action |
|---------|--------|
| `sync` | Sync lf sidebar to shell's current directory |

Other keybinds (vi-mode, pane navigation, aliases, etc.) depend on your global config. The installer can optionally add these to your configs.

## LSP Support

Language servers are selected during installation and auto-install on first Neovim launch via mason.nvim:

| Language | Server |
|----------|--------|
| Go | gopls |
| Python | pyright |
| TypeScript/JS | ts_ls |
| Bash/Shell | bashls |
| C/C++ | clangd |
| Lua | lua_ls |
| PHP | intelephense |

## File Structure

```
neotui/
├── install.sh                 # Interactive installer
├── README.md
├── AGENTS.md
├── tmux/
│   └── tmux.conf              # Tab bar, panes, keybinds (used inside neotui sessions)
├── nvim/
│   ├── init.lua               # Neovim entry point
│   └── lua/
│       ├── core/              # Options, keymaps, autocmds
│       └── plugins/           # LSP, completion, AI, UI, etc.
├── lf/
│   ├── lfrc                   # File explorer config
│   └── preview.sh             # File previewer
├── shell/
│   ├── .zshrc                 # ZDOTDIR wrapper (sources user's .zshrc then NeoTUI)
│   ├── env.sh                 # PATH, zsh options, fzf, carapace
│   ├── vi-mode.sh             # Vi-mode, prompt theme
│   ├── hooks.sh               # Escape sequence flushing
│   └── aliases.sh             # Shell aliases
└── bin/
    ├── neotui                 # Main launcher
    ├── neotui-toggle-sidebar  # Sidebar toggle
    └── neotui-new-window      # New window with sidebar
```

## WSL2 Notes

- **Nerd Font**: Install on the Windows side. Download [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads), then set it in Windows Terminal (Settings > Profiles > Appearance > Font Face).
- **Clipboard**: Yank in Neovim copies to Windows clipboard via `clip.exe`. Paste from Windows works too.
- **True Color**: Works automatically with Windows Terminal.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Neovim plugins not installing | Run `:Lazy sync` inside a neotui session |
| LSP servers not found | Run `:Mason` to check, `:MasonInstall <server>` to install |
| Icons look broken | Install a Nerd Font and set it in your terminal |
| AI completions not working | Run `:Codeium Auth` to sign in, `:Codeium Toggle` to enable |
| Tab bar disappeared | Press `Ctrl+b, T` to toggle it back |
| `neotui` command not found | Ensure `~/.local/bin` is in your PATH |

## License

MIT
