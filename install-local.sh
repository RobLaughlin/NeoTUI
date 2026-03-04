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
declare -A CONFIG_SECTION_OVERWRITE_MODE=()
ENABLE_NVIM_IDE_PROFILE=1
ENABLE_NVIM_FORMAT_ON_SAVE=1
PYTHON_FORMATTER_PREREQS_OK=1
RUST_FORMATTER_PREREQS_OK=1
GO_FORMATTER_PREREQS_OK=1
ENABLE_NVIM_CLIPBOARD_SHARING=1
ENABLE_WSL_HOST_CLIPBOARD=0
INSTALL_IS_WSL2=0
ENABLE_NVIM_AI_PROMPT_INSERTION=1
ENABLE_NVIM_OPENCODE_PROMPT_ROUTING=1
ENABLE_NVIM_DEBUGGER=1
CONFIG_OVERWRITE_COUNT=0
CONFIG_KEEP_COUNT=0

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

prompt_yes_no() {
  local prompt="$1"
  local default_answer="$2"
  local response=""

  printf '%s' "$prompt"

  if [ -r /dev/tty ]; then
    if ! read -r response </dev/tty; then
      response=""
    fi
  fi

  if [ -z "$response" ]; then
    [ "$default_answer" = "y" ]
    return
  fi

  case "$response" in
    [Yy]*) return 0 ;;
    [Nn]*) return 1 ;;
    *)
      [ "$default_answer" = "y" ]
      return
      ;;
  esac
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

detect_wsl2() {
  local osrelease=""

  if [ -r /proc/sys/kernel/osrelease ]; then
    osrelease="$(tr '[:upper:]' '[:lower:]' </proc/sys/kernel/osrelease)"
  fi

  if [[ "$osrelease" == *microsoft* ]] && [[ "$osrelease" == *wsl2* ]]; then
    return 0
  fi

  if [ -n "${WSL_INTEROP:-}" ] && [ -S "${WSL_INTEROP}" ]; then
    return 0
  fi

  return 1
}

install_with_pkg_manager() {
  local tool="$1"
  local manager="$2"

  local pkg_name="$tool"
  case "$tool" in
    nvim)
      pkg_name="neovim"
      ;;
    python3)
      if [ "$manager" = "pacman" ]; then
        pkg_name="python"
      fi
      ;;
    python3-pip)
      if [ "$manager" = "pacman" ]; then
        pkg_name="python-pip"
      fi
      ;;
    python3-venv)
      if [ "$manager" = "pacman" ]; then
        pkg_name="python"
      fi
      ;;
    rustfmt)
      ;;
    gofmt)
      case "$manager" in
        apt) pkg_name="golang-go" ;;
        dnf) pkg_name="golang" ;;
        pacman) pkg_name="go" ;;
        zypper) pkg_name="go" ;;
      esac
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

python_formatter_prereqs_ready() {
  local tmp_root

  if ! command -v python3 >/dev/null 2>&1; then
    return 1
  fi

  tmp_root="$(mktemp -d 2>/dev/null || true)"
  if [ -z "$tmp_root" ]; then
    return 1
  fi

  if python3 -m venv "$tmp_root/neotui-venv-check" >/dev/null 2>&1; then
    rm -rf "$tmp_root"
    return 0
  fi

  rm -rf "$tmp_root"
  return 1
}

rust_formatter_prereqs_ready() {
  command -v rustfmt >/dev/null 2>&1
}

go_formatter_prereqs_ready() {
  command -v gofmt >/dev/null 2>&1
}

