# NeoTUI (Stable Refactor)

NeoTUI is a minimal local-first TUI that runs in isolation from global dotfiles.

Core scope:
- tmux
- zsh
- lf
- neovim

## Isolation model

- NeoTUI config sources live only in this repo (`tmux/`, `shell/`, `lf/`, `nvim/`).
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

This creates a symlink for `neotui` in `~/.local/bin/neotui`.

Installer behavior:
- checks installed versions against `REQUIREMENTS.txt`
- prompts before installing/upgrading missing or outdated tools
- prefers distro package manager installs
- falls back to upstream binaries for `nvim` and `lf` when distro packages are unavailable or below minimum
- prints applied NeoTUI defaults during install so users know what is being enabled

Default setup applied at install time:
- enables tmux top status bar with tab navigation
- sets zsh as the default shell inside NeoTUI tmux panes
- enables tmux pane navigation hotkeys (`<prefix> h/j/k/l`)
- enables tmux pane split hotkeys (`<prefix>+|` and `<prefix>+-`)
- enables tmux pane resize hotkeys (`<prefix>+H/J/K/L`)
- enables tmux `<prefix>+E` to toggle the lf sidebar
- opens lf as a left sidebar by default on new `neotui` sessions
- enables lf keybinds: `gh` (home), `gz` (toggle file preview)

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
- file preview is off by default
- `gh` jumps to home directory
- `gz` toggles file preview (off <-> `2:3` preview)

Zsh defaults:
- NeoTUI uses repo-scoped zsh config in `shell/`
- prompt matches the previous main-branch NeoTUI style (`[HH:MM] ~/path (git-branch) >`)

## Development checks

Pre-commit uses husky and runs strict shell checks.

```bash
npm install
shellcheck --version
npm run check:shell
```
