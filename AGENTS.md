# AGENTS.md

Guidelines for AI coding agents working in this repository.

## Project Overview

NeoTUI is a terminal IDE configuration repository. It provides:
- Neovim configuration with LSP, AI completion (Codeium), and plugins
- tmux configuration for tab management and panes
- lf file manager configuration
- zsh shell configuration
- An installer script (`install.sh`) that sets up the full environment

## Build/Install Commands

```bash
# Install all dependencies and symlink configurations
./install.sh

# Install with skip flag for unsupported architectures
./install.sh --skip-unsupported

# Verify Neovim config loads without errors
nvim --headless -c 'q'

# Open Neovim and sync plugins (run after plugin changes)
nvim -c 'Lazy sync'

# Reload tmux config
tmux source-file ~/.tmux.conf
# Or within tmux: prefix, r

# Start the full environment
neotui
```

## Linting and Validation

```bash
# Check shell scripts with shellcheck (if installed)
shellcheck install.sh bin/neotui bin/neotui-* shell/*.sh

# Lua syntax check via Neovim
nvim --headless -c 'lua dofile("nvim/init.lua")' -c 'q'

# The lua-language-server (lua_ls) is auto-configured for this Neovim config
# and will provide real-time diagnostics when editing Lua files
```

## Code Style Guidelines

### Lua (Neovim Configuration)

```lua
-- ============================================================
-- Section/Module Name - Brief description
-- ============================================================
return {
  -- Plugin spec or configuration
}
```

- **Section headers:** Use Unicode: `-- ─── Section Name ────────────────────────────────`
- **Variables:** Localize at top: `local map = vim.keymap.set`
- **Plugin specs:** Return a table for lazy.nvim, use lazy loading (`event`, `cmd`, `keys`)
- **Keymaps:** Always include `desc` for which-key
- **Option merging:** Use `vim.tbl_extend("force", base, additions)`
- **Comments:** Explain *why*, not just *what*
- **Formatting:** 2-space indent, one item per line in tables

### Bash/Shell Scripts

```bash
#!/usr/bin/env bash
set -euo pipefail
# ─── Section Name ────────────────────────────────
```

- **Variables:** `local` for function scope, UPPERCASE for constants, quote all expansions
- **Conditionals:** Prefer `[[ ]]`, use `(( ))` for arithmetic
- **Functions:** Define helpers near top: `info()`, `success()`, `warn()`, `error()`
- **Colors:** Define at top: `RED='\033[0;31m'`, use with `echo -e "${GREEN}Success${NC}"`
- **Error handling:** Use `|| true` for allowed failures, `return 1` on error
- **Command substitution:** Prefer `$()` over backticks

### tmux and lf Configuration

- Comments use `#`, section headers same style as bash
- tmux key binds: `bind KEY command`
- lf commands: `cmd name {{ ... }}` or `cmd name &{{ ... }}` (async)

## File Organization

```
tui/
├── install.sh           # Main installer
├── bin/                 # Executable scripts (neotui launcher)
├── nvim/
│   ├── init.lua         # Entry point, sets leader, loads core/
│   └── lua/
│       ├── core/        # options, keymaps, autocmds
│       └── plugins/     # Plugin specs (one file per concern)
├── shell/               # zsh configuration files
├── tmux/                # tmux.conf
└── lf/                  # File manager config
```

## Key Conventions

1. **Leader Keys:** Neovim leader is `<Space>`, tmux prefix is `Ctrl+b`
2. **Color Scheme:** Catppuccin Mocha throughout (Neovim, tmux, fzf)
3. **Clipboard:** WSL2, Wayland, and X11 compatible via conditional setup
4. **Indentation:** 4 spaces default, 2 spaces for web languages (JS/TS/JSON/YAML/HTML/CSS/Lua), tabs for Go
5. **Line Length:** Soft limit ~100 characters (see `colorcolumn = "100"`)

## Common Tasks

**Add a Neovim plugin:** Create `nvim/lua/plugins/<name>.lua`, return a table with the plugin spec, include lazy-loading where possible, run `:Lazy sync`

**Add a shell alias:** Edit `shell/aliases.sh`, follow existing patterns

**Modify tmux keybinds:** Edit `tmux/tmux.conf`, reload with `prefix, r`

**Change Neovim options:** Edit `nvim/lua/core/options.lua` for global, or `nvim/lua/core/autocmds.lua` for filetype-specific

## Documentation Synchronization

When making changes that affect user-facing features, always update:

1. **README.md** - Keep feature lists, keybindings, and setup instructions current
2. **bin/neotui** (`show_help` function) - Update `-h`/`--help` output for keybinding changes

These three sources should stay in sync:
- README.md (documentation)
- bin/neotui help text (runtime reference)
- Actual config files (implementation)

## Portability Requirements

Target: General x86_64 modern Linux distributions (glibc 2.17+)

- Prefer pre-built binaries over source compilation
- Use musl-static builds when available for maximum compatibility
- Avoid distro-specific package dependencies in scripts
- Test on Ubuntu/Debian, Fedora, Arch if possible
- WSL2 compatibility is required (clipboard, paths)