install_python_formatter_prereqs() {
  local manager="$1"
  local py_venv_pkg="python3-venv"

  if [ "$manager" = "apt" ] && command -v python3 >/dev/null 2>&1; then
    local py_minor
    py_minor="$(python3 -c 'import sys; print(f"python{sys.version_info.major}.{sys.version_info.minor}-venv")' 2>/dev/null || true)"
    if [ -n "$py_minor" ]; then
      py_venv_pkg="$py_minor"
    fi
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    if ! install_with_pkg_manager python3 "$manager"; then
      printf 'Warning: failed to install python3 automatically.\n'
    fi
  fi

  if command -v python3 >/dev/null 2>&1 && ! python_formatter_prereqs_ready; then
    if [ "$manager" = "apt" ] && [ "$py_venv_pkg" != "python3-venv" ]; then
      if ! install_with_pkg_manager "$py_venv_pkg" "$manager"; then
        printf 'Versioned venv package install failed (%s), trying python3-venv...\n' "$py_venv_pkg"
        install_with_pkg_manager python3-venv "$manager" || true
      fi
    elif ! install_with_pkg_manager python3-venv "$manager"; then
      printf 'Package-manager install failed for python3 venv support, trying pip package...\n'
    fi
  fi

  if command -v python3 >/dev/null 2>&1 && ! python_formatter_prereqs_ready; then
    if ! install_with_pkg_manager python3-pip "$manager"; then
      printf 'Package-manager install failed for python3 pip, trying ensurepip bootstrap...\n'
    fi
  fi

  if command -v python3 >/dev/null 2>&1 && ! python_formatter_prereqs_ready; then
    if python3 -m ensurepip --default-pip >/dev/null 2>&1; then
      printf 'Bootstrapped pip using python3 -m ensurepip.\n'
    fi
  fi
}

install_rust_formatter_prereqs() {
  local manager="$1"

  if rust_formatter_prereqs_ready; then
    return 0
  fi

  if command -v rustup >/dev/null 2>&1; then
    printf 'Installing rustfmt via rustup...\n'
    rustup component add rustfmt || printf 'Warning: rustup failed to add rustfmt.\n'
  fi

  if ! rust_formatter_prereqs_ready; then
    install_with_pkg_manager rustfmt "$manager" || printf 'Warning: failed to install rustfmt automatically.\n'
  fi
}

install_go_formatter_prereqs() {
  local manager="$1"

  if go_formatter_prereqs_ready; then
    return 0
  fi

  install_with_pkg_manager gofmt "$manager" || printf 'Warning: failed to install go/gofmt automatically.\n'
}

ensure_formatter_prereqs() {
  local manager
  local missing_ids=()
  local id

  if [ "$ENABLE_NVIM_IDE_PROFILE" -ne 1 ]; then
    return 0
  fi

  if python_formatter_prereqs_ready; then
    PYTHON_FORMATTER_PREREQS_OK=1
  else
    PYTHON_FORMATTER_PREREQS_OK=0
    missing_ids+=(python)
  fi

  if rust_formatter_prereqs_ready; then
    RUST_FORMATTER_PREREQS_OK=1
  else
    RUST_FORMATTER_PREREQS_OK=0
    missing_ids+=(rust)
  fi

  if go_formatter_prereqs_ready; then
    GO_FORMATTER_PREREQS_OK=1
  else
    GO_FORMATTER_PREREQS_OK=0
    missing_ids+=(go)
  fi

  if [ "${#missing_ids[@]}" -eq 0 ]; then
    printf 'Formatter prerequisites are satisfied for python/rust/go.\n'
    return 0
  fi

  printf '\nSome nvim formatter prerequisites are missing:\n'
  if [ "$PYTHON_FORMATTER_PREREQS_OK" -ne 1 ]; then
    printf '  - Python formatter (black/ruff): python3 with venv/pip support\n'
  fi
  if [ "$RUST_FORMATTER_PREREQS_OK" -ne 1 ]; then
    printf '  - Rust formatter (rustfmt): rustfmt\n'
  fi
  if [ "$GO_FORMATTER_PREREQS_OK" -ne 1 ]; then
    printf '  - Go formatter (gofmt): gofmt\n'
  fi

  if ! prompt_yes_no 'Install missing formatter prerequisites now? [Y/n]: ' 'y'; then
    printf 'Warning: some formatters will be unavailable until these dependencies are installed.\n'
    return 0
  fi

  manager="$(detect_pkg_manager)"

  for id in "${missing_ids[@]}"; do
    case "$id" in
      python)
        install_python_formatter_prereqs "$manager"
        ;;
      rust)
        install_rust_formatter_prereqs "$manager"
        ;;
      go)
        install_go_formatter_prereqs "$manager"
        ;;
    esac
  done

  if python_formatter_prereqs_ready; then
    PYTHON_FORMATTER_PREREQS_OK=1
  else
    PYTHON_FORMATTER_PREREQS_OK=0
    printf 'Warning: Python formatting remains unavailable. Install python3 venv/pip support, then run :MasonToolsInstall in nvim.\n'
  fi

  if rust_formatter_prereqs_ready; then
    RUST_FORMATTER_PREREQS_OK=1
  else
    RUST_FORMATTER_PREREQS_OK=0
    printf 'Warning: Rust formatting remains unavailable. Install rustfmt and retry.\n'
  fi

  if go_formatter_prereqs_ready; then
    GO_FORMATTER_PREREQS_OK=1
  else
    GO_FORMATTER_PREREQS_OK=0
    printf 'Warning: Go formatting remains unavailable. Install go/gofmt and retry.\n'
  fi
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

