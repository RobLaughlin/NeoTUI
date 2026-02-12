# ============================================================
# TUI Dev Environment - Aliases
# ============================================================

# ─── Editor ──────────────────────────────────────────────────
alias v='nvim'
alias vi='nvim'

# ─── Python ──────────────────────────────────────────────────
alias python='python3'
alias py='python3'

# ─── ls → eza ────────────────────────────────────────────────
if command -v eza &>/dev/null; then
    alias ls='eza --icons'
    alias ll='eza -la --icons --git'
    alias la='eza -a --icons'
    alias lt='eza --tree --icons --level=3'
    alias l='eza -l --icons'
else
    alias ll='ls -la --color=auto'
    alias la='ls -a --color=auto'
    alias l='ls -l --color=auto'
fi

# ─── bat → cat ───────────────────────────────────────────────
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
fi

# ─── ripgrep ─────────────────────────────────────────────────
if command -v rg &>/dev/null; then
    alias grep='rg'
fi

# ─── Git ─────────────────────────────────────────────────────
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate'
alias gp='git push'
alias gpl='git pull'
alias gb='git branch'
alias gco='git checkout'
alias gsw='git switch'

# ─── Navigation ──────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ─── Safety ──────────────────────────────────────────────────
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# ─── Misc ────────────────────────────────────────────────────
alias cls='clear'
alias reload='source ~/.bashrc'
alias path='echo $PATH | tr ":" "\n"'
