#!/usr/bin/env bash
# ============================================================
# NeoTUI - Installer
# Installs all dependencies and optionally integrates
# NeoTUI features into the user's global configs.
# ============================================================
set -euo pipefail

# ─── Command-line flags ──────────────────────────────────────
SKIP_UNSUPPORTED=0
YES_TO_ALL=0

for arg in "$@"; do
    case "$arg" in
        --skip-unsupported) SKIP_UNSUPPORTED=1 ;;
        --yes|-y)           YES_TO_ALL=1 ;;
    esac
done

NEOTUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$HOME/.local"
LOCAL_BIN="$LOCAL_DIR/bin"
CONFIG_DIR="$HOME/.config"

# ─── Colors & Helpers ────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${BLUE}>>>${NC} $*"; }
success() { echo -e "${GREEN} ✓${NC}  $*"; }
warn()    { echo -e "${YELLOW} !${NC}  $*"; }
error()   { echo -e "${RED} ✗${NC}  $*" >&2; }
header()  { echo -e "\n${BOLD}━━━ $* ━━━${NC}"; }

has() { command -v "$1" &>/dev/null; }

# ─── Interactive helpers ─────────────────────────────────────

# Ask a yes/no question. Default is the second arg (Y or N).
# Returns 0 for yes, 1 for no. Respects --yes flag.
ask_yes_no() {
    local prompt="$1"
    local default="${2:-Y}"

    if [[ $YES_TO_ALL -eq 1 ]]; then
        [[ "$default" == "Y" ]] && return 0 || return 1
    fi

    local suffix
    if [[ "$default" == "Y" ]]; then
        suffix="[Y/n]"
    else
        suffix="[y/N]"
    fi

    local answer
    echo -en "  ${prompt} ${suffix} " >/dev/tty
    read -r answer </dev/tty

    case "${answer:-$default}" in
        [Yy]*) return 0 ;;
        *)     return 1 ;;
    esac
}

# Backup a file or directory with a timestamped suffix
backup_if_exists() {
    local path="$1"
    if [[ -e "$path" ]] && [[ ! -L "$path" ]]; then
        local backup="${path}.bak.$(date +%Y%m%d%H%M%S)"
        cp -a "$path" "$backup"
        success "Backed up $(basename "$path") to $(basename "$backup")"
        return 0
    fi
    return 1
}

# Marker block helpers for config injection
MARKER_START="# >>> neotui >>>"
MARKER_END="# <<< neotui <<<"

# Check if a file already has NeoTUI marker blocks
has_neotui_block() {
    local file="$1"
    [[ -f "$file" ]] && grep -q "$MARKER_START" "$file" 2>/dev/null
}

# Remove existing NeoTUI marker block from a file
remove_neotui_block() {
    local file="$1"
    if has_neotui_block "$file"; then
        sed -i "/$MARKER_START/,/$MARKER_END/d" "$file"
    fi
}

# Append content inside marker blocks to a file
append_neotui_block() {
    local file="$1"
    local content="$2"
    remove_neotui_block "$file"
    {
        echo ""
        echo "$MARKER_START"
        echo "$content"
        echo "$MARKER_END"
    } >> "$file"
}

# ─── Architecture helpers ────────────────────────────────────

get_arch_suffix() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  echo "x86_64-unknown-linux-musl" ;;
        aarch64) echo "aarch64-unknown-linux-musl" ;;
        armv7l)  echo "armv7-unknown-linux-musleabihf" ;;
        *)       return 1 ;;
    esac
}

get_arch_name() {
    case "$(uname -m)" in
        x86_64)  echo "x86_64" ;;
        aarch64) echo "ARM64" ;;
        armv7l)  echo "ARMv7" ;;
        *)       echo "unknown" ;;
    esac
}

mkdir -p "$LOCAL_BIN" "$CONFIG_DIR"
export PATH="$LOCAL_BIN:$PATH"

# ─── Generic GitHub release installer ────────────────────────
install_from_github() {
    local cmd_name="$1" repo="$2" pattern="$3" bin_name="$4"

    if has "$cmd_name"; then
        success "$cmd_name already installed"
        return 0
    fi

    info "Installing $cmd_name from $repo..."
    local tmp_dir
    tmp_dir=$(mktemp -d)

    local url
    url=$(curl -sL "https://api.github.com/repos/${repo}/releases/latest" \
        | grep -o '"browser_download_url": *"[^"]*"' \
        | grep "$pattern" \
        | head -1 \
        | grep -o 'https://[^"]*') || true

    if [[ -z "$url" ]]; then
        warn "Could not find $cmd_name release (pattern: $pattern), skipping"
        rm -rf "$tmp_dir"
        return 1
    fi

    curl -sL "$url" -o "$tmp_dir/download"

    case "$url" in
        *.tar.gz|*.tgz) tar xzf "$tmp_dir/download" -C "$tmp_dir" ;;
        *.zip)          unzip -oq "$tmp_dir/download" -d "$tmp_dir" ;;
        *)              chmod +x "$tmp_dir/download"
                        cp "$tmp_dir/download" "$LOCAL_BIN/$bin_name"
                        rm -rf "$tmp_dir"
                        success "$cmd_name installed"
                        return 0 ;;
    esac

    local found
    found=$(find "$tmp_dir" -name "$bin_name" -type f 2>/dev/null | head -1)

    if [[ -n "$found" ]]; then
        install -m 755 "$found" "$LOCAL_BIN/$bin_name"
        success "$cmd_name installed"
    else
        warn "Binary '$bin_name' not found in archive for $cmd_name"
    fi

    rm -rf "$tmp_dir"
}

# ============================================================
# Phase 1: Install Tools
# ============================================================