install_optional_nvim_ide_tools() {
  local manager="$1"

  if [ "$ENABLE_NVIM_IDE_PROFILE" -ne 1 ]; then
    return 0
  fi

  if [ "$manager" = "none" ]; then
    printf 'Skipping optional nvim IDE tool install (no supported package manager found).\n'
    return 0
  fi

  printf 'Installing optional nvim IDE runtime tools...\n'
  if install_with_pkg_manager ripgrep "$manager"; then
    printf '  - installed optional package: ripgrep\n'
  else
    printf '  - optional package unavailable: ripgrep (continuing; telescope live grep may be limited)\n'
  fi
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

install_opencode_upstream() {
  printf 'Installing OpenCode from upstream installer...\n'
  if ! command -v curl >/dev/null 2>&1; then
    printf 'Error: curl is required to install OpenCode from upstream.\n' >&2
    return 1
  fi

  if ! curl -fsSL https://opencode.ai/install | bash; then
    printf 'Error: OpenCode install script failed.\n' >&2
    return 1
  fi

  if command -v opencode >/dev/null 2>&1; then
    return 0
  fi

  if [ -x "$HOME/.opencode/bin/opencode" ]; then
    export PATH="$HOME/.opencode/bin:$PATH"
    printf 'OpenCode was installed at %s; using it for this install run.\n' "$HOME/.opencode/bin/opencode"
    printf 'Note: add %s to PATH in your shell if needed.\n' "$HOME/.opencode/bin"
    return 0
  fi

  if [ -x "$HOME/.local/bin/opencode" ]; then
    export PATH="$HOME/.local/bin:$PATH"
    printf 'OpenCode was installed at %s but may require a new shell for PATH updates.\n' "$HOME/.local/bin/opencode"
    return 0
  fi

  printf 'Error: OpenCode install completed but opencode command is not available in PATH.\n' >&2
  return 1
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

  if ! prompt_yes_no 'Install or upgrade required tools now? [y/N]: ' 'n'; then
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
  local section="$4"

  local section_mode="${CONFIG_SECTION_OVERWRITE_MODE[$section]:-}"

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

  if [ -z "$section_mode" ]; then
    printf '\nConfig section: %s\n' "$section"
    printf 'Existing installed configs in this section differ from repo defaults.\n'
    printf 'Choose overwrite mode: [a]sk per file, [y] overwrite all, [n] keep all [a]: '

    local mode_response=""
    if [ -r /dev/tty ]; then
      if ! read -r mode_response </dev/tty; then
        mode_response=""
      fi
    fi

    case "$mode_response" in
      [Yy]*) section_mode="all_overwrite" ;;
      [Nn]*) section_mode="all_keep" ;;
      *) section_mode="ask" ;;
    esac

    CONFIG_SECTION_OVERWRITE_MODE["$section"]="$section_mode"
  fi

  case "$section_mode" in
    all_overwrite)
      cp "$src" "$dst"
      CONFIG_OVERWRITE_COUNT=$((CONFIG_OVERWRITE_COUNT + 1))
      printf 'Overwrote config [%s]: %s\n' "$section" "$label"
      ;;
    all_keep)
      CONFIG_KEEP_COUNT=$((CONFIG_KEEP_COUNT + 1))
      printf 'Kept installed config [%s]: %s\n' "$section" "$label"
      ;;
    ask|*)
      printf 'Config exists [%s]: %s\n' "$section" "$label"
      if prompt_yes_no 'Overwrite installed config with repo default? [y/N]: ' 'n'; then
        cp "$src" "$dst"
        CONFIG_OVERWRITE_COUNT=$((CONFIG_OVERWRITE_COUNT + 1))
        printf 'Overwrote config [%s]: %s\n' "$section" "$label"
      else
        CONFIG_KEEP_COUNT=$((CONFIG_KEEP_COUNT + 1))
        printf 'Kept installed config [%s]: %s\n' "$section" "$label"
      fi
      ;;
  esac
}

print_config_overwrite_summary() {
  printf '\nConfig overwrite summary:\n'
  printf '  - overwritten differing configs: %s\n' "$CONFIG_OVERWRITE_COUNT"
  printf '  - kept differing configs: %s\n' "$CONFIG_KEEP_COUNT"
}

