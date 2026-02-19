# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

NeoTUI is a terminal IDE configuration that bundles Neovim (with LSP + Codeium AI completion), tmux, lf file manager, and zsh into a single `neotui` command. The `neotui` command is **self-contained** — it uses isolation mechanisms (`NVIM_APPNAME`, `ZDOTDIR`, `lf -config`, direct `tmux source-file`) so it works without modifying any user configs. The installer optionally offers to integrate NeoTUI features into the user's global configs.

## Config Philosophy

**NeoTUI must never silently modify user configs.** The following rules are strict:

1. **Self-contained by default.** The `neotui` command works fully without any changes to the user's `~/.tmux.conf`, `~/.config/nvim/`, `~/.config/lf/`, or `~/.zshrc`. It uses its own copies via isolation mechanisms.

2. **Ask and inform before every external config change.** The installer MUST ask the user before modifying any config file outside of NeoTUI-specific locations (`~/.config/neotui/`, `~/.local/bin/neotui*`, `~/.local/share/zsh/plugins/`). Each prompt must clearly describe what the change does.

3. **Marker blocks for all injected config.** Any content the installer adds to user config files (`~/.tmux.conf`, `~/.zshrc`, `~/.config/lf/lfrc`) must be wrapped in `# >>> neotui >>>` / `# <<< neotui <<<` marker blocks.

4. **Conflict detection.** Before offering keybinds, check for conflicts with the user's existing config. Notify the user of conflicts and preserve their existing bindings.

5. **Backup before overwrite.** If replacing an existing config (e.g., symlinking `~/.config/nvim/`), back it up first with a timestamped suffix.

6. **Documentation only covers NeoTUI-specific defaults.** `README.md` and `neotui --help` ONLY document keybinds and commands that NeoTUI provides by default (custom tmux binds, lf commands, formatting keybinds, the `sync` shell command). Generic vim/tmux/zsh features that are opt-in via the installer (vi-mode, aliases, pane navigation, etc.) are NOT documented in these places.

## Commands

```bash
# Install/update everything (remote)
curl -fsSL https://raw.githubusercontent.com/RobLaughlin/NeoTUI/main/install.sh | bash

# Install/update everything (local, after cloning)
./install-local.sh
./install-local.sh --skip-unsupported   # skip tools without binaries for current arch
./install-local.sh --yes                # accept all defaults (scripted/CI use)

# Validate configs
shellcheck install.sh install-local.sh bin/neotui bin/neotui-* shell/*.sh
nvim --headless -c 'q'                                    # verify Neovim loads
nvim --headless -c 'lua dofile("nvim/init.lua")' -c 'q'   # Lua syntax check

# After plugin changes
nvim -c 'Lazy sync'

# Reload tmux config inside a neotui session
tmux source-file "$NEOTUI_DIR/tmux/tmux.conf"

# Launch the environment
neotui
```

There is no formal test suite. Validation is done via shellcheck and headless Neovim checks.

## Architecture

### NeoTUI-specific locations (no user consent needed)

| Repo path | Installed to | Purpose |
|-----------|-------------|---------|
| `nvim/` | `~/.config/neotui/` (symlink) | Neovim config for `NVIM_APPNAME=neotui` |
| `bin/*` | `~/.local/bin/` | Launcher and helper scripts |
| `lf/preview.sh` | `~/.local/bin/neotui-lf-preview` | lf file previewer |

### User configs (require consent via installer Phase 4)

| Config | File | What the installer can add |
|--------|------|---------------------------|
| tmux | `~/.tmux.conf` | Keybinds, status bar, vi-mode, default shell |
| Neovim | `~/.config/nvim/` | Full NeoTUI config (only if no existing config) |
| lf | `~/.config/lf/lfrc` | Commands, navigation shortcuts |
| zsh | `~/.zshrc` | vi-mode, prompt, completion, plugins, PATH, EDITOR |

### Isolation mechanisms