install_neovim() {
    header "Neovim"
    if has nvim && nvim --version &>/dev/null; then
        success "Already installed: $(nvim --version | head -1)"
        return
    fi

    local nvim_version="v0.10.4"
    info "Installing Neovim $nvim_version (AppImage)..."

    curl -fL "https://github.com/neovim/neovim/releases/download/${nvim_version}/nvim-linux-x86_64.appimage" \
        -o "$LOCAL_BIN/nvim" || {
        curl -fL "https://github.com/neovim/neovim/releases/download/${nvim_version}/nvim.appimage" \
            -o "$LOCAL_BIN/nvim" || {
            error "Failed to download Neovim"
            return 1
        }
    }
    chmod +x "$LOCAL_BIN/nvim"

    if "$LOCAL_BIN/nvim" --version &>/dev/null; then
        success "Neovim installed: $("$LOCAL_BIN/nvim" --version | head -1)"
    else
        error "Neovim binary downloaded but fails to run"
        rm -f "$LOCAL_BIN/nvim"
        return 1
    fi
}

install_zsh() {
    header "zsh"
    if has zsh; then
        success "Already installed: $(zsh --version)"
        return
    fi

    info "Installing zsh (requires sudo)..."
    if has apt-get; then
        sudo apt-get update -qq && sudo apt-get install -y -qq zsh
    elif has dnf; then
        sudo dnf install -y -q zsh
    elif has pacman; then
        sudo pacman -S --noconfirm --needed zsh
    elif has apk; then
        sudo apk add --quiet zsh
    elif has zypper; then
        sudo zypper install -y -q zsh
    elif has brew; then
        brew install zsh
    else
        error "Could not detect package manager. Install zsh manually and re-run."
        return 1
    fi

    if has zsh; then
        success "zsh installed: $(zsh --version)"
    else
        error "zsh installation failed"
        return 1
    fi
}

install_tmux() {
    header "tmux"

    local min_major=3 min_minor=0

    if has tmux; then
        local version
        version=$(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -1)
        local major minor
        major=$(echo "$version" | cut -d. -f1)
        minor=$(echo "$version" | cut -d. -f2)

        if (( major > min_major )) || { (( major == min_major )) && (( minor >= min_minor )); }; then
            success "Already installed: $(tmux -V)"
            return 0
        else
            warn "tmux $version installed, but $min_major.$min_minor+ required"
            info "Upgrading tmux..."
        fi
    fi

    info "Installing tmux (requires sudo)..."
    if has apt-get; then
        sudo apt-get update -qq && sudo apt-get install -y -qq tmux
    elif has dnf; then
        sudo dnf install -y -q tmux
    elif has pacman; then
        sudo pacman -S --noconfirm --needed tmux
    elif has apk; then
        sudo apk add --quiet tmux
    elif has zypper; then
        sudo zypper install -y -q tmux
    elif has brew; then
        brew install tmux
    else
        error "Could not detect package manager. Install tmux 3.0+ manually and re-run."
        return 1
    fi

    if has tmux; then
        success "tmux installed: $(tmux -V)"
    else
        error "tmux installation failed"
        return 1
    fi
}

install_go() {
    header "Go"

    if has go; then
        success "Already installed: $(go version)"
        return 0
    fi

    local arch
    arch=$(uname -m)
    local goarch
    case "$arch" in
        x86_64)  goarch="amd64" ;;
        aarch64) goarch="arm64" ;;
        armv7l)  goarch="armv6l" ;;
        *)
            if [[ $SKIP_UNSUPPORTED -eq 1 ]]; then
                warn "Go: unsupported architecture $arch, skipping"
                return 0
            else
                error "Go: unsupported architecture $arch"
                error "Use --skip-unsupported to continue without Go"
                return 1
            fi
            ;;
    esac

    info "Installing Go for $arch to ~/.local/go..."
    local go_version="1.22.0"
    local url="https://go.dev/dl/go${go_version}.linux-${goarch}.tar.gz"

    local tmp_dir
    tmp_dir=$(mktemp -d)

    if curl -sL "$url" -o "$tmp_dir/go.tar.gz"; then
        mkdir -p "$HOME/.local"
        rm -rf "$HOME/.local/go"
        tar -C "$HOME/.local" -xzf "$tmp_dir/go.tar.gz"
        rm -rf "$tmp_dir"

        export PATH="$HOME/.local/go/bin:$PATH"
        export GOPATH="${GOPATH:-$HOME/go}"
        export PATH="$GOPATH/bin:$PATH"

        if has go; then
            success "Go installed: $(go version)"
        else
            error "Go installed but not in PATH"
            return 1
        fi
    else
        error "Failed to download Go"
        rm -rf "$tmp_dir"
        return 1
    fi
}

install_zsh_plugins() {
    header "zsh plugins (autosuggestions + syntax-highlighting)"
    local plugin_dir="$HOME/.local/share/zsh/plugins"
    mkdir -p "$plugin_dir"

    if [[ -d "$plugin_dir/zsh-autosuggestions" ]]; then
        success "zsh-autosuggestions already installed"
    else
        info "Installing zsh-autosuggestions..."
        git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
            "$plugin_dir/zsh-autosuggestions"
        success "zsh-autosuggestions installed"
    fi

    if [[ -d "$plugin_dir/zsh-syntax-highlighting" ]]; then
        success "zsh-syntax-highlighting already installed"
    else
        info "Installing zsh-syntax-highlighting..."
        git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
            "$plugin_dir/zsh-syntax-highlighting"
        success "zsh-syntax-highlighting installed"
    fi
}

install_lf() {
    header "lf (file manager)"
    if has lf; then
        success "Already installed"
        return
    fi

    if has go; then
        info "Installing lf via go install..."
        GOBIN="$LOCAL_BIN" go install github.com/gokcehan/lf@latest
        success "lf installed"
    else
        error "Go not found - cannot install lf"
        return 1
    fi
}