print_config_section_header() {
  local section="$1"
  printf '\n[%s config]\n' "$section"
}

install_config_section() {
  local section="$1"
  local src="$2"
  local dst="$3"
  local label="$4"

  copy_config_with_prompt "$src" "$dst" "$label" "$section"
}

install_runtime_layout() {
  mkdir -p "$INSTALL_ROOT/bin" "$INSTALL_ROOT/config" "$INSTALL_ROOT/data" "$INSTALL_ROOT/state" "$INSTALL_ROOT/cache" "$INSTALL_ROOT/tools"

  copy_runtime_script "neotui"
  copy_runtime_script "neotui-toggle-lf"
  copy_runtime_script "neotui-clean-session"
  copy_runtime_script "neotui-watch-session"

  printf '\nInstalling NeoTUI runtime configs (sectioned by tool)...\n'

  print_config_section_header "Tmux"
  install_config_section "Tmux" "$ROOT_DIR/tmux/tmux.conf" "$INSTALL_ROOT/config/tmux/tmux.conf" "tmux/tmux.conf"

  print_config_section_header "Lf"
  install_config_section "Lf" "$ROOT_DIR/lf/lfrc" "$INSTALL_ROOT/config/lf/lfrc" "lf/lfrc"

  print_config_section_header "Nvim"
  install_config_section "Nvim" "$ROOT_DIR/nvim/init.lua" "$INSTALL_ROOT/config/nvim/init.lua" "nvim/init.lua"
  install_config_section "Nvim" "$ROOT_DIR/nvim/lua/neotui/minimal.lua" "$INSTALL_ROOT/config/nvim/lua/neotui/minimal.lua" "nvim/lua/neotui/minimal.lua"
  install_config_section "Nvim" "$ROOT_DIR/nvim/lua/neotui/clipboard.lua" "$INSTALL_ROOT/config/nvim/lua/neotui/clipboard.lua" "nvim/lua/neotui/clipboard.lua"
  install_config_section "Nvim" "$ROOT_DIR/nvim/lua/neotui/ide/init.lua" "$INSTALL_ROOT/config/nvim/lua/neotui/ide/init.lua" "nvim/lua/neotui/ide/init.lua"
  install_config_section "Nvim" "$ROOT_DIR/nvim/lua/neotui/ide/options.lua" "$INSTALL_ROOT/config/nvim/lua/neotui/ide/options.lua" "nvim/lua/neotui/ide/options.lua"
  install_config_section "Nvim" "$ROOT_DIR/nvim/lua/neotui/ide/ai_insert.lua" "$INSTALL_ROOT/config/nvim/lua/neotui/ide/ai_insert.lua" "nvim/lua/neotui/ide/ai_insert.lua"
  install_config_section "Nvim" "$ROOT_DIR/nvim/lua/neotui/ide/explorer.lua" "$INSTALL_ROOT/config/nvim/lua/neotui/ide/explorer.lua" "nvim/lua/neotui/ide/explorer.lua"
  install_config_section "Nvim" "$ROOT_DIR/nvim/lua/neotui/ide/keymaps.lua" "$INSTALL_ROOT/config/nvim/lua/neotui/ide/keymaps.lua" "nvim/lua/neotui/ide/keymaps.lua"
  install_config_section "Nvim" "$ROOT_DIR/nvim/lua/neotui/ide/lazy.lua" "$INSTALL_ROOT/config/nvim/lua/neotui/ide/lazy.lua" "nvim/lua/neotui/ide/lazy.lua"
  install_config_section "Nvim" "$ROOT_DIR/nvim/lua/neotui/ide/plugins.lua" "$INSTALL_ROOT/config/nvim/lua/neotui/ide/plugins.lua" "nvim/lua/neotui/ide/plugins.lua"

  print_config_section_header "Shell (zsh)"
  install_config_section "Shell (zsh)" "$ROOT_DIR/shell/.zshrc" "$INSTALL_ROOT/config/shell/.zshrc" "shell/.zshrc"
  install_config_section "Shell (zsh)" "$ROOT_DIR/shell/env.zsh" "$INSTALL_ROOT/config/shell/env.zsh" "shell/env.zsh"
  install_config_section "Shell (zsh)" "$ROOT_DIR/shell/vi-mode.zsh" "$INSTALL_ROOT/config/shell/vi-mode.zsh" "shell/vi-mode.zsh"
  install_config_section "Shell (zsh)" "$ROOT_DIR/shell/hooks.zsh" "$INSTALL_ROOT/config/shell/hooks.zsh" "shell/hooks.zsh"
  install_config_section "Shell (zsh)" "$ROOT_DIR/shell/aliases.zsh" "$INSTALL_ROOT/config/shell/aliases.zsh" "shell/aliases.zsh"
  install_config_section "Shell (zsh)" "$ROOT_DIR/shell/plugins.zsh" "$INSTALL_ROOT/config/shell/plugins.zsh" "shell/plugins.zsh"

  print_config_overwrite_summary
}

