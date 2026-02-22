#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="${NEOTUI_HOME:-$HOME/.local/share/neotui}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
TARGET="$BIN_DIR/neotui"
SOURCE="$ROOT_DIR/bin/neotui"
REQ_FILE="$ROOT_DIR/REQUIREMENTS.txt"

NVIM_UPSTREAM_VERSION="0.11.6"
LF_UPSTREAM_VERSION="r41"

export PATH="$INSTALL_ROOT/bin:$PATH"

declare -A REQUIRED_VERSIONS=()

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'
  C_SECTION=$'\033[1;36m'
  C_KEYBIND=$'\033[1;33m'
  C_COMMAND=$'\033[1;32m'
  C_NOTE=$'\033[1;35m'
else
  C_RESET=""
  C_SECTION=""
  C_KEYBIND=""
  C_COMMAND=""
  C_NOTE=""
fi

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

  if [ "$manager" = "none" ]; then
    return 1
  fi

  printf 'Installing %s via %s...\n' "$tool" "$manager"
  if [ "${EUID}" -eq 0 ]; then
    case "$manager" in
      apt) apt-get install -y "$pkg_name" ;;
      dnf) dnf install -y "$pkg_name" ;;
      pacman) pacman -Sy --noconfirm "$pkg_name" ;;
      zypper) zypper --non-interactive install "$pkg_name" ;;
      *) return 1 ;;
    esac
    return 0
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    printf 'No sudo/root available, cannot install %s with %s.\n' "$tool" "$manager" >&2
    return 1
  fi

  case "$manager" in
    apt) sudo apt-get install -y "$pkg_name" ;;
    dnf) sudo dnf install -y "$pkg_name" ;;
    pacman) sudo pacman -Sy --noconfirm "$pkg_name" ;;
    zypper) sudo zypper --non-interactive install "$pkg_name" ;;
    *) return 1 ;;
  esac
}

