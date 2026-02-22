# NeoTUI (Stable Refactor)

NeoTUI is a minimal local-first TUI that runs in isolation from global dotfiles.

Core scope:
- tmux
- zsh
- lf
- neovim

## Isolation model

- This repo provides NeoTUI default templates (`tmux/`, `shell/`, `lf/`, `nvim/`).
- Installer copies defaults into NeoTUI runtime home at `~/.local/share/neotui/config/`.
- Installed runtime configs are the active source of truth for NeoTUI.
- The installer only adds one global command: `neotui`.
- NeoTUI does not write to `~/.tmux.conf`, `~/.zshrc`, `~/.config/nvim`, or other global configs.

## Requirements

- bash
- git
- tmux
- zsh
- lf
- neovim

Runtime minimums are defined in `REQUIREMENTS.txt`:
- `tmux>=3.2a`
- `zsh>=5.8`
- `lf>=31`
- `nvim>=0.11.0`

## Local install

```bash
./install-local.sh
```

This creates a symlink for `neotui` in `~/.local/bin/neotui` pointing to the installed runtime launcher in `~/.local/share/neotui/bin/neotui`.

Runtime directory tree:

```text
~/.local/share/neotui/
  bin/      # runtime launchers and helpers
  config/   # active NeoTUI configs (source of truth)
  data/     # app data (e.g. lf tags)
  state/    # session/runtime state (queues, trash, history)
  cache/    # cache files
  tools/    # NeoTUI-managed tool installs (e.g. upstream lf/nvim)
```

Installer behavior:
- checks installed versions against `REQUIREMENTS.txt`
- prompts before installing/upgrading missing or outdated tools
- prefers distro package manager installs
- falls back to upstream binaries for `nvim` and `lf` when distro packages are unavailable or below minimum
- installs NeoTUI runtime home at `~/.local/share/neotui`
- copies default configs from this repo into runtime config paths
- prompts per config file on reinstall when installed configs differ from repo defaults
- prints applied NeoTUI defaults during install so users know what is being enabled

Default setup applied at install time:

### Tmux

| Type | Value | Notes |
| --- | --- | --- |
| Feature | Top status bar with tab navigation | Enabled by default |
| Feature | zsh default shell in tmux panes | NeoTUI sessions |
| Keybind | `<prefix> h/j/k/l` | Pane navigation |
| Keybind | `<prefix>+|`, `<prefix>+-` | Pane split |
| Keybind | `<prefix>+H/J/K/L` | Pane resize |
| Keybind | `<prefix>+E` | Toggle lf sidebar |

### Zsh

| Type | Value | Notes |
| --- | --- | --- |
| Command | `lfsync` | Sync zsh cwd to lf pane path |
| Feature | `compinit` completion | Enabled by default |
| Feature | Autosuggestions + syntax highlighting | Enabled when plugins are installed |
| Feature | History reset prompt during install | Default answer is `No` |

### Lf

| Type | Value | Notes |
| --- | --- | --- |
| Feature | Left sidebar on new `neotui` session | Enabled by default |
| Feature | Auto-refresh (`watch` + `period 2`) | Create/delete updates |
| Keybind | `gh`, `gz`, `gs` | Home, preview toggle, sync to zsh dir |
| Keybind | `l`, `Enter` | Enter dir; file opens in nvim pane/new tmux window |
| Keybind | `yy`/`yY`, `p`/`P`, `yq`, `c` | Queue copy/cut flow |
| Keybind | `md`, `mf`, `dd`, `gu`/`gr` | File ops and undo/redo |
| Feature | `Space`/`v`/`u` mark keys disabled | Queue markers stay copy/cut-only |
| Feature | Delete recovery scope | Current NeoTUI tmux session only |

### Nvim

| Type | Value | Notes |
| --- | --- | --- |
| Keybind | `Ctrl+h` | Previous tab |
| Keybind | `Ctrl+l` | Next tab |
| Command | `:tabn`, `:tabp`, `:tabclose` | Tab navigation and close |

## Usage

```bash
neotui
```

Debug mode:

```bash
neotui --debug
```

This prints an isolation/debug report (tool paths, versions, and global config link status) before launching.
This command only prints debug information and exits.

Subcommands:
- `neotui tmux` (default)
- `neotui zsh`
- `neotui nvim [args...]`
- `neotui lf`

### Tmux defaults

| Type | Value | Notes |
| --- | --- | --- |
| Feature | Top status bar with tab-style window list | Enabled by default |
| Feature | zsh default shell in tmux panes | NeoTUI sessions |
| Keybind | `<prefix> h/j/k/l` | Pane navigation |
| Keybind | `<prefix>+|`, `<prefix>+-` | Pane split |
| Keybind | `<prefix>+H/J/K/L` | Pane resize |
| Keybind | `<prefix>+E` | Toggle lf sidebar |

### Zsh defaults

| Type | Value | Notes |
| --- | --- | --- |
| Feature | Runtime config path | `~/.local/share/neotui/config/shell/` |
| Feature | Prompt style | `[HH:MM] ~/path (git-branch) >` |
| Command | `lfsync` | Sync zsh cwd to lf pane path |
| Feature | `compinit` completion | Enabled by default |
| Feature | Autosuggestions + syntax highlighting | Enabled when plugins are installed |
| Feature | History file | `~/.local/share/neotui/state/zsh/history` |
| Feature | History reset prompt | Installer default is `No` |

### Lf defaults

| Type | Value | Notes |
| --- | --- | --- |
| Feature | Left sidebar on new `neotui` session | Enabled by default |
| Feature | Auto-refresh (`watch` + `period 2`) | Create/delete updates |
| Feature | File preview | Off by default (`gz` toggles) |
| Keybind | `gh`, `gz`, `gs` | Home, preview toggle, sync to zsh dir |
| Keybind | `l`, `Enter` | Enter dir; open files in nvim pane/new tmux window |
| Keybind | `yy`/`yY`, `p`/`P`, `yq`, `c` | Queue copy/cut flow |
| Keybind | `md`, `mf`, `dd`, `gu`/`gr` | File ops and undo/redo |
| Feature | Queue marker lane | `y` for copy, `Y` for cut |
| Feature | Default mark keys disabled | `Space`, `v`, `u` |
| Feature | Undo/redo + trash scope | Current NeoTUI tmux session only |

### Nvim defaults

| Type | Value | Notes |
| --- | --- | --- |
| Keybind | `Ctrl+h` | Previous tab |
| Keybind | `Ctrl+l` | Next tab |
| Command | `:tabn`, `:tabp`, `:tabclose` | Tab navigation and close |

## Development checks

Pre-commit uses husky and runs strict shell checks.

```bash
npm install
shellcheck --version
npm run check:shell
```