install_fzf() {
    header "fzf"
    if has fzf; then
        success "Already installed: $(fzf --version | head -1)"
        return
    fi

    info "Installing fzf..."
    if [[ -d "$HOME/.fzf" ]]; then
        rm -rf "$HOME/.fzf"
    fi
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --bin --no-update-rc --no-completion --no-key-bindings
    ln -sf "$HOME/.fzf/bin/fzf" "$LOCAL_BIN/fzf"
    success "fzf installed"
}

install_ripgrep() {
    header "ripgrep"
    local suffix
    if ! suffix=$(get_arch_suffix); then
        if [[ $SKIP_UNSUPPORTED -eq 1 ]]; then
            warn "ripgrep: $(uname -m) not supported, skipping"
            return 0
        else
            error "ripgrep: $(uname -m) not supported"
            error "Use --skip-unsupported to continue"
            return 1
        fi
    fi
    install_from_github rg BurntSushi/ripgrep "${suffix}.tar.gz" rg
}

install_fd() {
    header "fd"
    local suffix
    if ! suffix=$(get_arch_suffix); then
        if [[ $SKIP_UNSUPPORTED -eq 1 ]]; then
            warn "fd: $(uname -m) not supported, skipping"
            return 0
        else
            error "fd: $(uname -m) not supported"
            error "Use --skip-unsupported to continue"
            return 1
        fi
    fi
    install_from_github fd sharkdp/fd "${suffix}.tar.gz" fd
}

install_bat() {
    header "bat"
    local suffix
    if ! suffix=$(get_arch_suffix); then
        if [[ $SKIP_UNSUPPORTED -eq 1 ]]; then
            warn "bat: $(uname -m) not supported, skipping"
            return 0
        else
            error "bat: $(uname -m) not supported"
            error "Use --skip-unsupported to continue"
            return 1
        fi
    fi
    install_from_github bat sharkdp/bat "${suffix}.tar.gz" bat
}

install_eza() {
    header "eza"
    local arch
    arch=$(uname -m)
    local suffix
    case "$arch" in
        x86_64)  suffix="x86_64-unknown-linux-musl" ;;
        aarch64) suffix="aarch64-unknown-linux-musl" ;;
        *)
            if [[ $SKIP_UNSUPPORTED -eq 1 ]]; then
                warn "eza: $arch not supported, skipping"
                return 0
            else
                error "eza: $arch not supported"
                error "Use --skip-unsupported to continue"
                return 1
            fi
            ;;
    esac
    install_from_github eza eza-community/eza "${suffix}.tar.gz" eza
}

install_markdown_tools() {
    header "markdown tools (glow, go-grip)"
    
    if has glow && has go-grip; then
        success "Already installed: glow, go-grip"
        return 0
    fi

    if ask_yes_no "Install markdown preview tools (glow, go-grip)?" "Y"; then
        if has go; then
            if ! has glow; then
                info "Installing glow..."
                GOBIN="$LOCAL_BIN" go install github.com/charmbracelet/glow@latest && success "glow installed" || warn "Failed to install glow"
            fi
            if ! has go-grip; then
                info "Installing go-grip..."
                GOBIN="$LOCAL_BIN" go install github.com/chrishrb/go-grip@latest && success "go-grip installed" || warn "Failed to install go-grip"
            fi
        else
            warn "Go not found - cannot install markdown tools"
            return 1
        fi
    fi
}

install_carapace() {
    header "carapace"
    install_from_github carapace carapace-sh/carapace-bin "linux_amd64.tar.gz" carapace
}

install_prettier() {
    header "prettier"
    if has prettier; then
        success "Already installed: prettier $(prettier --version 2>/dev/null)"
        return
    fi

    if has npm; then
        info "Installing prettier via npm..."
        npm install -g prettier@latest 2>/dev/null && success "prettier installed" || {
            warn "Failed to install prettier via npm"
            return 1
        }
    else
        warn "Cannot install prettier (npm not found). Install Node.js/npm first."
        return 1
    fi
}

install_opencode() {
    header "opencode"
    if has opencode; then
        success "Already installed: $(opencode --version 2>/dev/null || echo 'opencode')"
        return 0
    fi

    if ask_yes_no "Install opencode (AI coding assistant)?" "Y"; then
        if has npm; then
            info "Installing opencode via npm..."
            npm install -g opencode-ai@latest 2>/dev/null && success "opencode installed" || warn "Failed to install opencode via npm"
        elif has curl; then
            info "Installing opencode via curl..."
            curl -fsSL https://opencode.ai/install | bash && success "opencode installed" || warn "Failed to install opencode"
        else
            warn "Cannot install opencode (need npm or curl)"
            return 1
        fi
    fi
}

install_claude_code() {
    header "Claude Code"
    if has claude; then
        success "Already installed: $(claude --version 2>/dev/null || echo 'claude')"
        return 0
    fi

    if ask_yes_no "Install Claude Code (AI coding assistant)?" "Y"; then
        if has curl; then
            info "Installing Claude Code..."
            curl -fsSL https://claude.ai/install.sh | bash && success "Claude Code installed" || warn "Failed to install Claude Code"
        else
            warn "Cannot install Claude Code (need curl)"
            return 1
        fi
    fi
}

# ============================================================
# Phase 2: NeoTUI Core Setup
# ============================================================

