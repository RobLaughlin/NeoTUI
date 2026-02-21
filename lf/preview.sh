#!/usr/bin/env bash
set -euo pipefail

file="$1"
width="${2:-80}"
height="${3:-40}"

if [ -d "$file" ]; then
  if command -v eza >/dev/null 2>&1; then
    eza --tree --level=2 --icons --color=always "$file" | head -n "$height"
  elif command -v tree >/dev/null 2>&1; then
    tree -C -L 2 "$file" | head -n "$height"
  else
    find "$file" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort | head -n "$height"
  fi
  exit 0
fi

mime_type="$(file --mime-type -Lb "$file")"

case "$mime_type" in
  text/*|application/json|application/javascript|application/xml|application/x-shellscript|application/toml|application/x-yaml|application/x-empty|inode/x-empty)
    if command -v bat >/dev/null 2>&1; then
      bat --color=always --style=plain --line-range=":$height" --wrap=character --terminal-width="$width" "$file" 2>/dev/null
    else
      head -n "$height" "$file"
    fi
    ;;
  application/gzip|application/x-gzip)
    tar tzf "$file" 2>/dev/null | head -n "$height"
    ;;
  application/x-tar)
    tar tf "$file" 2>/dev/null | head -n "$height"
    ;;
  application/zip)
    unzip -l "$file" 2>/dev/null | head -n "$height"
    ;;
  application/x-bzip2)
    tar tjf "$file" 2>/dev/null | head -n "$height"
    ;;
  application/x-xz)
    tar tJf "$file" 2>/dev/null | head -n "$height"
    ;;
  image/*)
    printf 'Image: %s\n' "$(file -b "$file")"
    if command -v identify >/dev/null 2>&1; then
      identify "$file" 2>/dev/null
    fi
    ;;
  application/pdf)
    if command -v pdftotext >/dev/null 2>&1; then
      pdftotext -l 10 "$file" - 2>/dev/null | head -n "$height"
    else
      printf 'PDF: %s\n' "$(file -b "$file")"
    fi
    ;;
  *)
    printf '%s\n\n' "$(file -b "$file")"
    printf 'No preview available for: %s\n' "$mime_type"
    ;;
esac
