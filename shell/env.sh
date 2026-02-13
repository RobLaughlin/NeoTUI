# ============================================================
# NeoTUI - Environment Setup (zsh)
# ============================================================

# ─── Flush stale terminal input (early) ─────────────────────
# tmux sends DA (Device Attributes) queries on startup; the
# terminal's response can land in zsh's input buffer and be
# misinterpreted as keystrokes ("failing fwd-i-search").
# Drain any pending bytes as early as possible.
if [[ -n "${TMUX:-}" ]]; then
    while read -t 0 -k 1 2>/dev/null; do :; done
fi

# ─── Editors ─────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"

# ─── Path ────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# Go (check ~/.local/go first, then system location)
export GOPATH="${GOPATH:-$HOME/go}"
if [[ -d "$HOME/.local/go/bin" ]]; then
    export PATH="$HOME/.local/go/bin:$GOPATH/bin:$PATH"
elif [[ -d "/usr/local/go/bin" ]]; then
    export PATH="/usr/local/go/bin:$GOPATH/bin:$PATH"
else
    export PATH="$GOPATH/bin:$PATH"
fi

# ─── Zsh Options ────────────────────────────────────────────
setopt AUTO_CD              # cd by typing directory name
setopt AUTO_PUSHD           # Push dirs onto stack
setopt PUSHD_IGNORE_DUPS    # No duplicate dirs in stack
setopt INTERACTIVE_COMMENTS # Allow comments in interactive shell
setopt NO_BEEP              # Silence

# ─── History ────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY        # Share history across sessions
setopt HIST_IGNORE_ALL_DUPS # Remove older duplicates
setopt HIST_FIND_NO_DUPS    # Don't show dups when searching
setopt HIST_REDUCE_BLANKS   # Remove extra whitespace
setopt HIST_VERIFY          # Confirm before executing from history
setopt APPEND_HISTORY       # Append, don't overwrite

# ─── Completion ─────────────────────────────────────────────
autoload -Uz compinit
compinit -C  # -C for faster startup via cache

zstyle ':completion:*' menu select                                 # Arrow-key menu
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'         # Case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"            # Colored results
zstyle ':completion:*' group-name ''                               # Group by type
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'  # Group headers
zstyle ':completion:*:warnings' format '%F{red}-- no matches --%f'

# ─── fzf ─────────────────────────────────────────────────────
if [[ -d "$HOME/.fzf" ]]; then
    export PATH="$HOME/.fzf/bin:$PATH"
    [[ -f "$HOME/.fzf/shell/completion.zsh" ]] && source "$HOME/.fzf/shell/completion.zsh"
    [[ -f "$HOME/.fzf/shell/key-bindings.zsh" ]] && source "$HOME/.fzf/shell/key-bindings.zsh"
fi

# fzf defaults (Catppuccin Mocha theme)
export FZF_DEFAULT_OPTS=" \
    --height 40% --layout=reverse --border --info=inline \
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

# ─── Carapace (shell completion engine) ──────────────────────
if command -v carapace &>/dev/null; then
    source <(carapace _carapace zsh)
fi

# ─── bat ─────────────────────────────────────────────────────
if command -v bat &>/dev/null; then
    export BAT_THEME="base16"
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