setup_neotui_core() {
    header "NeoTUI Core Setup"

    echo ""
    echo -e "  NeoTUI installs tools and configs to these locations:"
    echo -e "    ${DIM}~/.local/bin/${NC}             Tool binaries and NeoTUI scripts"
    echo -e "    ${DIM}~/.config/neotui/${NC}         NeoTUI's Neovim config (used inside neotui sessions)"
    echo -e "    ${DIM}~/.local/go/${NC}              Go runtime"
    echo -e "    ${DIM}~/.local/share/zsh/${NC}       Zsh plugins (autosuggestions, syntax-highlighting)"
    echo -e "    ${DIM}~/.fzf/${NC}                   fzf"
    echo ""
    echo -e "  These are self-contained and do not modify your existing configs."
    echo -e "  The ${BOLD}neotui${NC} command works fully without any changes to your"
    echo -e "  global shell, tmux, Neovim, or lf configuration."
    echo ""

    # Launcher and helper scripts
    ln -sf "$NEOTUI_DIR/bin/neotui" "$LOCAL_BIN/neotui"
    ln -sf "$NEOTUI_DIR/bin/neotui-toggle-sidebar" "$LOCAL_BIN/neotui-toggle-sidebar"
    ln -sf "$NEOTUI_DIR/bin/neotui-new-window" "$LOCAL_BIN/neotui-new-window"
    success "bin scripts -> ~/.local/bin/"

    # lf preview script (used as 'neotui-lf-preview' on PATH)
    ln -sf "$NEOTUI_DIR/lf/preview.sh" "$LOCAL_BIN/neotui-lf-preview"
    success "lf previewer -> ~/.local/bin/neotui-lf-preview"

    # Neovim config for NVIM_APPNAME=neotui (reads from ~/.config/neotui/)
    mkdir -p "$CONFIG_DIR"
    if [[ -L "$CONFIG_DIR/neotui" ]]; then
        rm -f "$CONFIG_DIR/neotui"
    fi
    ln -sf "$NEOTUI_DIR/nvim" "$CONFIG_DIR/neotui"
    success "nvim/ -> ~/.config/neotui/"

    # Remove old tui-dev-env integration from .bashrc and .zshrc
    local old_marker="# >>> tui-dev-env >>>"
    local old_end="# <<< tui-dev-env <<<"
    if grep -q "$old_marker" "$HOME/.bashrc" 2>/dev/null; then
        sed -i "/$old_marker/,/$old_end/d" "$HOME/.bashrc"
        success "Removed old tui-dev-env block from ~/.bashrc"
    fi
    if [[ -f "$HOME/.zshrc" ]] && grep -q "$old_marker" "$HOME/.zshrc" 2>/dev/null; then
        sed -i "/$old_marker/,/$old_end/d" "$HOME/.zshrc"
        success "Removed old tui-dev-env block from ~/.zshrc"
    fi
}

# ============================================================
# Phase 3: LSP Server Selection
# ============================================================

select_lsp_servers() {
    header "LSP Server Selection"
    echo ""
    info "NeoTUI's Neovim config includes LSP support via Mason."
    info "Which language servers would you like installed on first launch?"
    echo ""

    local selected_servers=()

    local -A lsp_map=(
        ["gopls"]="Go"
        ["pyright"]="Python"
        ["ts_ls"]="TypeScript/JavaScript"
        ["bashls"]="Bash"
        ["clangd"]="C/C++"
        ["lua_ls"]="Lua"
        ["intelephense"]="PHP"
    )

    # Ordered list to maintain consistent prompting order
    local lsp_order=("gopls" "pyright" "ts_ls" "bashls" "clangd" "lua_ls" "intelephense")

    for server in "${lsp_order[@]}"; do
        local lang="${lsp_map[$server]}"
        if ask_yes_no "Install ${server} (${lang})?" "Y"; then
            selected_servers+=("$server")
        fi
    done

    # Write the selection to the NeoTUI nvim config directory
    local config_file="$CONFIG_DIR/neotui/neotui_lsp_servers.lua"
    {
        echo "-- Generated by NeoTUI installer"
        echo "-- Edit this file to change which LSP servers are auto-installed"
        echo "return {"
        for server in "${selected_servers[@]}"; do
            echo "  \"${server}\","
        done
        echo "}"
    } > "$config_file"

    success "LSP selection saved (${#selected_servers[@]} servers)"
}

# ============================================================
# Phase 4: Global Config Integration (optional)
# ============================================================

# ─── tmux config ─────────────────────────────────────────────

# Extract bound keys from a tmux config file
get_tmux_binds() {
    local file="$1"
    [[ -f "$file" ]] || return
    # Match lines like: bind X ..., bind-key X ..., bind -r X ...
    grep -E '^\s*bind(-key)?\s' "$file" 2>/dev/null | \
        sed 's/.*bind\(-key\)\?\s\+//' | \
        sed 's/^-r\s\+//' | \
        sed 's/^-T\s\+\S\+\s\+//' | \
        awk '{print $1}' | \
        sort -u || true
}

