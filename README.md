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
- enables tmux top status bar with tab navigation
- sets zsh as the default shell inside NeoTUI tmux panes
- enables tmux pane navigation hotkeys (`<prefix> h/j/k/l`)
- enables tmux pane split hotkeys (`<prefix>+|` and `<prefix>+-`)
- enables tmux pane resize hotkeys (`<prefix>+H/J/K/L`)
- enables tmux `<prefix>+E` to toggle the lf sidebar
- opens lf as a left sidebar by default on new `neotui` sessions
- enables lf auto-refresh on file create/delete changes (`watch` + `period 2` fallback)
- enables lf keybinds: `gh` (home), `gz` (toggle file preview), `gs` (sync to zsh dir)
- enables lf queue flow: `yy`/`yY` (toggle copy/cut), `p`/`P` (execute; copy queue persists), `yq` (status), `c` (clear)
- enables lf file-operation hotkeys: `md` (mkdir), `mf` (touch), `dd` (safe trash)
- enables lf undo/redo hotkeys: `gu`/`gr` (session-scoped)
- deleted files are recoverable only during the current NeoTUI tmux session
- enables zsh helper: `lfsync` (sync to lf directory)

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

Tmux defaults:
- top status bar with tab-style window list
- use `Shift+Left` / `Shift+Right` (or `Alt+Left` / `Alt+Right`) to switch tabs
- zsh is the default shell inside NeoTUI tmux panes
- pane navigation with `<prefix> h/j/k/l`
- pane splitting with `<prefix>+|` and `<prefix>+-`
- pane resizing with `<prefix>+H/J/K/L`
- lf sidebar toggle with `<prefix>+E`

Lf defaults:
- lf opens by default as a left sidebar on new `neotui` sessions
- lf auto-refreshes on file create/delete changes (`watch` + `period 2` fallback)
- file preview is off by default
- `gh` jumps to home directory
- `gz` toggles file preview (off <-> `2:3` preview)
- `gs` syncs lf to the current zsh pane directory (same tmux window)
- `yy`/`yY` toggle queueing current item for copy/cut
- queued marker in left indicator lane: `y` for copy, `Y` for cut
- `p` executes queued copy items and keeps copy queue, `P` executes queued cut items and clears cut queue
- `yq` shows queue status and `c` clears all queues
- `md` creates a directory, `mf` creates a file
- `dd` moves selected/current file or directory to NeoTUI trash with confirmation
- `gu` undoes and `gr` redoes the last create, paste, or delete action
- lf undo/redo and trash are scoped to the current NeoTUI tmux session

Zsh defaults:
- NeoTUI uses installed runtime zsh config in `~/.local/share/neotui/config/shell/`
- prompt matches the previous main-branch NeoTUI style (`[HH:MM] ~/path (git-branch) >`)
- `lfsync` changes zsh cwd to the lf pane directory (same tmux window)

## Development checks

Pre-commit uses husky and runs strict shell checks.

```bash
npm install
shellcheck --version
npm run check:shell
```
