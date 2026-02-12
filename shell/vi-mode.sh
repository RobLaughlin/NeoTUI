# ============================================================
# TUI Dev Environment - Zsh Vi-Mode & Prompt
# ============================================================

# ─── Flush stale terminal input ─────────────────────────────
# When tmux starts, the terminal sends Device Attributes responses
# (e.g. ESC[?61;4;...c) that arrive in zsh's input buffer.
# With vi-mode, ESC enters normal mode and the rest is interpreted
# as keystrokes, causing "failing fwd-i-search" errors.
# Fix: read and discard any pending input before zsh processes it.
if [[ -n "${TMUX:-}" ]]; then
    while read -t 0 -k 1 2>/dev/null; do :; done
fi

# Disable XON/XOFF flow control (Ctrl+S / Ctrl+Q) so stray
# characters can't accidentally trigger forward-search.
stty -ixon 2>/dev/null

# ─── Vi Mode ────────────────────────────────────────────────
bindkey -v
export KEYTIMEOUT=10  # 100ms - prevents terminal responses from leaking in

# ─── Cursor Shape Per Mode ──────────────────────────────────
# Beam cursor for insert mode, block for normal mode
function zle-keymap-select {
    if [[ ${KEYMAP} == vicmd ]] || [[ $1 == 'block' ]]; then
        echo -ne '\e[2 q'
    elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ $1 == 'beam' ]]; then
        echo -ne '\e[6 q'
    fi
}
zle -N zle-keymap-select

function zle-line-init {
    # Drain any stale terminal responses before accepting input
    while read -t 0 -k 1 2>/dev/null; do :; done
    echo -ne '\e[6 q'  # Start each prompt in insert mode with beam cursor
}
zle -N zle-line-init

# ─── Insert Mode Keybinds ───────────────────────────────────
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^W' backward-kill-word
bindkey '^K' kill-line
bindkey '^U' backward-kill-line
bindkey '^P' up-history
bindkey '^N' down-history
bindkey '^L' clear-screen
bindkey '^?' backward-delete-char   # Backspace
bindkey '^H' backward-delete-char   # Ctrl+H

# Normal mode: search with / and ?
bindkey -M vicmd '/' history-incremental-search-backward
bindkey -M vicmd '?' history-incremental-search-forward

# ─── Text Objects (vim-like) ────────────────────────────────
autoload -Uz select-bracketed select-quoted
zle -N select-quoted
zle -N select-bracketed

for km in viopp visual; do
    bindkey -M $km -- '-' vi-up-line-or-history
    for c in {a,i}${(s..)^:-\'\"\`\|,./:;=+@}; do
        bindkey -M $km $c select-quoted
    done
    for c in {a,i}${(s..)^:-'()[]{}<>bB'}; do
        bindkey -M $km $c select-bracketed
    done
done

# ─── Hook support ────────────────────────────────────────────
autoload -Uz add-zsh-hook

# ─── One-shot input flush before first prompt ───────────────
# Catches DA responses that arrive while config files were loading.
# Runs once, then removes itself.
_tui_flush_once() {
    while read -t 0 -k 1 2>/dev/null; do :; done
    add-zsh-hook -d precmd _tui_flush_once
}
add-zsh-hook precmd _tui_flush_once

# ─── Prompt (Neon Blue Theme) ───────────────────────────────
# Colors:
#   51  = neon cyan/blue (username, hostname, prompt symbol)
#   39  = deep sky blue  (current directory)
#   45  = turquoise      (git branch)
#   243 = gray           (time, separators)

autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats ' (%b)'
zstyle ':vcs_info:*' enable git

_tui_precmd_vcs() { vcs_info }
add-zsh-hook precmd _tui_precmd_vcs

setopt PROMPT_SUBST

# [14:30] ~/path (branch) >
PROMPT='%F{243}[%D{%H:%M}]%f %F{39}%~%f%F{45}${vcs_info_msg_0_}%f %(?.%F{51}.%F{red})>%f '
