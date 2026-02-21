#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
TARGET="$BIN_DIR/neotui"
SOURCE="$ROOT_DIR/bin/neotui"
REQ_FILE="$ROOT_DIR/REQUIREMENTS.txt"

NVIM_UPSTREAM_VERSION="0.11.6"
LF_UPSTREAM_VERSION="r41"

export PATH="$ROOT_DIR/.local/bin:$PATH"

declare -A REQUIRED_VERSIONS=()

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

load_requirements() {
  if [ ! -f "$REQ_FILE" ]; then
    printf 'Error: missing %s\n' "$REQ_FILE" >&2
    exit 1
  fi

  while IFS= read -r raw_line; do
    line="$(trim "$raw_line")"
    if [ -z "$line" ] || [[ "$line" == \#* ]]; then
      continue
    fi
    if [[ "$line" =~ ^([a-z0-9_-]+)\>=(.+)$ ]]; then
      REQUIRED_VERSIONS["${BASH_REMATCH[1]}"]="$(trim "${BASH_REMATCH[2]}")"
    else
      printf 'Error: invalid requirements line: %s\n' "$line" >&2
      exit 1
    fi
  done <"$REQ_FILE"
}

normalize_version() {
  local tool="$1"
  local version="$2"
  case "$tool" in
    nvim)
      version="${version#v}"
      ;;
    lf)
      version="${version#r}"
      ;;
  esac
  printf '%s' "$version"
}

get_tool_version() {
  local tool="$1"

  if ! command -v "$tool" >/dev/null 2>&1; then
    return 1
  fi

  local raw=""
  case "$tool" in
    tmux)
      raw="$(tmux -V 2>/dev/null | awk '{print $2}')"
      ;;
    zsh)
      raw="$(zsh --version 2>/dev/null | awk '{print $2}')"
      ;;
    lf)
      raw="$(lf -version 2>/dev/null | awk 'match($0,/r[0-9]+/){print substr($0, RSTART, RLENGTH); exit}')"
      ;;
    nvim)
      raw="$(nvim --version 2>/dev/null | awk 'NR==1 {print $2}')"
      ;;
    *)
      return 1
      ;;
  esac

  if [ -z "$raw" ]; then
    return 1
  fi

  normalize_version "$tool" "$raw"
}

version_ge() {
  local actual="$1"
  local minimum="$2"
  printf '%s\n%s\n' "$minimum" "$actual" | sort -V -C
}

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    printf 'apt'
  elif command -v dnf >/dev/null 2>&1; then
    printf 'dnf'
  elif command -v pacman >/dev/null 2>&1; then
    printf 'pacman'
  elif command -v zypper >/dev/null 2>&1; then
    printf 'zypper'
  else
    printf 'none'
  fi
}

install_with_pkg_manager() {
  local tool="$1"
  local manager="$2"

  local pkg_name="$tool"
  case "$tool" in
    nvim)
      pkg_name="neovim"
      ;;
  esac

  printf 'Installing %s via %s...\n' "$tool" "$manager"
  if [ "${EUID}" -eq 0 ]; then
    case "$manager" in
      apt)
        apt-get install -y "$pkg_name"
        ;;
      dnf)
        dnf install -y "$pkg_name"
        ;;
      pacman)
        pacman -Sy --noconfirm "$pkg_name"
        ;;
      zypper)
        zypper --non-interactive install "$pkg_name"
        ;;
      *)
        return 1
        ;;
    esac
    return 0
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    printf 'No sudo/root available, cannot install %s with %s.\n' "$tool" "$manager" >&2
    return 1
  fi

  case "$manager" in
    apt)
      sudo apt-get install -y "$pkg_name"
      ;;
    dnf)
      sudo dnf install -y "$pkg_name"
      ;;
    pacman)
      sudo pacman -Sy --noconfirm "$pkg_name"
      ;;
    zypper)
      sudo zypper --non-interactive install "$pkg_name"
      ;;
    *)
      return 1
      ;;
  esac
}

download_file() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$output"
  else
    printf 'Error: curl or wget is required for download installs.\n' >&2
    return 1
  fi
}

