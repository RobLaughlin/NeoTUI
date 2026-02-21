export NEOTUI_DIR="${NEOTUI_ROOT:-$(cd "$(dirname "${(%):-%N}")/.." && pwd)}"

source "$NEOTUI_DIR/shell/env.zsh"
source "$NEOTUI_DIR/shell/vi-mode.zsh"
source "$NEOTUI_DIR/shell/hooks.zsh"
source "$NEOTUI_DIR/shell/aliases.zsh"
