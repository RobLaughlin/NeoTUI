# ============================================================
# NeoTUI - ZDOTDIR wrapper
# This file is sourced by zsh when ZDOTDIR points here
# (inside NeoTUI tmux sessions). It layers NeoTUI's shell
# integration on top of the user's existing config.
# ============================================================

# Load persistent history config if user opted in during install.
# This sets NEOTUI_HISTFILE, which we use to initialize HISTFILE
# before sourcing user config (so autosuggestions can see history
# from previous sessions).
_neotui_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/neotui"
if [[ -f "$_neotui_config_dir/history.conf" ]]; then
    source "$_neotui_config_dir/history.conf"
    [[ -n "${NEOTUI_HISTFILE:-}" ]] && : "${HISTFILE:=$NEOTUI_HISTFILE}"
fi
unset _neotui_config_dir

# Source the user's own .zshrc first so we layer on top, not replace.
# Temporarily reset ZDOTDIR so the user's .zshrc doesn't recurse back here.
if [[ -f "$HOME/.zshrc" ]]; then
    _neotui_zdotdir="$ZDOTDIR"
    unset ZDOTDIR
    source "$HOME/.zshrc"
    export ZDOTDIR="$_neotui_zdotdir"
    unset _neotui_zdotdir
fi

# Resolve NEOTUI_DIR from this file's location if not already set
export NEOTUI_DIR="${NEOTUI_DIR:-$(cd "$(dirname "${(%):-%N}")/.." && pwd)}"

# NeoTUI shell integration
export PATH="$HOME/.local/bin:$PATH"
source "$NEOTUI_DIR/shell/env.sh"
source "$NEOTUI_DIR/shell/vi-mode.sh"
source "$NEOTUI_DIR/shell/hooks.sh"
source "$NEOTUI_DIR/shell/aliases.sh"

# Plugins (syntax-highlighting must be sourced last)
[[ -f "$HOME/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \
    source "$HOME/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \
    source "$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
