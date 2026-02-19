# ============================================================
# NeoTUI - Shell Hooks (zsh)
# Flushes stray terminal escape sequences on tmux attach
# ============================================================

# Discard any pending terminal responses (e.g., Device Attributes)
# that may have leaked through during tmux attach
if [[ -n "${TMUX:-}" ]]; then
    while read -t 0.01 -k 1 2>/dev/null; do :; done
fi
