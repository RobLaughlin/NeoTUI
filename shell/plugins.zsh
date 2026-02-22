if [[ -o interactive ]] && [[ -t 0 ]]; then
  for autosuggest_file in \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    if [[ -f "$autosuggest_file" ]]; then
      source "$autosuggest_file"
      break
    fi
  done

  for highlight_file in \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    if [[ -f "$highlight_file" ]]; then
      source "$highlight_file"
      break
    fi
  done
fi