configure_tmux() {
    echo ""
    echo -e "  ${BOLD}─── tmux (~/.tmux.conf) ───${NC}"
    echo ""

    local tmux_conf="$HOME/.tmux.conf"

    # Create default config if none exists
    if [[ ! -f "$tmux_conf" ]]; then
        if ask_yes_no "No tmux config found. Create a default config?" "Y"; then
            cat > "$tmux_conf" << 'EOF'
# tmux configuration
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g history-limit 50000
set -g escape-time 10
set -g focus-events on
set -g set-clipboard on
EOF
            success "Created default ~/.tmux.conf"
        else
            info "Skipping tmux configuration"
            return
        fi
    fi

    # Collect all additions into one block, then write once at the end
    local tmux_additions=""

    # Check for keybind conflicts
    local existing_binds
    existing_binds=$(get_tmux_binds "$tmux_conf")

    # NeoTUI-specific keybinds to offer
    local -A neotui_binds=(
        ["E"]="Toggle file explorer sidebar"
        ["T"]="Toggle tab bar"
        ["v"]="Open Neovim in current directory"
        ["O"]="Open opencode (split below)"
        ["C"]="Open Claude Code (split below)"
        ["c"]="New window with lf sidebar"
    )
    local bind_order=("E" "T" "v" "O" "C" "c")

    local conflicts=()
    local available=()
    for key in "${bind_order[@]}"; do
        if echo "$existing_binds" | grep -qxF "$key"; then
            conflicts+=("$key")
        else
            available+=("$key")
        fi
    done

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        warn "Keybind conflicts detected (these will be preserved):"
        for key in "${conflicts[@]}"; do
            echo -e "    ${YELLOW}prefix+${key}${NC} is already bound in your config"
        done
    fi

    if [[ ${#available[@]} -gt 0 ]]; then
        echo ""
        echo "  The following NeoTUI keybinds are available:"
        for key in "${available[@]}"; do
            printf "    ${GREEN}prefix+%-4s${NC} %s\n" "$key" "${neotui_binds[$key]}"
        done
        echo ""

        if ask_yes_no "Add these keybinds to ~/.tmux.conf?" "Y"; then
            tmux_additions+="# NeoTUI keybinds"$'\n'
            for key in "${available[@]}"; do
                case "$key" in
                    E) tmux_additions+="bind E run-shell 'neotui-toggle-sidebar'"$'\n' ;;
                    T) tmux_additions+="bind T set -g status"$'\n' ;;
                    v) tmux_additions+="bind v send-keys 'nvim .' Enter"$'\n' ;;
                    O) tmux_additions+='bind O split-window -v -c "#{pane_current_path}" '"'"'opencode || zsh'"'"$'\n' ;;
                    C) tmux_additions+='bind C split-window -v -c "#{pane_current_path}" '"'"'claude || zsh'"'"$'\n' ;;
                    c) tmux_additions+="bind c run-shell 'neotui-new-window'"$'\n' ;;
                esac
            done
            success "NeoTUI keybinds will be added"
        fi
    fi

    # Vi-style pane navigation
    echo ""
    if ask_yes_no "Enable vi-style pane navigation (h/j/k/l)?" "Y"; then
        local has_vim_nav=0
        if echo "$existing_binds" | grep -qxF "h" && \
           echo "$existing_binds" | grep -qxF "j"; then
            has_vim_nav=1
        fi

        if [[ $has_vim_nav -eq 0 ]]; then
            tmux_additions+="# Vi-style pane navigation"$'\n'
            tmux_additions+="bind h select-pane -L"$'\n'
            tmux_additions+="bind j select-pane -D"$'\n'
            tmux_additions+="bind k select-pane -U"$'\n'
            tmux_additions+="bind l select-pane -R"$'\n'
            tmux_additions+="bind -r H resize-pane -L 5"$'\n'
            tmux_additions+="bind -r J resize-pane -D 5"$'\n'
            tmux_additions+="bind -r K resize-pane -U 5"$'\n'
            tmux_additions+="bind -r L resize-pane -R 5"$'\n'
            success "Vi-style pane navigation will be added"
        else
            info "h/j/k/l pane navigation already configured"
        fi
    fi

    # Status bar
    echo ""
    if ! grep -qE '^\s*set\s+(-g\s+)?status-style' "$tmux_conf" 2>/dev/null && \
       ! grep -qE '^\s*set\s+(-g\s+)?status-left' "$tmux_conf" 2>/dev/null; then
        if ask_yes_no "Your tmux config doesn't have a status bar. Add one?" "Y"; then
            tmux_additions+="# Status bar (Catppuccin Mocha theme)"$'\n'
            tmux_additions+="set -g status-position top"$'\n'
            tmux_additions+="set -g status-interval 5"$'\n'
            tmux_additions+="set -g status-justify left"$'\n'
            tmux_additions+="set -g status-style 'bg=#1e1e2e,fg=#cdd6f4'"$'\n'
            tmux_additions+="set -g status-left-length 30"$'\n'
            tmux_additions+="set -g status-left '#[bg=#89b4fa,fg=#1e1e2e,bold]  #S #[bg=#1e1e2e,fg=#89b4fa] '"$'\n'
            tmux_additions+="set -g status-right-length 60"$'\n'
            tmux_additions+="set -g status-right '#[fg=#585b70]│ #[fg=#a6adc8]%Y-%m-%d #[fg=#585b70]│ #[fg=#cdd6f4,bold]%H:%M #[fg=#585b70]│ #[fg=#89b4fa]#h '"$'\n'
            tmux_additions+="set -g window-status-format '#[fg=#585b70]  #I #W  '"$'\n'
            tmux_additions+="set -g window-status-current-format '#[fg=#89b4fa,bg=#313244,bold]  #I #W  #[bg=#1e1e2e,fg=#313244]'"$'\n'
            tmux_additions+="set -g window-status-separator ''"$'\n'
            tmux_additions+="set -g pane-border-style 'fg=#313244'"$'\n'
            tmux_additions+="set -g pane-active-border-style 'fg=#89b4fa'"$'\n'
            tmux_additions+="set -g message-style 'bg=#313244,fg=#cdd6f4'"$'\n'
            success "Status bar will be added"
        fi
    else
        info "Status bar already configured"
    fi

    # Default shell
    echo ""
    if ask_yes_no "Set zsh as the default shell inside tmux panes?" "Y"; then
        if ! grep -q "default-shell" "$tmux_conf" 2>/dev/null; then
            tmux_additions+="# Default shell"$'\n'
            tmux_additions+='run-shell "command -v zsh >/dev/null && tmux set-option -g default-shell \"$(command -v zsh)\" || true"'$'\n'
            success "zsh will be set as default tmux shell"
        else
            info "Default shell already configured in tmux"
        fi
    fi

    # Write all additions at once
    if [[ -n "$tmux_additions" ]]; then
        append_neotui_block "$tmux_conf" "$tmux_additions"
        success "All tmux changes written to ~/.tmux.conf"
    fi
}

# ─── Neovim config ───────────────────────────────────────────

