# ============================================================
# NeoTUI - Shell Hooks (zsh)
# Bidirectional directory sync between shell and lf sidebar
# ============================================================

__neotui_state_dir="$HOME/.local/share/neotui"

__neotui_sync_sidebar() {
    # Only run inside tmux
    [[ -z "${TMUX:-}" ]] && return

    # Write current working directory to state file
    mkdir -p "$__neotui_state_dir"
    printf '%s' "$PWD" > "$__neotui_state_dir/shell-pwd"

    # Read lf's current directory to detect who initiated the change
    local lf_pwd=""
    [[ -f "$__neotui_state_dir/lf-pwd" ]] && lf_pwd="$(<"$__neotui_state_dir/lf-pwd")"

    if command -v lf &>/dev/null; then
        if [[ "$PWD" != "$lf_pwd" ]]; then
            # Shell initiated this cd — tell lf to follow
            lf -remote "send :cd '$PWD'; on-cd" 2>/dev/null || true
        else
            # lf initiated this cd (directories already match) —
            # just refresh the [WD] prompt indicator, don't send cd
            lf -remote "send on-cd" 2>/dev/null || true
        fi
    fi
}

# Use zsh's chpwd hook (fires on every directory change)
autoload -Uz add-zsh-hook
add-zsh-hook chpwd __neotui_sync_sidebar

# Write initial PWD on shell startup
if [[ -n "${TMUX:-}" ]]; then
    mkdir -p "$__neotui_state_dir"
    printf '%s' "$PWD" > "$__neotui_state_dir/shell-pwd"
    # Sync lf on startup too
    if command -v lf &>/dev/null; then
        lf -remote "send :cd '$PWD'; on-cd" 2>/dev/null || true
    fi
fi
