export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"

export PATH="$HOME/.local/bin:$PATH"

export GOPATH="${GOPATH:-$HOME/go}"
if [[ -d "$HOME/.local/go/bin" ]]; then
  export PATH="$HOME/.local/go/bin:$GOPATH/bin:$PATH"
elif [[ -d "/usr/local/go/bin" ]]; then
  export PATH="/usr/local/go/bin:$GOPATH/bin:$PATH"
else
  export PATH="$GOPATH/bin:$PATH"
fi

setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt APPEND_HISTORY

autoload -Uz compinit
compinit -C

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "$LS_COLORS"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches --%f'

if [[ -d "$HOME/.fzf" ]]; then
  export PATH="$HOME/.fzf/bin:$PATH"
  if [[ -o interactive ]] && [[ -t 0 ]]; then
    [[ -f "$HOME/.fzf/shell/completion.zsh" ]] && source "$HOME/.fzf/shell/completion.zsh"
    [[ -f "$HOME/.fzf/shell/key-bindings.zsh" ]] && source "$HOME/.fzf/shell/key-bindings.zsh"
  fi
fi

export FZF_DEFAULT_OPTS=" \
  --height 40% --layout=reverse --border --info=inline \
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

if [[ -o interactive ]] && [[ -t 0 ]] && command -v carapace >/dev/null 2>&1; then
  source <(carapace _carapace zsh)
fi

if command -v bat >/dev/null 2>&1; then
  export BAT_THEME="base16"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
