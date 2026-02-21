#!/usr/bin/env bash
set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
  printf 'Error: shellcheck is required and not installed.\n' >&2
  exit 1
fi

mapfile -t shell_files < <(git ls-files --cached --others --exclude-standard '*.sh')

if [ -f "bin/neotui" ]; then
  shell_files+=("bin/neotui")
fi

if [ -f ".husky/pre-commit" ]; then
  shell_files+=(".husky/pre-commit")
fi

if [ "${#shell_files[@]}" -eq 0 ]; then
  printf 'No shell files found.\n'
  exit 0
fi

printf 'Running bash -n syntax checks...\n'
bash -n "${shell_files[@]}"

printf 'Running shellcheck...\n'
shellcheck "${shell_files[@]}"

printf 'Shell checks passed.\n'
