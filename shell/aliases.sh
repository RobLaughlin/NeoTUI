# ============================================================
# NeoTUI - Aliases
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

# ─── Markdown ────────────────────────────────────────────────
# mdpreview: GitHub-style markdown preview in browser
if command -v go-grip &>/dev/null; then
    mdpreview() { go-grip "$@"; }
fi

# ─── lf Sync ─────────────────────────────────────────────────
# sync: tell lf sidebar to navigate to the shell's current directory
sync() {
    if [[ -n "${TMUX:-}" ]] && command -v lf &>/dev/null; then
        lf -remote "send :cd '$PWD'; on-cd" 2>/dev/null && echo "lf → $PWD"
    else
        echo "Not in a tmux session or lf not installed"
    fi
}

# ─── Misc ────────────────────────────────────────────────────
alias cls='clear'
alias reload='source ~/.zshrc'
alias path='echo $PATH | tr ":" "\n"'