prompt_nvim_ide_profile() {
  local ide_flag="$INSTALL_ROOT/state/nvim/ide-profile-enabled"

  mkdir -p "$(dirname "$ide_flag")"
  if ! prompt_yes_no 'Enable NeoTUI recommended nvim IDE profile (LSP, completion, telescope, gitsigns, formatting/linting, codeium)? [Y/n]: ' 'y'; then
    ENABLE_NVIM_IDE_PROFILE=0
    rm -f "$ide_flag"
    printf 'Keeping minimal NeoTUI nvim profile.\n'
  else
    ENABLE_NVIM_IDE_PROFILE=1
    : > "$ide_flag"
    printf 'Enabled NeoTUI recommended nvim IDE profile.\n'
    printf 'Run :Codeium Auth in nvim once to enable AI autocomplete.\n'
    printf 'Neo-tree sticky explorer is enabled. Use <leader>e to toggle visibility across tabs.\n'
  fi
}

prompt_nvim_format_on_save() {
  local format_disable_flag="$INSTALL_ROOT/state/nvim/format-on-save-disabled"

  mkdir -p "$(dirname "$format_disable_flag")"

  if [ "$ENABLE_NVIM_IDE_PROFILE" -ne 1 ]; then
    ENABLE_NVIM_FORMAT_ON_SAVE=0
    rm -f "$format_disable_flag"
    printf 'Skipping nvim format-on-save prompt (minimal nvim profile selected).\n'
    return 0
  fi

  if ! prompt_yes_no 'Enable nvim format-on-save in NeoTUI IDE profile? [Y/n]: ' 'y'; then
    ENABLE_NVIM_FORMAT_ON_SAVE=0
    : > "$format_disable_flag"
    printf 'Disabled nvim format-on-save in NeoTUI IDE profile.\n'
  else
    ENABLE_NVIM_FORMAT_ON_SAVE=1
    rm -f "$format_disable_flag"
    printf 'Enabled nvim format-on-save in NeoTUI IDE profile.\n'
  fi
}

prompt_nvim_ai_prompt_insertion() {
  local ai_prompt_disable_flag="$INSTALL_ROOT/state/nvim/ai-prompt-insertion-disabled"

  mkdir -p "$(dirname "$ai_prompt_disable_flag")"

  if [ "$ENABLE_NVIM_IDE_PROFILE" -ne 1 ]; then
    ENABLE_NVIM_AI_PROMPT_INSERTION=0
    rm -f "$ai_prompt_disable_flag"
    printf 'Skipping nvim AI prompt insertion prompt (minimal nvim profile selected).\n'
    return 0
  fi

  if ! prompt_yes_no 'Enable custom AI prompt code insertion in nvim (Ctrl+k provider popup)? [Y/n]: ' 'y'; then
    ENABLE_NVIM_AI_PROMPT_INSERTION=0
    : > "$ai_prompt_disable_flag"
    printf 'Disabled nvim AI prompt code insertion.\n'
  else
    ENABLE_NVIM_AI_PROMPT_INSERTION=1
    rm -f "$ai_prompt_disable_flag"
    printf 'Enabled nvim AI prompt code insertion (Ctrl+k).\n'
    printf 'Ctrl+k prompt uses the active provider and shows auth/model context in the prompt label.\n'
    printf 'Switch provider/auth with <leader>ap (or :NeoTUIAIProvider) and select model with <leader>am (or :NeoTUIAIModel).\n'
  fi
}

