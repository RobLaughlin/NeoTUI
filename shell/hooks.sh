# ============================================================
# NeoTUI - Shell Hooks (zsh)
# Writes shell PWD to state file so lf can show [WD] indicator
# ============================================================

__neotui_state_dir="$HOME/.local/share/neotui"

__neotui_write_pwd() {
    [[ -z "${TMUX:-}" ]] && return
    mkdir -p "$__neotui_state_dir"
    printf '%s' "$PWD" > "$__neotui_state_dir/shell-pwd"

    # Refresh lf's [WD] indicator (doesn't navigate, just updates the prompt)
    if command -v lf &>/dev/null; then
        lf -remote "send on-cd" 2>/dev/null || true
    fi
}

# Fire on every directory change
autoload -Uz add-zsh-hook
add-zsh-hook chpwd __neotui_write_pwd

# Write initial PWD on shell startup
if [[ -n "${TMUX:-}" ]]; then
    mkdir -p "$__neotui_state_dir"
    printf '%s' "$PWD" > "$__neotui_state_dir/shell-pwd"
fi
