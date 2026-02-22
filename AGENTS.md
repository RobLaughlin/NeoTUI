# NeoTUI Refactor Notes

NeoTUI is now intentionally minimal.

Primary goal:
- deliver a local-first TUI setup that works out of the box with minimal moving parts.

Core scope:
- tmux
- zsh
- lf
- neovim

Refactor principles:
- keep defaults stable and predictable
- prefer small scripts over complex abstractions
- avoid optional integrations in the initial baseline
- keep installer behavior explicit and easy to audit
- keep NeoTUI default templates in this repo, and install active runtime configs under `~/.local/share/neotui/config`
- only install a global `neotui` command; do not modify global dotfiles
- when asked to update configs in `~/projects/NeoTUI`, update NeoTUI-managed configs in this repo, not global configs like `~/.zshrc`
- enforce runtime minimums from `REQUIREMENTS.txt`
- when installer defaults change, update both `README.md` and `install-local.sh` install messaging so users are informed during installation
- when NeoTUI hotkeys/default bindings change, update `neotui --help` / `neotui -h` output to reflect the new defaults
- when the NeoTUI runtime directory layout changes, update the runtime directory tree documented in `README.md`

Quality gates:
- all shell scripts must pass syntax checks
- all shell scripts must pass shellcheck lints
- pre-commit enforces these checks via husky
