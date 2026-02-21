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

lfsync() {
  if [[ -z "${TMUX:-}" ]]; then
    echo "Not in a tmux session"
    return 1
  fi

  local window_id
  window_id="$(tmux display-message -p '#{window_id}')"

  local target_pane
  target_pane="$({
    tmux list-panes -t "$window_id" -F '#{pane_id} #{pane_current_command} #{pane_last}'
  } | awk -v current="${TMUX_PANE:-}" '$2 == "lf" && $1 != current { if ($3 == "1") { print $1; found=1; exit } if (first == "") first=$1 } END { if (!found && first != "") print first }')"

  if [[ -z "$target_pane" ]]; then
    echo "No lf pane found in this window"
    return 1
  fi

  local target_dir
  target_dir="$(tmux display-message -t "$target_pane" -p '#{pane_current_path}')"
  if [[ -z "$target_dir" ]]; then
    echo "Could not read lf pane directory"
    return 1
  fi

  builtin cd -- "$target_dir" || return 1
  echo "zsh -> $target_dir"
}

alias cls='clear'
alias reload='source "$ZDOTDIR/.zshrc"'
alias path='echo $PATH | tr ":" "\n"'
