#!/usr/bin/env bash
# ============================================================
# NeoTUI - lf file previewer
# Uses bat for syntax highlighting, falls back to head
# ============================================================

file="$1"
w="${2:-80}"
h="${3:-40}"

# Handle directories
if [ -d "$file" ]; then
    if command -v eza &>/dev/null; then
        eza --tree --level=2 --icons --color=always "$file" | head -n "$h"
    elif command -v tree &>/dev/null; then
        tree -C -L 2 "$file" | head -n "$h"
    else
        ls -la --color=always "$file" | head -n "$h"
    fi
    exit 0
fi

# Handle files by MIME type
mime_type=$(file --mime-type -Lb "$file")

case "$mime_type" in
    text/*|application/json|application/javascript|application/xml|\
    application/x-shellscript|application/toml|application/x-yaml|\
    application/x-empty|inode/x-empty)
        if command -v bat &>/dev/null; then
            bat --color=always --style=plain --line-range=":$h" --wrap=character \
                --terminal-width="$w" "$file" 2>/dev/null
        else
            head -n "$h" "$file"
        fi
        ;;
    application/gzip|application/x-gzip)
        tar tzf "$file" 2>/dev/null | head -n "$h"
        ;;
    application/x-tar)
        tar tf "$file" 2>/dev/null | head -n "$h"
        ;;
    application/zip)
        unzip -l "$file" 2>/dev/null | head -n "$h"
        ;;
    application/x-bzip2)
        tar tjf "$file" 2>/dev/null | head -n "$h"
        ;;
    application/x-xz)
        tar tJf "$file" 2>/dev/null | head -n "$h"
        ;;
    image/*)
        echo "Image: $(file -b "$file")"
        if command -v identify &>/dev/null; then
            identify "$file" 2>/dev/null
        fi
        ;;
    application/pdf)
        if command -v pdftotext &>/dev/null; then
            pdftotext -l 10 "$file" - 2>/dev/null | head -n "$h"
        else
            echo "PDF: $(file -b "$file")"
        fi
        ;;
    *)
        echo "$(file -b "$file")"
        echo ""
        echo "No preview available for: $mime_type"
        ;;
esac