prompt_nvim_opencode_prompt_routing() {
  local provider_state_file="$INSTALL_ROOT/state/nvim/ai-prompt-provider"
  mkdir -p "$(dirname "$provider_state_file")"

  if [ "$ENABLE_NVIM_AI_PROMPT_INSERTION" -ne 1 ]; then
    ENABLE_NVIM_OPENCODE_PROMPT_ROUTING=0
    return 0
  fi

  if prompt_yes_no 'Use OpenCode for nvim prompt insertion/provider-model routing? [Y/n]: ' 'y'; then
    ENABLE_NVIM_OPENCODE_PROMPT_ROUTING=1
    if ! command -v opencode >/dev/null 2>&1 && [ ! -x "$HOME/.opencode/bin/opencode" ] && [ ! -x "$HOME/.local/bin/opencode" ]; then
      printf 'OpenCode was not found in PATH.\n'
      if prompt_yes_no 'Install OpenCode now using curl -fsSL https://opencode.ai/install | bash ? [Y/n]: ' 'y'; then
        if install_opencode_upstream; then
          printf 'Installed OpenCode successfully.\n'
        else
          ENABLE_NVIM_OPENCODE_PROMPT_ROUTING=0
          printf 'OpenCode install failed; prompt insertion will default to Codeium provider.\n'
        fi
      else
        ENABLE_NVIM_OPENCODE_PROMPT_ROUTING=0
        printf 'Skipping OpenCode install; prompt insertion will default to Codeium provider.\n'
      fi
    fi
  else
    ENABLE_NVIM_OPENCODE_PROMPT_ROUTING=0
    printf 'Keeping Codeium as default nvim prompt insertion provider.\n'
  fi

  if [ "$ENABLE_NVIM_OPENCODE_PROMPT_ROUTING" -eq 1 ]; then
    printf 'opencode\n' >"$provider_state_file"
    printf 'Set nvim prompt insertion default provider to OpenCode.\n'
  else
    printf 'codeium\n' >"$provider_state_file"
  fi
}

prompt_nvim_debugger() {
  local debugger_disable_flag="$INSTALL_ROOT/state/nvim/debugger-disabled"
  mkdir -p "$(dirname "$debugger_disable_flag")"

  if [ "$ENABLE_NVIM_IDE_PROFILE" -ne 1 ]; then
    ENABLE_NVIM_DEBUGGER=0
    rm -f "$debugger_disable_flag"
    printf 'Skipping nvim debugger prompt (minimal nvim profile selected).\n'
    return 0
  fi

  if prompt_yes_no 'Enable nvim debugger features (DAP + debugger UI)? [Y/n]: ' 'y'; then
    ENABLE_NVIM_DEBUGGER=1
    rm -f "$debugger_disable_flag"
    printf 'Enabled nvim debugger features.\n'
  else
    ENABLE_NVIM_DEBUGGER=0
    : > "$debugger_disable_flag"
    printf 'Disabled nvim debugger features.\n'
  fi
}

prompt_nvim_clipboard_settings() {
  local clipboard_disable_flag="$INSTALL_ROOT/state/nvim/clipboard-sharing-disabled"
  local wsl_host_clipboard_disable_flag="$INSTALL_ROOT/state/nvim/wsl-host-clipboard-disabled"

  mkdir -p "$(dirname "$clipboard_disable_flag")"

  if ! prompt_yes_no 'Enable nvim system clipboard sharing (yank/delete uses clipboard)? [Y/n]: ' 'y'; then
    ENABLE_NVIM_CLIPBOARD_SHARING=0
    ENABLE_WSL_HOST_CLIPBOARD=0
    : > "$clipboard_disable_flag"
    printf 'Disabled nvim system clipboard sharing.\n'
    return 0
  fi

  ENABLE_NVIM_CLIPBOARD_SHARING=1
  rm -f "$clipboard_disable_flag"
  printf 'Enabled nvim system clipboard sharing.\n'

  if [ "$INSTALL_IS_WSL2" -ne 1 ]; then
    ENABLE_WSL_HOST_CLIPBOARD=0
    printf 'WSL2 not detected; skipping Windows host clipboard bridge prompt.\n'
    return 0
  fi

  if ! prompt_yes_no 'Enable WSL2 <-> Windows host clipboard bridge for nvim? [Y/n]: ' 'y'; then
    ENABLE_WSL_HOST_CLIPBOARD=0
    : > "$wsl_host_clipboard_disable_flag"
    printf 'Disabled WSL2 <-> Windows host clipboard bridge.\n'
  else
    ENABLE_WSL_HOST_CLIPBOARD=1
    rm -f "$wsl_host_clipboard_disable_flag"
    printf 'Enabled WSL2 <-> Windows host clipboard bridge.\n'
  fi
}

