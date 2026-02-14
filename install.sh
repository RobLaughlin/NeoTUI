#!/usr/bin/env bash
# ============================================================
# NeoTUI - Installer
# Installs all dependencies and symlinks configurations
# ============================================================
set -euo pipefail

# Command-line flags
SKIP_UNSUPPORTED=0

for arg in "$@"; do
    case "$arg" in
        --skip-unsupported) SKIP_UNSUPPORTED=1 ;;
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
NC='\033[0m'

info()    { echo -e "${BLUE}>>>${NC} $*"; }
success() { echo -e "${GREEN} ✓${NC}  $*"; }
warn()    { echo -e "${YELLOW} !${NC}  $*"; }
error()   { echo -e "${RED} ✗${NC}  $*" >&2; }
header()  { echo -e "\n${BOLD}━━━ $* ━━━${NC}"; }

has() { command -v "$1" &>/dev/null; }

# Get architecture suffix for GitHub releases
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

# Get system architecture name for display
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
# Usage: install_from_github <cmd_name> <repo> <asset_grep_pattern> <binary_name>
install_from_github() {
    local cmd_name="$1" repo="$2" pattern="$3" bin_name="$4"

    if has "$cmd_name"; then
        success "$cmd_name already installed"
        return 0
    fi

    info "Installing $cmd_name from $repo..."
    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Fetch the latest release download URL matching pattern
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

    # Extract based on file type
    case "$url" in
        *.tar.gz|*.tgz) tar xzf "$tmp_dir/download" -C "$tmp_dir" ;;
        *.zip)          unzip -oq "$tmp_dir/download" -d "$tmp_dir" ;;
        *)              chmod +x "$tmp_dir/download"
                        cp "$tmp_dir/download" "$LOCAL_BIN/$bin_name"
                        rm -rf "$tmp_dir"
                        success "$cmd_name installed"
                        return 0 ;;
    esac

    # Find the binary in the extracted files
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

# ─── Neovim ──────────────────────────────────────────────────
install_neovim() {
    header "Neovim"
    if has nvim && nvim --version &>/dev/null; then
        success "Already installed: $(nvim --version | head -1)"
        return
    fi

    # Neovim 0.11+ requires glibc 2.32+. v0.10.4 is the newest release
    # that works on older systems (glibc 2.17+), maximizing compatibility.
    local nvim_version="v0.10.4"
    info "Installing Neovim $nvim_version (AppImage)..."

    curl -fL "https://github.com/neovim/neovim/releases/download/${nvim_version}/nvim-linux-x86_64.appimage" \
        -o "$LOCAL_BIN/nvim" || {
        # Fall back to older naming convention
        curl -fL "https://github.com/neovim/neovim/releases/download/${nvim_version}/nvim.appimage" \
            -o "$LOCAL_BIN/nvim" || {
            error "Failed to download Neovim"
            return 1
        }
    }
    chmod +x "$LOCAL_BIN/nvim"

    # Verify it works
    if "$LOCAL_BIN/nvim" --version &>/dev/null; then
        success "Neovim installed: $("$LOCAL_BIN/nvim" --version | head -1)"
    else
        error "Neovim binary downloaded but fails to run"
        rm -f "$LOCAL_BIN/nvim"
        return 1
    fi
}

# ─── zsh ─────────────────────────────────────────────────────
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

# ─── lf (file manager) ──────────────────────────────────────
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

# ─── fzf ─────────────────────────────────────────────────────
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

# ─── ripgrep ─────────────────────────────────────────────────
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

# ─── fd ──────────────────────────────────────────────────────
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

# ─── bat ─────────────────────────────────────────────────────
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

# ─── eza ─────────────────────────────────────────────────────
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

# ─── glow (markdown renderer) ────────────────────────────────
install_glow() {
    header "glow (markdown renderer)"
    if has glow; then
        success "Already installed"
        return
    fi

    if has go; then
        info "Installing glow via go install..."
        GOBIN="$LOCAL_BIN" go install github.com/charmbracelet/glow@latest
        success "glow installed"
    else
        error "Go not found - cannot install glow"
        return 1
    fi
}

# ─── go-grip (GitHub markdown preview) ───────────────────────
install_gogrip() {
    header "go-grip (GitHub markdown preview)"
    if has go-grip; then
        success "Already installed"
        return
    fi

    if has go; then
        info "Installing go-grip via go install..."
        GOBIN="$LOCAL_BIN" go install github.com/chrishrb/go-grip@latest
        success "go-grip installed"
    else
        error "Go not found - cannot install go-grip"
        return 1
    fi
}

# ─── carapace (shell completion) ─────────────────────────────
install_carapace() {
    header "carapace"
    install_from_github carapace carapace-sh/carapace-bin "linux_amd64.tar.gz" carapace
}

# ─── opencode ────────────────────────────────────────────────
install_opencode() {
    header "opencode"
    if has opencode; then
        success "Already installed: $(opencode --version 2>/dev/null || echo 'opencode')"
        return
    fi

    # Primary: npm with the correct package name
    if has npm; then
        info "Installing opencode via npm (opencode-ai@latest)..."
        npm install -g opencode-ai@latest 2>/dev/null && success "opencode installed" || {
            warn "npm install failed, trying curl installer..."
            curl -fsSL https://opencode.ai/install | bash && success "opencode installed" || warn "Could not install opencode, install manually"
        }
    # Fallback: official curl installer
    elif has curl; then
        info "Installing opencode via curl..."
        curl -fsSL https://opencode.ai/install | bash && success "opencode installed" || warn "Could not install opencode, install manually"
    else
        warn "Cannot install opencode (need npm or curl)"
    fi
}

