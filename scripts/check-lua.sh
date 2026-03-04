#!/usr/bin/env bash
set -euo pipefail

if ! command -v luacheck >/dev/null 2>&1; then
  printf 'Error: luacheck is required and not installed.\n' >&2
  exit 1
fi

mapfile -t lua_files < <(git ls-files --cached --others --exclude-standard '*.lua')

if [ "${#lua_files[@]}" -eq 0 ]; then
  printf 'No Lua files found.\n'
  exit 0
fi

printf 'Running Lua syntax checks...\n'
if command -v luac >/dev/null 2>&1; then
  luac -p "${lua_files[@]}"
elif command -v nvim >/dev/null 2>&1; then
  for file in "${lua_files[@]}"; do
    nvim --headless -u NONE "+luafile $file" +q
  done
else
  printf 'Error: luac or nvim is required for Lua syntax checks.\n' >&2
  exit 1
fi

printf 'Running luacheck...\n'
luacheck "${lua_files[@]}"

printf 'Lua checks passed.\n'
