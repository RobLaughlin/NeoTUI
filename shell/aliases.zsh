alias v='nvim'
alias vi='nvim'

alias python='python3'
alias py='python3'

if command -v eza >/dev/null 2>&1; then
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

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi

if command -v rg >/dev/null 2>&1; then
  alias grep='rg'
fi

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

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

if command -v go-grip >/dev/null 2>&1; then
  mdpreview() { go-grip "$@"; }
fi

sync() {
  if [[ -n "${TMUX:-}" ]] && command -v lf >/dev/null 2>&1; then
    lf -remote "send :cd '$PWD'; on-cd" 2>/dev/null && echo "lf -> $PWD"
  else
    echo "Not in a tmux session or lf not installed"
  fi
}

alias cls='clear'
alias reload='source "$ZDOTDIR/.zshrc"'
alias path='echo $PATH | tr ":" "\n"'