install_nvim_upstream() {
  if [ "$(uname -m)" != "x86_64" ]; then
    printf 'Upstream Neovim auto-install currently supports x86_64 only.\n' >&2
    return 1
  fi

  local archive
  archive="$(mktemp)"
  local url="https://github.com/neovim/neovim/releases/download/v${NVIM_UPSTREAM_VERSION}/nvim-linux-x86_64.tar.gz"
  local tools_dir="$ROOT_DIR/.local/tools"
  local bin_dir="$ROOT_DIR/.local/bin"
  local install_dir="$tools_dir/nvim-linux-x86_64-${NVIM_UPSTREAM_VERSION}"

  mkdir -p "$tools_dir" "$bin_dir"
  printf 'Installing Neovim v%s from upstream...\n' "$NVIM_UPSTREAM_VERSION"
  download_file "$url" "$archive"

  rm -rf "$install_dir"
  rm -rf "$tools_dir/nvim-linux-x86_64"
  tar -xzf "$archive" -C "$tools_dir"
  rm -f "$archive"

  mv "$tools_dir/nvim-linux-x86_64" "$install_dir"
  ln -sfn "$install_dir/bin/nvim" "$bin_dir/nvim"
}

install_lf_upstream() {
  if [ "$(uname -m)" != "x86_64" ]; then
    printf 'Upstream lf auto-install currently supports x86_64 only.\n' >&2
    return 1
  fi

  local archive
  archive="$(mktemp)"
  local url="https://github.com/gokcehan/lf/releases/download/${LF_UPSTREAM_VERSION}/lf-linux-amd64.tar.gz"
  local tools_dir="$ROOT_DIR/.local/tools"
  local bin_dir="$ROOT_DIR/.local/bin"
  local install_dir="$tools_dir/lf-${LF_UPSTREAM_VERSION}"

  mkdir -p "$tools_dir" "$bin_dir" "$install_dir"
  printf 'Installing lf %s from upstream...\n' "$LF_UPSTREAM_VERSION"
  download_file "$url" "$archive"

  rm -rf "$install_dir"
  mkdir -p "$install_dir"
  tar -xzf "$archive" -C "$install_dir"
  rm -f "$archive"

  ln -sfn "$install_dir/lf" "$bin_dir/lf"
}

ensure_requirements() {
  local tools=(tmux zsh lf nvim)
  local manager
  manager="$(detect_pkg_manager)"

  local missing=()
  local outdated=()
  local unknown=()

  printf 'Checking minimum runtime requirements...\n'
  for tool in "${tools[@]}"; do
    local min actual
    min="${REQUIRED_VERSIONS[$tool]:-}"
    if [ -z "$min" ]; then
      printf 'Error: missing minimum version for %s in %s\n' "$tool" "$REQ_FILE" >&2
      exit 1
    fi

    if actual="$(get_tool_version "$tool")"; then
      if version_ge "$actual" "$min"; then
        printf '  - %s %s (ok, min %s)\n' "$tool" "$actual" "$min"
      else
        printf '  - %s %s (too old, min %s)\n' "$tool" "$actual" "$min"
        outdated+=("$tool")
      fi
    else
      if command -v "$tool" >/dev/null 2>&1; then
        printf '  - %s version unknown (min %s)\n' "$tool" "$min"
        unknown+=("$tool")
      else
        printf '  - %s not found (min %s)\n' "$tool" "$min"
        missing+=("$tool")
      fi
    fi
  done

  if [ "${#missing[@]}" -eq 0 ] && [ "${#outdated[@]}" -eq 0 ] && [ "${#unknown[@]}" -eq 0 ]; then
    printf 'All runtime requirements are satisfied.\n'
    return 0
  fi

  printf '\nMissing or unsupported tools detected.\n'
  if [ "${#missing[@]}" -gt 0 ]; then
    printf 'Missing: %s\n' "${missing[*]}"
  fi
  if [ "${#outdated[@]}" -gt 0 ]; then
    printf 'Outdated: %s\n' "${outdated[*]}"
  fi
  if [ "${#unknown[@]}" -gt 0 ]; then
    printf 'Unknown version: %s\n' "${unknown[*]}"
  fi

  printf 'Install or upgrade required tools now? [y/N]: '
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    printf 'Install cancelled. NeoTUI requirements were not met.\n' >&2
    exit 1
  fi

  local needs_install=("${missing[@]}" "${outdated[@]}" "${unknown[@]}")
  for tool in "${needs_install[@]}"; do
    if [ -z "$tool" ]; then
      continue
    fi

    if [ "$tool" = "nvim" ]; then
      if ! install_with_pkg_manager "$tool" "$manager"; then
        printf 'Package-manager install failed for nvim, trying upstream build...\n'
      fi
      if ! actual="$(get_tool_version nvim)" || ! version_ge "$actual" "${REQUIRED_VERSIONS[nvim]}"; then
        install_nvim_upstream
      fi
      continue
    fi

    if [ "$tool" = "lf" ]; then
      if ! install_with_pkg_manager "$tool" "$manager"; then
        printf 'Package-manager install failed for lf, trying upstream build...\n'
        install_lf_upstream
      fi
      if ! actual="$(get_tool_version lf)" || ! version_ge "$actual" "${REQUIRED_VERSIONS[lf]}"; then
        install_lf_upstream
      fi
      continue
    fi

    install_with_pkg_manager "$tool" "$manager"
  done

  printf '\nRechecking runtime requirements...\n'
  for tool in "${tools[@]}"; do
    local min actual
    min="${REQUIRED_VERSIONS[$tool]}"
    if ! actual="$(get_tool_version "$tool")"; then
      printf 'Error: %s is still missing after install.\n' "$tool" >&2
      exit 1
    fi
    if ! version_ge "$actual" "$min"; then
      printf 'Error: %s version %s is below required %s.\n' "$tool" "$actual" "$min" >&2
      exit 1
    fi
    printf '  - %s %s (ok, min %s)\n' "$tool" "$actual" "$min"
  done
}

