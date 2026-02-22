export NEOTUI_DIR="${NEOTUI_ROOT:-$(cd "$(dirname "${(%):-%N}")/../.." && pwd)}"

source "$NEOTUI_DIR/config/shell/env.zsh"
source "$NEOTUI_DIR/config/shell/vi-mode.zsh"
source "$NEOTUI_DIR/config/shell/hooks.zsh"
source "$NEOTUI_DIR/config/shell/aliases.zsh"