# ─── claude code ────────────────────────────────────────────────
install_claude_code() {
    header "Claude Code"
    if has claude; then
        success "Already installed: $(claude --version 2>/dev/null || echo 'claude')"
        return
    fi

    if has curl; then
        info "Installing Claude Code via curl..."
        curl -fsSL https://claude.ai/install.sh | bash && success "Claude Code installed" || warn "Could not install Claude Code, install manually"
    else
        warn "Cannot install Claude Code (need curl)"
    fi
}

# ─── Symlink Configurations ─────────────────────────────────
symlink_configs() {
    header "Symlinking configurations"

    # tmux
    ln -sf "$NEOTUI_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
    success "tmux.conf -> ~/.tmux.conf"

    # Neovim
    rm -rf "$CONFIG_DIR/nvim"
    ln -sf "$NEOTUI_DIR/nvim" "$CONFIG_DIR/nvim"
    success "nvim/ -> ~/.config/nvim/"

    # lf
    mkdir -p "$CONFIG_DIR/lf"
    ln -sf "$NEOTUI_DIR/lf/lfrc" "$CONFIG_DIR/lf/lfrc"
    ln -sf "$NEOTUI_DIR/lf/preview.sh" "$CONFIG_DIR/lf/preview.sh"
    success "lf config -> ~/.config/lf/"

    # Launcher and helper scripts
    ln -sf "$NEOTUI_DIR/bin/neotui" "$LOCAL_BIN/neotui"
    ln -sf "$NEOTUI_DIR/bin/neotui-toggle-sidebar" "$LOCAL_BIN/neotui-toggle-sidebar"
    ln -sf "$NEOTUI_DIR/bin/neotui-new-window" "$LOCAL_BIN/neotui-new-window"
    success "bin scripts -> ~/.local/bin/"

    # Remove old tui-dev-env integration from .bashrc and .zshrc
    local old_marker="# >>> tui-dev-env >>>"
    local old_end="# <<< tui-dev-env <<<"
    if grep -q "$old_marker" "$HOME/.bashrc" 2>/dev/null; then
        sed -i "/$old_marker/,/$old_end/d" "$HOME/.bashrc"
        success "Removed old tui-dev-env block from ~/.bashrc"
    fi
    if grep -q "$old_marker" "$HOME/.zshrc" 2>/dev/null; then
        sed -i "/$old_marker/,/$old_end/d" "$HOME/.zshrc"
        success "Removed old tui-dev-env block from ~/.zshrc"
    fi

    # Shell integration in .zshrc
    local marker="# >>> neotui >>>"
    local end_marker="# <<< neotui <<<"
    if ! grep -q "$marker" "$HOME/.zshrc" 2>/dev/null; then
        cat >> "$HOME/.zshrc" << ZSHEOF

$marker
export NEOTUI_DIR="$NEOTUI_DIR"
export PATH="\$HOME/.local/bin:\$PATH"
source "$NEOTUI_DIR/shell/env.sh"
source "$NEOTUI_DIR/shell/vi-mode.sh"
source "$NEOTUI_DIR/shell/hooks.sh"
source "$NEOTUI_DIR/shell/aliases.sh"
# Plugins (syntax-highlighting must be last)
[[ -f "\$HOME/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && \\
    source "\$HOME/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "\$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && \\
    source "\$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
$end_marker
ZSHEOF
        success "Shell integration added to ~/.zshrc"
    else
        success "Shell integration already in ~/.zshrc"
    fi
}

# ─── Main ────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║          NeoTUI  -  Installer             ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    
    info "Architecture: $(get_arch_name)"
    [[ $SKIP_UNSUPPORTED -eq 1 ]] && info "Mode: --skip-unsupported enabled"
    echo ""

    local failures=0
    install_tmux      || ((failures++)) || true
    install_zsh       || ((failures++)) || true
    install_zsh_plugins || ((failures++)) || true
    install_go        || ((failures++)) || true
    install_neovim   || ((failures++)) || true
    install_lf       || ((failures++)) || true
    install_fzf      || ((failures++)) || true
    install_ripgrep  || ((failures++)) || true
    install_fd       || ((failures++)) || true
    install_bat      || ((failures++)) || true
    install_eza      || ((failures++)) || true
    install_glow     || ((failures++)) || true
    install_gogrip   || ((failures++)) || true
    install_carapace || ((failures++)) || true
    install_opencode || ((failures++)) || true
    install_claude_code || ((failures++)) || true
    symlink_configs

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
    echo "     (Windows Terminal: Settings > Profiles > Appearance > Font Face)"
    echo "     Recommended: JetBrainsMono Nerd Font"
    echo "     Download: https://www.nerdfonts.com/font-downloads"
    echo ""
    echo -e "  ${BOLD}2.${NC} Start a zsh shell (or launch neotui which uses zsh automatically):"
    echo "     zsh"
    echo ""
    echo -e "  ${BOLD}3.${NC} Launch the TUI environment:"
    echo "     neotui"
    echo ""
    echo -e "  ${BOLD}4.${NC} First launch of Neovim will auto-install plugins & LSP servers."
    echo "     Run 'nvim' and wait for installation to complete."
    echo ""
    echo -e "  ${BOLD}5.${NC} Set up AI autocompletion (Codeium / Windsurf — free):"
    echo "     a. Create a free account at ${BLUE}https://windsurf.com${NC}"
    echo "     b. Open Neovim:  nvim"
    echo "     c. Run:          :Codeium Auth"
    echo "     d. A browser window will open — sign in and copy the token"
    echo "     e. Paste the token back into Neovim"
    echo "     f. Done! AI ghost text suggestions will appear as you type."
    echo ""
    echo -e "  ${BOLD}Tip:${NC} Run ${GREEN}neotui -h${NC} or ${GREEN}neotui --help${NC} for a full keybinding reference."
    echo ""
}

main "$@"
