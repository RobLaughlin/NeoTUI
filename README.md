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

## Usage

```bash
neotui
```

Subcommands:
- `neotui tmux` (default)
- `neotui zsh`
- `neotui nvim [args...]`
- `neotui lf`

## Development checks

Pre-commit uses husky and runs strict shell checks.

```bash
npm install
shellcheck --version
npm run check:shell
```
