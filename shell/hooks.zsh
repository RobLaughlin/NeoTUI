if [[ -n "${TMUX:-}" ]]; then
  while read -t 0.01 -k 1 2>/dev/null; do :; done
fi
