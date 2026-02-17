# AGENTS.md

This file provides guidance to OpenCode when working with code in this repository.

## Project Overview

NeoTUI is a terminal IDE configuration that bundles Neovim (with LSP + Codeium AI completion), tmux, lf file manager, and zsh into a single `neotui` command. The installer (`install.sh`) downloads pre-built binaries to `~/.local/bin` and symlinks config files to their standard locations.

## Commands

```bash
# Install/update everything
./install.sh
./install.sh --skip-unsupported   # skip tools without binaries for current arch

# Validate configs
shellcheck install.sh bin/neotui bin/neotui-* shell/*.sh
nvim --headless -c 'q'                                    # verify Neovim loads
nvim --headless -c 'lua dofile("nvim/init.lua")' -c 'q'   # Lua syntax check

# After plugin changes
nvim -c 'Lazy sync'

# Reload tmux config (or prefix, r inside tmux)
tmux source-file ~/.tmux.conf

# Launch the environment
neotui
```

There is no formal test suite. Validation is done via shellcheck and headless Neovim checks.

## Architecture

### Config symlink targets

| Repo path | Installed to |
|-----------|-------------|
| `nvim/` | `~/.config/nvim/` |
| `tmux/tmux.conf` | `~/.tmux.conf` |
| `lf/` | `~/.config/lf/` |
| `shell/*.sh` | sourced from `~/.zshrc` |
| `bin/*` | `~/.local/bin/` |

### Neovim (`nvim/`)

Uses lazy.nvim as plugin manager. `init.lua` sets leader to Space, loads `lua/core/` modules, then auto-discovers plugin specs from `lua/plugins/*.lua`.

- `lua/core/options.lua` — global vim options
- `lua/core/keymaps.lua` — editor keybindings (all use `desc` for which-key)
- `lua/core/autocmds.lua` — autocommands including filetype-specific indentation
- `lua/plugins/*.lua` — one file per plugin concern (ui, lsp, cmp, codeium, telescope, treesitter, formatting)

Each plugin file returns a lazy.nvim spec table. Use lazy loading (`event`, `cmd`, `keys`) whenever possible.

### Shell (`shell/`)

Four files sourced by zsh in order:
- `env.sh` — PATH, zsh options, fzf/carapace setup, DA response flushing
- `vi-mode.sh` — vi-mode keybindings, cursor shapes, prompt theme
- `hooks.sh` — chpwd hook that writes PWD to `~/.local/share/neotui/shell-pwd` for lf sync
- `aliases.sh` — aliases and utility functions

### lf-shell sync

lf and zsh share state via `~/.local/share/neotui/shell-pwd`. The shell writes its PWD there on every directory change (hooks.sh). lf reads it on its `on-cd` event to show a `[WD]` indicator. The `sync-shell` lf command finds an idle shell pane and cd's it to match lf's directory.

### Installer (`install.sh`)

Uses a generic `install_from_github()` helper to download releases. Supports x86_64, ARM64, and ARMv7. Targets glibc 2.17+ and prefers musl-static builds when available.

## Code Style

### Lua (Neovim)
- 2-space indent, one item per line in tables
- Section headers: `-- ─── Section Name ────────────────────────────────`
- Localize frequently-used functions at file top: `local map = vim.keymap.set`
- All keymaps must include `desc`
- Merge options with `vim.tbl_extend("force", base, additions)`
- Comments explain *why*, not just *what*

### Bash/Shell
- `#!/usr/bin/env bash` with `set -euo pipefail`
- `local` for function scope, UPPERCASE for constants, quote all expansions
- Prefer `[[ ]]` for conditionals, `(( ))` for arithmetic, `$()` for command substitution
- Color constants defined at top (`RED`, `GREEN`, etc.), used with `echo -e`
- Color output helpers (`info`, `success`, `warn`, `error`) defined near top
- Error handling: `|| true` for allowed failures, `return 1` on error
- Section headers: `# ─── Section Name ────────────────────────────────`

### tmux/lf
- Comments use `#`, same section header style as bash
- lf async commands use `cmd name &{{ }}`

## Key Conventions

- **Theme:** Catppuccin Mocha everywhere (Neovim, tmux, fzf)
- **Leader keys:** Neovim = Space, tmux prefix = Ctrl+b
- **Indentation:** 4 spaces default; 2 spaces for JS/TS/JSON/YAML/HTML/CSS/Lua; tabs for Go
- **Line length:** soft limit at 100 characters (`colorcolumn`)
- **Clipboard:** conditional setup for WSL2 (clip.exe), Wayland (wl-copy), X11 (xclip)
- **Portability:** avoid distro-specific package dependencies; prefer pre-built binaries

## Common Tasks

**Add a Neovim plugin:** Create `nvim/lua/plugins/<name>.lua`, return a lazy.nvim spec table with lazy loading, run `:Lazy sync`

**Add a shell alias:** Edit `shell/aliases.sh`, follow existing patterns

**Modify tmux keybinds:** Edit `tmux/tmux.conf`, reload with `prefix, r`

**Change Neovim options:** `nvim/lua/core/options.lua` for global, `nvim/lua/core/autocmds.lua` for filetype-specific

## Documentation Sync

When changing user-facing features, keep these three in sync:
1. `README.md` — feature lists, keybindings, setup instructions
2. `bin/neotui` (`show_help` function) — runtime `--help` output
3. The actual config files
