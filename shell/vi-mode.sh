# ============================================================
# NeoTUI - Zsh Vi-Mode & Prompt
# ============================================================

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

# ─── Prompt (Neon Blue Theme) ───────────────────────────────
# Colors:
#   51  = neon cyan/blue (username, hostname, prompt symbol)
#   39  = deep sky blue  (current directory)
#   45  = turquoise      (git branch)
#   243 = gray           (time, separators)

autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats ' (%b)'
zstyle ':vcs_info:*' enable git

_neotui_precmd_vcs() { vcs_info }
add-zsh-hook precmd _neotui_precmd_vcs

setopt PROMPT_SUBST

# [14:30] ~/path (branch) >
PROMPT='%F{243}[%D{%H:%M}]%f %F{39}%~%f%F{45}${vcs_info_msg_0_}%f %(?.%F{51}.%F{red})>%f '
