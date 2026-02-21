if [[ -o interactive ]] && [[ -t 0 ]]; then
  stty -ixon 2>/dev/null

  bindkey -v
  export KEYTIMEOUT=10

  zle-keymap-select() {
    if [[ ${KEYMAP} == vicmd ]] || [[ $1 == 'block' ]]; then
      echo -ne '\e[2 q'
    elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ $1 == 'beam' ]]; then
      echo -ne '\e[6 q'
    fi
  }
  zle -N zle-keymap-select

  zle-line-init() {
    echo -ne '\e[6 q'
  }
  zle -N zle-line-init

  bindkey '^A' beginning-of-line
  bindkey '^E' end-of-line
  bindkey '^W' backward-kill-word
  bindkey '^K' kill-line
  bindkey '^U' backward-kill-line
  bindkey '^P' up-history
  bindkey '^N' down-history
  bindkey '^L' clear-screen
  bindkey '^?' backward-delete-char
  bindkey '^H' backward-delete-char

  bindkey -M vicmd '/' history-incremental-search-backward
  bindkey -M vicmd '?' history-incremental-search-forward

  autoload -Uz select-bracketed select-quoted
  zle -N select-quoted
  zle -N select-bracketed

  bindkey -M viopp -- '-' vi-up-line-or-history
  bindkey -M visual -- '-' vi-up-line-or-history
fi

autoload -Uz add-zsh-hook
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats ' (%b)'
zstyle ':vcs_info:*' enable git

_neotui_precmd_vcs() { vcs_info; }
add-zsh-hook precmd _neotui_precmd_vcs

setopt PROMPT_SUBST
PROMPT='%F{243}[%D{%H:%M}]%f %F{39}%~%f%F{45}${vcs_info_msg_0_}%f %(?.%F{51}.%F{red})>%f '