cleanup_legacy_link() {
  local symlink_path="$1"
  local expected_target="$2"

  if [ ! -L "$symlink_path" ]; then
    return 0
  fi

  local actual_target
  actual_target="$(readlink "$symlink_path")"
  if [ "$actual_target" != "$expected_target" ]; then
    return 0
  fi

  rm -f "$symlink_path"
  printf 'Removed legacy NeoTUI global symlink: %s -> %s\n' "$symlink_path" "$actual_target"
}

if [ ! -f "$SOURCE" ]; then
  printf 'Error: missing launcher at %s\n' "$SOURCE" >&2
  exit 1
fi

load_requirements
ensure_requirements

cleanup_legacy_link "$HOME/.tmux.conf" "$ROOT_DIR/tmux/tmux.conf"
cleanup_legacy_link "$HOME/.zshrc" "$ROOT_DIR/shell/.zshrc"
cleanup_legacy_link "$HOME/.config/nvim/init.lua" "$ROOT_DIR/nvim/init.lua"
cleanup_legacy_link "$HOME/.config/nvim" "$ROOT_DIR/nvim"

printf 'Applying NeoTUI defaults...\n'
printf '  1) Enabling tmux status bar (top tab navigation)\n'
printf '  2) Setting zsh as the default shell inside NeoTUI tmux\n'
printf '  3) Enabling tmux pane navigation hotkeys (<prefix> h/j/k/l)\n'
printf '  4) Enabling tmux pane split hotkeys (<prefix>+| and <prefix>+-)\n'
printf '  5) Enabling tmux pane resize hotkeys (<prefix>+H/J/K/L)\n'
printf '  6) Enabling tmux <prefix>+E to toggle lf sidebar\n'
printf '  7) Opening lf sidebar by default on new neotui session\n'
printf '  8) Enabling lf keybinds: gh (home), gz (toggle file preview)\n'

mkdir -p "$BIN_DIR"

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  rm -f "$TARGET"
fi

ln -s "$SOURCE" "$TARGET"

printf 'Installed neotui command: %s -> %s\n' "$TARGET" "$SOURCE"

case ":$PATH:" in
  *":$BIN_DIR:"*)
    printf 'PATH already includes %s\n' "$BIN_DIR"
    ;;
  *)
    printf 'Warning: %s is not in PATH. Add it to run neotui directly.\n' "$BIN_DIR"
    ;;
esac

printf 'NeoTUI install complete.\n'