configure_neovim() {
    echo ""
    echo -e "  ${BOLD}─── Neovim (~/.config/nvim/) ───${NC}"
    echo ""

    local nvim_config="$CONFIG_DIR/nvim"

    if [[ ! -d "$nvim_config" ]] || \
       { [[ ! -f "$nvim_config/init.lua" ]] && [[ ! -f "$nvim_config/init.vim" ]]; }; then
        # No existing Neovim config
        if ask_yes_no "No Neovim config found. Use NeoTUI's config as your global default?" "Y"; then
            if [[ -d "$nvim_config" ]] && [[ ! -L "$nvim_config" ]]; then
                backup_if_exists "$nvim_config"
                rm -rf "$nvim_config"
            elif [[ -L "$nvim_config" ]]; then
                rm -f "$nvim_config"
            fi
            ln -sf "$NEOTUI_DIR/nvim" "$nvim_config"
            success "~/.config/nvim/ -> NeoTUI config"
        fi
    else
        # Existing Neovim config
        info "Existing Neovim config found at ~/.config/nvim/"
        info "NeoTUI's Neovim config is available inside neotui sessions"
        info "automatically (via NVIM_APPNAME). No changes needed."
    fi
}

# ─── lf config ───────────────────────────────────────────────

# Extract mapped keys from an lf config file
get_lf_maps() {
    local file="$1"
    [[ -f "$file" ]] || return
    grep -E '^\s*map\s' "$file" 2>/dev/null | awk '{print $2}' | sort -u || true
}

