#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/RobLaughlin/NeoTUI.git"
BRANCH="main"

if ! command -v git >/dev/null 2>&1; then
  printf 'Error: git is required to install NeoTUI.\n' >&2
  exit 1
fi

work_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

printf 'Cloning NeoTUI from %s...\n' "$REPO_URL"
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$work_dir/NeoTUI"

printf 'Running install-local.sh...\n'
bash "$work_dir/NeoTUI/install-local.sh"