| Tool | Mechanism | Effect |
|------|-----------|--------|
| tmux | `tmux source-file $NEOTUI_DIR/tmux/tmux.conf` | NeoTUI session uses its own tmux config |
| Neovim | `NVIM_APPNAME=neotui` | Neovim reads from `~/.config/neotui/` |
| lf | `lf -config $NEOTUI_DIR/lf/lfrc` | lf uses NeoTUI's lfrc |
| zsh | `ZDOTDIR=$NEOTUI_DIR/shell` | zsh reads `shell/.zshrc` wrapper |

### Neovim (`nvim/`)

Uses lazy.nvim as plugin manager. `init.lua` sets leader to Space, loads `lua/core/` modules, then auto-discovers plugin specs from `lua/plugins/*.lua`.

- `lua/core/options.lua` — global vim options
- `lua/core/keymaps.lua` — editor keybindings (all use `desc` for which-key)
- `lua/core/autocmds.lua` — autocommands including filetype-specific indentation
- `lua/plugins/*.lua` — one file per plugin concern (ui, lsp, cmp, codeium, telescope, treesitter, formatting, linting)

Each plugin file returns a lazy.nvim spec table. Use lazy loading (`event`, `cmd`, `keys`) whenever possible.

LSP server selection is read from `neotui_lsp_servers.lua` in the Neovim config directory (written by the installer). If absent, a default set is used.

### Shell (`shell/`)

Files sourced by zsh inside NeoTUI sessions (via `ZDOTDIR`):
- `.zshrc` — ZDOTDIR wrapper: sources user's `~/.zshrc` first, then NeoTUI shell scripts
- `env.sh` — PATH, zsh options, fzf/carapace setup
- `vi-mode.sh` — vi-mode keybindings, cursor shapes, prompt theme
- `hooks.sh` — escape sequence flushing on tmux attach
- `aliases.sh` — aliases and utility functions

### lf-shell sync

The `sync-shell` lf command (bound to `S`) finds an idle shell pane via tmux and cd's it to match lf's directory. The `sync` shell command does the reverse — tells lf to navigate to the shell's directory.

### Installer

- `install.sh` — Bootstrap script (curl | bash). Clones repo to `~/.local/share/neotui/repo` and runs `install-local.sh`
- `install-local.sh` — Main installer with four phases:
1. **Install tools** — downloads binaries to `~/.local/bin`
2. **NeoTUI core setup** — symlinks NeoTUI-specific files (no user config changes)
3. **LSP server selection** — asks which language servers to install
4. **Global config integration** — optional, prompted per-item, with conflict detection

Uses a generic `install_from_github()` helper to download releases. Supports x86_64, ARM64, and ARMv7.

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

- **Theme:** Catppuccin Mocha inside NeoTUI sessions (Neovim, tmux, fzf)
- **Leader keys:** Neovim = Space, tmux prefix = Ctrl+b
- **Indentation:** 4 spaces default; 2 spaces for JS/TS/JSON/YAML/HTML/CSS/Lua; tabs for Go
- **Line length:** soft limit at 100 characters (`colorcolumn`)
- **Clipboard:** conditional setup for WSL2 (clip.exe), Wayland (wl-copy), X11 (xclip)
- **Portability:** avoid distro-specific package dependencies; prefer pre-built binaries

## Common Tasks

**Add a Neovim plugin:** Create `nvim/lua/plugins/<name>.lua`, return a lazy.nvim spec table with lazy loading, run `:Lazy sync`

**Add a shell alias:** Edit `shell/aliases.sh` (applies inside NeoTUI sessions only)

**Modify tmux keybinds:** Edit `tmux/tmux.conf` (applies inside NeoTUI sessions only), reload with `prefix, r`

**Change Neovim options:** `nvim/lua/core/options.lua` for global, `nvim/lua/core/autocmds.lua` for filetype-specific

**Add a new installer prompt:** Add to Phase 4 in `install-local.sh`, use `ask_yes_no`, check for conflicts, wrap additions in marker blocks

## Documentation Sync

When changing user-facing features, keep these in sync:
1. `README.md` — NeoTUI-specific features, keybindings, setup instructions
2. `bin/neotui` (`show_help` function) — runtime `--help` output
3. The actual config files

**Critical rule:** Only document NeoTUI-specific defaults (custom tmux binds, lf commands, format keybinds, `sync` command). Do NOT document generic vim/tmux/zsh features in README or `--help`.