prompt_history_reset() {
  local history_file="$INSTALL_ROOT/state/zsh/history"
  mkdir -p "$(dirname "$history_file")"
  if prompt_yes_no "Create a brand new NeoTUI history file at $history_file? [y/N]: " 'n'; then
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
  printf '  - prefix: %bCtrl+a%b (use %b<prefix>+a%b to send literal Ctrl+a)\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
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
  printf '  - keybind: %b<leader>fm%b formats the current file\n' "$C_KEYBIND" "$C_RESET"
  printf '  - format coverage: bash/sh/zsh/lua/json/jsonc/markdown/toml/yaml/html/css/scss/javascript/typescript/jsx/tsx/python/rust/go\n'
  printf '  - keybinds: %bCtrl+h%b (previous tab), %bCtrl+l%b (next tab)\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
  printf '  - keybinds: %bS-Tab%b (Codeium accept), %bC-y%b (Codeium accept fallback), %bC-g%b (Codeium accept line)\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
  if [ "$ENABLE_NVIM_AI_PROMPT_INSERTION" -eq 1 ]; then
    printf '  - keybind: %bCtrl+k%b opens AI prompt with auth/provider/model label and inserts generated code at cursor\n' "$C_KEYBIND" "$C_RESET"
    printf '  - keybinds: %b<leader>ap%b opens AI provider/auth menu, %b<leader>am%b opens AI model selector\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
    printf '  - ai prompt controls: %b:NeoTUIAIProvider%b (switch), %b:NeoTUIAIModel%b (model), %b:NeoTUIAIStatus%b (status)\n' "$C_COMMAND" "$C_RESET" "$C_COMMAND" "$C_RESET" "$C_COMMAND" "$C_RESET"
  else
    printf '  - keybind: %bCtrl+k%b AI prompt insertion disabled by installer option\n' "$C_KEYBIND" "$C_RESET"
  fi
  if [ "$ENABLE_NVIM_DEBUGGER" -eq 1 ]; then
    printf '  - debugger keybinds: %b<leader>db%b (breakpoint), %b<leader>dc%b (continue), %b<leader>di/do/dO%b (step), %b<leader>du%b (debugger UI)\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
  else
    printf '  - debugger: disabled by installer option\n'
  fi
  printf '  - keybinds: %b<leader>e%b (toggle neo-tree), %bCtrl-w h/l%b (move explorer/editor), %bCtrl-w p%b (previous window)\n' "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET" "$C_KEYBIND" "$C_RESET"
  printf '  - commands: %b:tabn%b / %b:tabp%b / %b:tabclose%b\n' "$C_COMMAND" "$C_RESET" "$C_COMMAND" "$C_RESET" "$C_COMMAND" "$C_RESET"
  printf '  - behavior: neo-tree %bEnter%b opens file in new nvim tab and reveals it; tabline is always visible\n' "$C_KEYBIND" "$C_RESET"
  printf '  - profile: recommended IDE defaults are installer prompt controlled (default: enabled)\n'
  if [ "$ENABLE_NVIM_CLIPBOARD_SHARING" -eq 1 ]; then
    printf '  - clipboard sharing: enabled (installer prompt controlled, default: enabled)\n'
  else
    printf '  - clipboard sharing: disabled (installer prompt controlled, default: enabled)\n'
  fi
  if [ "$INSTALL_IS_WSL2" -eq 1 ]; then
    if [ "$ENABLE_NVIM_CLIPBOARD_SHARING" -eq 1 ]; then
      if [ "$ENABLE_WSL_HOST_CLIPBOARD" -eq 1 ]; then
        printf '  - WSL2 host clipboard bridge: enabled (installer prompt controlled, default: enabled)\n'
      else
        printf '  - WSL2 host clipboard bridge: disabled (installer prompt controlled, default: enabled)\n'
      fi
    else
      printf '  - WSL2 host clipboard bridge: skipped (nvim clipboard sharing disabled)\n'
    fi
  else
    printf '  - WSL2 host clipboard bridge: not applicable (WSL2 not detected)\n'
  fi
  printf '  - default IDE LSPs: bashls, jsonls, lua_ls, marksman, taplo, yamlls, ts_ls, rust_analyzer, gopls\n'
  if [ "$ENABLE_NVIM_IDE_PROFILE" -eq 1 ]; then
    if [ "$ENABLE_NVIM_FORMAT_ON_SAVE" -eq 1 ]; then
      printf '  - format on save: enabled (installer prompt controlled, default: enabled)\n'
    else
      printf '  - format on save: disabled (installer prompt controlled, default: enabled)\n'
      printf '  - note: manual format remains available via %b<leader>fm%b\n' "$C_NOTE" "$C_RESET"
    fi
    if [ "$PYTHON_FORMATTER_PREREQS_OK" -eq 1 ]; then
      printf '  - python formatting: prerequisites available (black/ruff via Mason)\n'
    else
      printf '  - python formatting: prerequisites missing (install python3 venv/pip support, then run :MasonToolsInstall)\n'
    fi
    if [ "$RUST_FORMATTER_PREREQS_OK" -eq 1 ]; then
      printf '  - rust formatting: prerequisite available (rustfmt)\n'
    else
      printf '  - rust formatting: prerequisite missing (install rustfmt)\n'
    fi
    if [ "$GO_FORMATTER_PREREQS_OK" -eq 1 ]; then
      printf '  - go formatting: prerequisite available (gofmt)\n'
    else
      printf '  - go formatting: prerequisite missing (install go/gofmt)\n'
    fi
  fi
  printf '  - theme: catppuccin (mocha)\n'
  printf '  - explorer: neo-tree sticky mode toggled with %b<leader>e%b; commands %b:NeoTUIExplorerEnable%b / %b:NeoTUIExplorerDisable%b / %b:NeoTUIExplorerToggle%b\n' "$C_KEYBIND" "$C_RESET" "$C_COMMAND" "$C_RESET" "$C_COMMAND" "$C_RESET" "$C_COMMAND" "$C_RESET"
  if [ "$ENABLE_NVIM_AI_PROMPT_INSERTION" -eq 1 ]; then
    printf '  - ai: run %b:Codeium Auth%b once in nvim to enable Codeium autocomplete\n' "$C_COMMAND" "$C_RESET"
    if [ "$ENABLE_NVIM_OPENCODE_PROMPT_ROUTING" -eq 1 ]; then
      printf '  - ai prompt default provider: OpenCode (installer prompt controlled, default: enabled)\n'
      printf '  - ai prompt auth: OpenCode via %bopencode auth login%b (provider/model routing), Codeium via %b:Codeium Auth%b\n' "$C_COMMAND" "$C_RESET" "$C_COMMAND" "$C_RESET"
    else
      printf '  - ai prompt default provider: Codeium (OpenCode routing disabled by installer choice)\n'
      printf '  - ai prompt auth: Codeium via %b:Codeium Auth%b; OpenCode optional via %bopencode auth login%b\n' "$C_COMMAND" "$C_RESET" "$C_COMMAND" "$C_RESET"
    fi
    printf '  - ai prompt switch: %b<leader>ap%b or %b:NeoTUIAIProvider%b\n' "$C_KEYBIND" "$C_RESET" "$C_COMMAND" "$C_RESET"
    printf '  - ai model switch: %b<leader>am%b or %b:NeoTUIAIModel%b (OpenCode models; Codeium stays auto/default)\n' "$C_KEYBIND" "$C_RESET" "$C_COMMAND" "$C_RESET"
  else
    printf '  - ai: run %b:Codeium Auth%b once in nvim to enable Codeium autocomplete\n' "$C_COMMAND" "$C_RESET"
  fi
  if [ "$ENABLE_NVIM_DEBUGGER" -eq 1 ]; then
    printf '  - debugger: enabled (nvim-dap + dap-ui + virtual-text; adapters via Mason)\n'
  else
    printf '  - debugger: disabled (installer prompt controlled, default: enabled)\n'
  fi
  printf '\n'
}

if [ ! -f "$SOURCE" ]; then
  printf 'Error: missing launcher at %s\n' "$SOURCE" >&2
  exit 1
fi

load_requirements
ensure_requirements

if detect_wsl2; then
  INSTALL_IS_WSL2=1
fi

prompt_nvim_ide_profile
prompt_nvim_format_on_save
prompt_nvim_ai_prompt_insertion
prompt_nvim_opencode_prompt_routing
prompt_nvim_debugger
prompt_nvim_clipboard_settings
ensure_formatter_prereqs

pkg_manager="$(detect_pkg_manager)"
install_optional_zsh_plugins "$pkg_manager"
install_optional_nvim_ide_tools "$pkg_manager"

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