install_optional_zsh_plugins() {
  local manager="$1"
  local plugin_packages=(zsh-autosuggestions zsh-syntax-highlighting)
  local pkg

  if [ "$manager" = "none" ]; then
    printf 'Skipping optional zsh plugin install (no supported package manager found).\n'
    return 0
  fi

  printf 'Installing optional zsh plugins (autosuggestions + syntax highlighting)...\n'
  for pkg in "${plugin_packages[@]}"; do
    if install_with_pkg_manager "$pkg" "$manager"; then
      printf '  - installed optional package: %s\n' "$pkg"
    else
      printf '  - optional package unavailable: %s (continuing)\n' "$pkg"
    fi
  done
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

  local archive url tools_dir bin_dir install_dir
  archive="$(mktemp)"
  url="https://github.com/neovim/neovim/releases/download/v${NVIM_UPSTREAM_VERSION}/nvim-linux-x86_64.tar.gz"
  tools_dir="$INSTALL_ROOT/tools"
  bin_dir="$INSTALL_ROOT/bin"
  install_dir="$tools_dir/nvim-linux-x86_64-${NVIM_UPSTREAM_VERSION}"

  mkdir -p "$tools_dir" "$bin_dir"
  printf 'Installing Neovim v%s from upstream...\n' "$NVIM_UPSTREAM_VERSION"
  download_file "$url" "$archive"

  rm -rf "$install_dir" "$tools_dir/nvim-linux-x86_64"
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

  local archive url tools_dir bin_dir install_dir
  archive="$(mktemp)"
  url="https://github.com/gokcehan/lf/releases/download/${LF_UPSTREAM_VERSION}/lf-linux-amd64.tar.gz"
  tools_dir="$INSTALL_ROOT/tools"
  bin_dir="$INSTALL_ROOT/bin"
  install_dir="$tools_dir/lf-${LF_UPSTREAM_VERSION}"

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
  local manager missing outdated unknown needs_install tool min actual
  manager="$(detect_pkg_manager)"
  missing=()
  outdated=()
  unknown=()

  printf 'Checking minimum runtime requirements...\n'
  for tool in "${tools[@]}"; do
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
  [ "${#missing[@]}" -gt 0 ] && printf 'Missing: %s\n' "${missing[*]}"
  [ "${#outdated[@]}" -gt 0 ] && printf 'Outdated: %s\n' "${outdated[*]}"
  [ "${#unknown[@]}" -gt 0 ] && printf 'Unknown version: %s\n' "${unknown[*]}"

  printf 'Install or upgrade required tools now? [y/N]: '
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    printf 'Install cancelled. NeoTUI requirements were not met.\n' >&2
    exit 1
  fi

  needs_install=("${missing[@]}" "${outdated[@]}" "${unknown[@]}")
  for tool in "${needs_install[@]}"; do
    [ -z "$tool" ] && continue
    if [ "$tool" = "nvim" ]; then
      install_with_pkg_manager "$tool" "$manager" || printf 'Package-manager install failed for nvim, trying upstream build...\n'
      if ! actual="$(get_tool_version nvim)" || ! version_ge "$actual" "${REQUIRED_VERSIONS[nvim]}"; then
        install_nvim_upstream
      fi
      continue
    fi
    if [ "$tool" = "lf" ]; then
      install_with_pkg_manager "$tool" "$manager" || printf 'Package-manager install failed for lf, trying upstream build...\n'
      if ! actual="$(get_tool_version lf)" || ! version_ge "$actual" "${REQUIRED_VERSIONS[lf]}"; then
        install_lf_upstream
      fi
      continue
    fi
    install_with_pkg_manager "$tool" "$manager"
  done

  printf '\nRechecking runtime requirements...\n'
  for tool in "${tools[@]}"; do
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

copy_runtime_script() {
  local relative="$1"
  local src="$ROOT_DIR/bin/$relative"
  local dst="$INSTALL_ROOT/bin/$relative"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  chmod +x "$dst"
}

copy_config_with_prompt() {
  local src="$1"
  local dst="$2"
  local label="$3"

  mkdir -p "$(dirname "$dst")"

  if [ ! -e "$dst" ]; then
    cp "$src" "$dst"
    printf 'Installed default config: %s\n' "$label"
    return 0
  fi

  if cmp -s "$src" "$dst"; then
    printf 'Config unchanged: %s\n' "$label"
    return 0
  fi

  printf 'Config exists: %s\n' "$label"
  printf 'Overwrite installed config with repo default? [y/N]: '
  read -r overwrite
  if [[ "$overwrite" =~ ^[Yy]$ ]]; then
    cp "$src" "$dst"
    printf 'Overwrote config: %s\n' "$label"
  else
    printf 'Kept installed config: %s\n' "$label"
  fi
}

install_runtime_layout() {
  mkdir -p "$INSTALL_ROOT/bin" "$INSTALL_ROOT/config" "$INSTALL_ROOT/data" "$INSTALL_ROOT/state" "$INSTALL_ROOT/cache" "$INSTALL_ROOT/tools"

  copy_runtime_script "neotui"
  copy_runtime_script "neotui-toggle-lf"
  copy_runtime_script "neotui-clean-session"
  copy_runtime_script "neotui-watch-session"

  copy_config_with_prompt "$ROOT_DIR/tmux/tmux.conf" "$INSTALL_ROOT/config/tmux/tmux.conf" "tmux/tmux.conf"
  copy_config_with_prompt "$ROOT_DIR/lf/lfrc" "$INSTALL_ROOT/config/lf/lfrc" "lf/lfrc"
  copy_config_with_prompt "$ROOT_DIR/nvim/init.lua" "$INSTALL_ROOT/config/nvim/init.lua" "nvim/init.lua"
  copy_config_with_prompt "$ROOT_DIR/shell/.zshrc" "$INSTALL_ROOT/config/shell/.zshrc" "shell/.zshrc"
  copy_config_with_prompt "$ROOT_DIR/shell/env.zsh" "$INSTALL_ROOT/config/shell/env.zsh" "shell/env.zsh"
  copy_config_with_prompt "$ROOT_DIR/shell/vi-mode.zsh" "$INSTALL_ROOT/config/shell/vi-mode.zsh" "shell/vi-mode.zsh"
  copy_config_with_prompt "$ROOT_DIR/shell/hooks.zsh" "$INSTALL_ROOT/config/shell/hooks.zsh" "shell/hooks.zsh"
  copy_config_with_prompt "$ROOT_DIR/shell/aliases.zsh" "$INSTALL_ROOT/config/shell/aliases.zsh" "shell/aliases.zsh"
  copy_config_with_prompt "$ROOT_DIR/shell/plugins.zsh" "$INSTALL_ROOT/config/shell/plugins.zsh" "shell/plugins.zsh"
}

prompt_history_reset() {
  local history_file="$INSTALL_ROOT/state/zsh/history"
  mkdir -p "$(dirname "$history_file")"
  printf 'Create a brand new NeoTUI history file at %s? [y/N]: ' "$history_file"
  read -r reset_history
  if [[ "$reset_history" =~ ^[Yy]$ ]]; then
    : > "$history_file"
    printf 'Created fresh NeoTUI history file.\n'
  else
    printf 'Keeping existing NeoTUI history file.\n'
  fi
}

print_applied_defaults() {
  printf 'Applying NeoTUI defaults...\n'
  printf '\n'

  printf '%bTmux%b\n' "$C_SECTION" "$C_RESET"
  printf '  - status: top bar with tab navigation\n'
  printf '  - shell: zsh is the default shell inside NeoTUI tmux panes\n'
  printf '  - keybinds: %b<prefix> h/j/k/l%b (move), %b<prefix>+|%b and %b<prefix>+-%b (split), %b<prefix>+H/J/K/L%b (resize)\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
  printf '  - keybind: %b<prefix>+E%b toggles lf sidebar\n' "$C_KEYBIND" "$C_RESET"
  printf '\n'

  printf '%bZsh%b\n' "$C_SECTION" "$C_RESET"
  printf '  - command: %blfsync%b syncs zsh cwd to lf pane path (same window)\n' "$C_COMMAND" "$C_RESET"
  printf '  - features: completion via compinit; autosuggestions + syntax highlighting when installed\n'
  printf '  - history: %s (installer prompts to reset, default: no)\n' "$INSTALL_ROOT/state/zsh/history"
  printf '\n'

  printf '%bLf%b\n' "$C_SECTION" "$C_RESET"
  printf '  - behavior: opens by default as left sidebar; auto-refresh on create/delete changes\n'
  printf '  - keybinds: %bgh%b (home), %bgz%b (preview), %bgs%b (sync to zsh dir)\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
  printf '  - keybinds: %bl%b (enter dir / open in nvim), %bEnter%b (enter dir / open in new tmux window)\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
  printf '  - keybinds: %byy/yY%b (queue copy/cut), %bp/P%b (execute queues), %byq%b (queue status), %bc%b (clear queues)\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
  printf '  - keybinds: %bmd%b (mkdir), %bmf%b (touch), %bdd%b (trash), %bgu/gr%b (undo/redo)\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
  printf '  - note: default lf mark keys are disabled (%bSpace/v/u%b)\n' "$C_NOTE" "$C_RESET"
  printf '\n'

  printf '%bNvim%b\n' "$C_SECTION" "$C_RESET"
  printf '  - keybinds: %bCtrl+h%b (previous tab), %bCtrl+l%b (next tab)\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
  printf '  - commands: %b:tabn%b / %b:tabp%b / %b:tabclose%b\n' "$C_COMMAND" "$C_RESET" "$C_COMMAND" "$C_RESET" "$C_COMMAND" "$C_RESET"
  printf '\n'
}

if [ ! -f "$SOURCE" ]; then
  printf 'Error: missing launcher at %s\n' "$SOURCE" >&2
  exit 1
fi

load_requirements
ensure_requirements

install_optional_zsh_plugins "$(detect_pkg_manager)"

cleanup_legacy_link "$HOME/.tmux.conf" "$ROOT_DIR/tmux/tmux.conf"
cleanup_legacy_link "$HOME/.zshrc" "$ROOT_DIR/shell/.zshrc"
cleanup_legacy_link "$HOME/.config/nvim/init.lua" "$ROOT_DIR/nvim/init.lua"
cleanup_legacy_link "$HOME/.config/nvim" "$ROOT_DIR/nvim"

print_applied_defaults

printf 'Installing NeoTUI runtime home: %s\n' "$INSTALL_ROOT"
install_runtime_layout
prompt_history_reset

mkdir -p "$BIN_DIR"
if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  rm -f "$TARGET"
fi
ln -s "$INSTALL_ROOT/bin/neotui" "$TARGET"

printf 'Installed neotui command: %s -> %s\n' "$TARGET" "$INSTALL_ROOT/bin/neotui"
printf 'NeoTUI runtime configs are now sourced from %s/config\n' "$INSTALL_ROOT"
printf 'See README.md for the NeoTUI runtime directory tree.\n'

case ":$PATH:" in
  *":$BIN_DIR:"*) printf 'PATH already includes %s\n' "$BIN_DIR" ;;
  *) printf 'Warning: %s is not in PATH. Add it to run neotui directly.\n' "$BIN_DIR" ;;
esac

printf 'NeoTUI install complete.\n'