configure_lf() {
    echo ""
    echo -e "  ${BOLD}─── lf (~/.config/lf/) ───${NC}"
    echo ""

    local lf_config_dir="$CONFIG_DIR/lf"
    local lf_config="$lf_config_dir/lfrc"

    if [[ ! -f "$lf_config" ]]; then
        # No existing lf config
        if ask_yes_no "No lf config found. Use NeoTUI's config as your default?" "Y"; then
            mkdir -p "$lf_config_dir"
            if [[ -L "$lf_config" ]]; then
                rm -f "$lf_config"
            fi
            ln -sf "$NEOTUI_DIR/lf/lfrc" "$lf_config"
            ln -sf "$NEOTUI_DIR/lf/preview.sh" "$lf_config_dir/preview.sh"
            success "~/.config/lf/ -> NeoTUI config"
        fi
        return
    fi

    # Existing lf config — offer individual features
    local existing_maps
    existing_maps=$(get_lf_maps "$lf_config")
    local lf_additions=""

    # sync-shell command
    if ! grep -q "cmd sync-shell" "$lf_config" 2>/dev/null; then
        echo ""
        if ask_yes_no "Add sync-shell command (S key)? Syncs an idle shell pane to lf's directory." "Y"; then
            lf_additions+=$(cat << 'LFEOF'

# NeoTUI: sync shell pane to lf's current directory
cmd sync-shell &{{
    [ -z "${TMUX:-}" ] && exit 0
    pane_id=""
    for entry in $(tmux list-panes -F '#{pane_pid}:#{pane_id}:#{pane_current_command}'); do
        p_pid=$(echo "$entry" | cut -d: -f1)
        p_id=$(echo "$entry" | cut -d: -f2)
        p_cmd=$(echo "$entry" | cut -d: -f3)
        case "$p_cmd" in
            zsh|bash|sh|fish)
                child=$(ps --ppid "$p_pid" -o comm= 2>/dev/null | head -1)
                if [ -z "$child" ]; then
                    pane_id="$p_id"
                    break
                fi
                ;;
        esac
    done
    if [ -z "$pane_id" ]; then
        lf -remote "send $id echo 'No idle shell pane found'"
        exit 0
    fi
    escaped=$(printf '%s' "$PWD" | sed "s/'/'\\\\''/g")
    tmux send-keys -t "$pane_id" C-u
    tmux send-keys -t "$pane_id" "cd '${escaped}'" Enter
    lf -remote "send $id echo 'Shell → $PWD'"
}}
map S sync-shell
LFEOF
)
        fi
    fi

    # open command
    if ! grep -q "cmd open" "$lf_config" 2>/dev/null; then
        echo ""
        if ask_yes_no "Add open command (Enter key)? Opens text files in Neovim via tmux pane." "Y"; then
            lf_additions+=$'\n'"map <enter> open"$'\n'"map o open"
        fi
    fi

    # open-tab command
    if ! grep -q "cmd open-tab" "$lf_config" 2>/dev/null; then
        echo ""
        if ask_yes_no "Add open-tab command (Shift+Enter / O key)? Opens text files in a new tmux window." "Y"; then
            lf_additions+=$'\n'"map <s-enter> open-tab"$'\n'"map O open-tab"
        fi
    fi

    # toggle-preview command
    if ! grep -q "cmd toggle-preview" "$lf_config" 2>/dev/null; then
        echo ""
        if ask_yes_no "Add toggle-preview command (zp key)? Toggles a file preview pane on/off." "Y"; then
            lf_additions+=$(cat << 'LFEOF'

# NeoTUI: toggle preview pane
cmd toggle-preview &{{
    if [ -f /tmp/lf-preview-on ]; then
        rm -f /tmp/lf-preview-on
        lf -remote "send $id set nopreview"
        lf -remote "send $id set ratios 1"
    else
        touch /tmp/lf-preview-on
        lf -remote "send $id set ratios 2:3"
        lf -remote "send $id set preview"
    fi
}}
map zp toggle-preview
LFEOF
)
        fi
    fi

    # Navigation shortcuts
    local nav_shortcuts=("gh" "gp" "gd" "gD" "g/")
    local nav_targets=("~" "~/projects" "~/Documents" "~/Downloads" "/")
    local nav_conflicts=()
    local nav_available=()

    for i in "${!nav_shortcuts[@]}"; do
        local shortcut="${nav_shortcuts[$i]}"
        if echo "$existing_maps" | grep -qxF "$shortcut"; then
            nav_conflicts+=("$shortcut")
        else
            nav_available+=("$shortcut")
        fi
    done

    if [[ ${#nav_conflicts[@]} -gt 0 ]]; then
        echo ""
        warn "Navigation shortcut conflicts detected:"
        for shortcut in "${nav_conflicts[@]}"; do
            echo -e "    ${YELLOW}${shortcut}${NC} is already mapped in your config"
        done
        info "Your existing mappings will be preserved."
    fi

    if [[ ${#nav_available[@]} -gt 0 ]]; then
        echo ""
        echo "  Navigation shortcuts available:"
        for i in "${!nav_shortcuts[@]}"; do
            local shortcut="${nav_shortcuts[$i]}"
            local target="${nav_targets[$i]}"
            # Only show available ones
            for avail in "${nav_available[@]}"; do
                if [[ "$shortcut" == "$avail" ]]; then
                    printf "    ${GREEN}%-4s${NC} -> %s\n" "$shortcut" "$target"
                fi
            done
        done
        echo ""

        if ask_yes_no "Add these navigation shortcuts?" "Y"; then
            lf_additions+=$'\n'"# NeoTUI: navigation shortcuts"
            for i in "${!nav_shortcuts[@]}"; do
                local shortcut="${nav_shortcuts[$i]}"
                local target="${nav_targets[$i]}"
                for avail in "${nav_available[@]}"; do
                    if [[ "$shortcut" == "$avail" ]]; then
                        lf_additions+=$'\n'"map $shortcut cd $target"
                    fi
                done
            done
        fi
    fi

    # Write all additions if any
    if [[ -n "$lf_additions" ]]; then
        append_neotui_block "$lf_config" "$lf_additions"
        success "lf features added to ~/.config/lf/lfrc"
    fi
}

# ─── zsh config ──────────────────────────────────────────────

configure_zsh() {
    echo ""
    echo -e "  ${BOLD}─── zsh (~/.zshrc) ───${NC}"
    echo ""

    local zshrc="$HOME/.zshrc"

    # Create .zshrc if it doesn't exist
    if [[ ! -f "$zshrc" ]]; then
        touch "$zshrc"
    fi

    local zsh_additions=""

    # vi-mode
    if ! grep -qE 'bindkey\s+-v' "$zshrc" 2>/dev/null; then
        if ask_yes_no "Enable vi-mode for zsh? (beam cursor in insert, block in normal)" "Y"; then
            zsh_additions+=$'\n'"# Vi-mode"
            zsh_additions+=$'\n'"bindkey -v"
            zsh_additions+=$'\n'"export KEYTIMEOUT=10"
        fi
    else
        info "vi-mode already enabled"
    fi

    # Persistent history (required for autosuggestions across sessions)
    echo ""
    local neotui_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/neotui"
    local history_conf="$neotui_config_dir/history.conf"
    if [[ -f "$history_conf" ]]; then
        info "Persistent history already configured"
    else
        if ask_yes_no "Enable persistent command history? (required for autosuggestions to remember commands across sessions)" "Y"; then
            mkdir -p "$neotui_config_dir"
            echo "# NeoTUI: persistent history configuration" > "$history_conf"
            echo "# This file is sourced by NeoTUI's shell wrapper" >> "$history_conf"
            echo "NEOTUI_HISTFILE=\"\$HOME/.zsh_history\"" >> "$history_conf"
            success "Persistent history enabled"
        fi
    fi

    # NeoTUI prompt
    echo ""
    if ask_yes_no "Use the NeoTUI prompt? ([HH:MM] ~/path (branch) >)" "Y"; then
        zsh_additions+=$'\n'"# NeoTUI prompt"
        zsh_additions+=$'\n'"autoload -Uz vcs_info"
        zsh_additions+=$'\n'"zstyle ':vcs_info:git:*' formats ' (%b)'"
        zsh_additions+=$'\n'"zstyle ':vcs_info:*' enable git"
        zsh_additions+=$'\n'"_neotui_precmd_vcs() { vcs_info }"
        zsh_additions+=$'\n'"autoload -Uz add-zsh-hook"
        zsh_additions+=$'\n'"add-zsh-hook precmd _neotui_precmd_vcs"
        zsh_additions+=$'\n'"setopt PROMPT_SUBST"
        zsh_additions+=$'\n'"PROMPT='%F{243}[%D{%H:%M}]%f %F{39}%~%f%F{45}\${vcs_info_msg_0_}%f %(?.%F{51}.%F{red})>%f '"
    fi

    # carapace
    echo ""
    if ! grep -q 'carapace' "$zshrc" 2>/dev/null; then
        if has carapace && ask_yes_no "Enable carapace shell completion?" "Y"; then
            zsh_additions+=$'\n'"# Carapace shell completion"
            zsh_additions+=$'\n'"source <(carapace _carapace zsh)"
        fi
    else
        info "carapace already configured"
    fi

    # EDITOR
    echo ""
    if ! grep -qE 'export\s+EDITOR.*nvim' "$zshrc" 2>/dev/null; then
        if ask_yes_no "Set EDITOR to nvim?" "Y"; then
            zsh_additions+=$'\n'"# Editor"
            zsh_additions+=$'\n'"export EDITOR=\"nvim\""
            zsh_additions+=$'\n'"export VISUAL=\"nvim\""
        fi
    else
        info "EDITOR already set to nvim"
    fi

    # zsh-autosuggestions
    echo ""
    local plugin_dir="$HOME/.local/share/zsh/plugins"
    if ! grep -q 'zsh-autosuggestions' "$zshrc" 2>/dev/null; then
        if [[ -d "$plugin_dir/zsh-autosuggestions" ]]; then
            if ask_yes_no "Enable zsh-autosuggestions? (suggests commands as you type)" "Y"; then
                zsh_additions+=$'\n'"# zsh-autosuggestions"
                zsh_additions+=$'\n'"[[ -f \"$plugin_dir/zsh-autosuggestions/zsh-autosuggestions.zsh\" ]] && \\"
                zsh_additions+=$'\n'"    source \"$plugin_dir/zsh-autosuggestions/zsh-autosuggestions.zsh\""
            fi
        fi
    else
        info "zsh-autosuggestions already enabled"
    fi

    # zsh-syntax-highlighting (must be last)
    echo ""
    if ! grep -q 'zsh-syntax-highlighting' "$zshrc" 2>/dev/null; then
        if [[ -d "$plugin_dir/zsh-syntax-highlighting" ]]; then
            if ask_yes_no "Enable zsh-syntax-highlighting? (colors valid/invalid commands)" "Y"; then
                zsh_additions+=$'\n'"# zsh-syntax-highlighting (must be sourced last)"
                zsh_additions+=$'\n'"[[ -f \"$plugin_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh\" ]] && \\"
                zsh_additions+=$'\n'"    source \"$plugin_dir/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh\""
            fi
        fi
    else
        info "zsh-syntax-highlighting already enabled"
    fi

    # sync command
    echo ""
    if ! grep -q 'sync()' "$zshrc" 2>/dev/null && \
       ! grep -q 'function sync' "$zshrc" 2>/dev/null; then
        if ask_yes_no "Add 'sync' command? (syncs lf sidebar to shell directory)" "Y"; then
            zsh_additions+=$'\n'"# NeoTUI: sync lf sidebar to shell directory"
            zsh_additions+=$'\n'"sync() {"
            zsh_additions+=$'\n'"    if [[ -n \"\${TMUX:-}\" ]] && command -v lf &>/dev/null; then"
            zsh_additions+=$'\n'"        lf -remote \"send :cd '\$PWD'; reload\" 2>/dev/null && echo \"lf → \$PWD\""
            zsh_additions+=$'\n'"    else"
            zsh_additions+=$'\n'"        echo \"Not in a tmux session or lf not installed\""
            zsh_additions+=$'\n'"    fi"
            zsh_additions+=$'\n'"}"
        fi
    else
        info "sync command already defined"
    fi

    # PATH
    echo ""
    if ! grep -qE 'PATH.*\.local/bin' "$zshrc" 2>/dev/null; then
        if ask_yes_no "Add ~/.local/bin to your PATH?" "Y"; then
            zsh_additions+=$'\n'"# PATH"
            zsh_additions+=$'\n'"export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    else
        info "~/.local/bin already in PATH"
    fi

    # Write all additions if any
    if [[ -n "$zsh_additions" ]]; then
        append_neotui_block "$zshrc" "$zsh_additions"
        success "Shell features added to ~/.zshrc"
    fi
}

# ============================================================
# Main
# ============================================================

main() {
    echo -e "${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║          NeoTUI  -  Installer            ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"

    info "Architecture: $(get_arch_name)"
    [[ $SKIP_UNSUPPORTED -eq 1 ]] && info "Mode: --skip-unsupported enabled"
    [[ $YES_TO_ALL -eq 1 ]] && info "Mode: --yes (accepting all defaults)"
    echo ""

    # ─── Phase 1: Install tools ──────────────────────────────
    header "Phase 1: Installing Tools"

    local failures=0
    install_tmux      || ((failures++)) || true
    install_zsh       || ((failures++)) || true
    install_go        || ((failures++)) || true
    install_neovim    || ((failures++)) || true
    install_lf        || ((failures++)) || true
    install_fzf       || ((failures++)) || true
    install_ripgrep   || ((failures++)) || true
    install_fd        || ((failures++)) || true
    install_bat       || ((failures++)) || true
    install_eza           || ((failures++)) || true
    install_markdown_tools || ((failures++)) || true
    install_carapace      || ((failures++)) || true
    install_prettier      || ((failures++)) || true
    install_opencode      || ((failures++)) || true
    install_claude_code   || ((failures++)) || true
    install_zsh_plugins   || ((failures++)) || true

    # ─── Phase 2: Core setup ─────────────────────────────────
    setup_neotui_core

    # ─── Phase 3: LSP selection ──────────────────────────────
    select_lsp_servers

    # ─── Phase 4: Global config integration ──────────────────
    header "Phase 4: Global Config Integration (optional)"
    echo ""
    echo -e "  The following questions are about adding NeoTUI features to your"
    echo -e "  global configs (~/.tmux.conf, ~/.zshrc, ~/.config/nvim/, ~/.config/lf/)."
    echo -e "  You can skip all of these — NeoTUI works without them."
    echo ""

    if ask_yes_no "Skip global config integration entirely?" "N"; then
        info "Skipping global config integration"
    else
        configure_tmux
        configure_neovim
        configure_lf
        configure_zsh
    fi

    # ─── Done ────────────────────────────────────────────────
    if [[ $failures -gt 0 ]]; then
        header "Installation Complete (with $failures warning(s))"
        warn "Some tools failed to install. You can re-run ./install.sh to retry."
    else
        header "Installation Complete"
    fi
    echo ""
    echo -e "  ${BOLD}Next steps:${NC}"
    echo ""
    echo -e "  ${BOLD}1.${NC} Install a Nerd Font in your terminal emulator"
    echo "     Recommended: JetBrainsMono Nerd Font"
    echo "     Download: https://www.nerdfonts.com/font-downloads"
    echo ""
    echo -e "  ${BOLD}2.${NC} Launch NeoTUI:"
    echo "     neotui"
    echo ""
    echo -e "  ${BOLD}3.${NC} First launch of Neovim will auto-install plugins & LSP servers."
    echo "     Open neovim inside a neotui session and wait for installation."
    echo ""
    echo -e "  ${BOLD}4.${NC} Set up AI autocompletion (Codeium / Windsurf — free):"
    echo "     a. Create a free account at https://windsurf.com"
    echo "     b. Inside neotui, open Neovim"
    echo "     c. Run:  :Codeium Auth"
    echo "     d. Sign in via browser, paste the token back into Neovim"
    echo ""
    echo -e "  ${BOLD}Tip:${NC} Run ${GREEN}neotui -h${NC} for a keybinding reference."
    echo ""
}

main "$@"
