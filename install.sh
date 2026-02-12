#!/usr/bin/env bash
# ============================================================
# TUI Dev Environment - Installer
# Installs all dependencies and symlinks configurations
# ============================================================
set -euo pipefail

TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

    # Ubuntu 20.04 has glibc 2.31. Neovim 0.11+ requires glibc 2.32+.
    # v0.10.4 is the newest version with glibc 2.31 support (AppImage).
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
        success "zsh installed: $(zsh --version)"
    else
        error "Could not install zsh (apt-get not found). Install manually."
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
    install_from_github rg BurntSushi/ripgrep "x86_64-unknown-linux-musl.tar.gz" rg
}

# ─── fd ──────────────────────────────────────────────────────
install_fd() {
    header "fd"
    install_from_github fd sharkdp/fd "x86_64-unknown-linux-musl.tar.gz" fd
}

# ─── bat ─────────────────────────────────────────────────────
install_bat() {
    header "bat"
    install_from_github bat sharkdp/bat "x86_64-unknown-linux-musl.tar.gz" bat
}

# ─── eza ─────────────────────────────────────────────────────
install_eza() {
    header "eza"
    install_from_github eza eza-community/eza "x86_64-unknown-linux-musl.tar.gz" eza
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

# ─── Symlink Configurations ─────────────────────────────────
symlink_configs() {
    header "Symlinking configurations"

    # tmux
    ln -sf "$TUI_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
    success "tmux.conf -> ~/.tmux.conf"

    # Neovim
    rm -rf "$CONFIG_DIR/nvim"
    ln -sf "$TUI_DIR/nvim" "$CONFIG_DIR/nvim"
    success "nvim/ -> ~/.config/nvim/"

    # lf
    mkdir -p "$CONFIG_DIR/lf"
    ln -sf "$TUI_DIR/lf/lfrc" "$CONFIG_DIR/lf/lfrc"
    ln -sf "$TUI_DIR/lf/preview.sh" "$CONFIG_DIR/lf/preview.sh"
    success "lf config -> ~/.config/lf/"

    # Launcher and helper scripts
    ln -sf "$TUI_DIR/bin/tui" "$LOCAL_BIN/tui"
    ln -sf "$TUI_DIR/bin/tui-toggle-sidebar" "$LOCAL_BIN/tui-toggle-sidebar"
    ln -sf "$TUI_DIR/bin/tui-new-window" "$LOCAL_BIN/tui-new-window"
    success "bin scripts -> ~/.local/bin/"

    # Remove old bash integration (shell configs are now zsh-specific)
    local marker="# >>> tui-dev-env >>>"
    local end_marker="# <<< tui-dev-env <<<"
    if grep -q "$marker" "$HOME/.bashrc" 2>/dev/null; then
        sed -i "/$marker/,/$end_marker/d" "$HOME/.bashrc"
        success "Removed old bash integration from ~/.bashrc"
    fi

    # Shell integration in .zshrc
    if ! grep -q "$marker" "$HOME/.zshrc" 2>/dev/null; then
        cat >> "$HOME/.zshrc" << ZSHEOF

$marker
export TUI_DIR="$TUI_DIR"
export PATH="\$HOME/.local/bin:\$PATH"
source "$TUI_DIR/shell/env.sh"
source "$TUI_DIR/shell/vi-mode.sh"
source "$TUI_DIR/shell/hooks.sh"
source "$TUI_DIR/shell/aliases.sh"
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
    echo "║     TUI Dev Environment - Installer      ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"

    local failures=0
    install_zsh      || ((failures++)) || true
    install_zsh_plugins || ((failures++)) || true
    install_neovim   || ((failures++)) || true
    install_lf       || ((failures++)) || true
    install_fzf      || ((failures++)) || true
    install_ripgrep  || ((failures++)) || true
    install_fd       || ((failures++)) || true
    install_bat      || ((failures++)) || true
    install_eza      || ((failures++)) || true
    install_glow     || ((failures++)) || true
    install_carapace || ((failures++)) || true
    install_opencode || ((failures++)) || true
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
    echo -e "  ${BOLD}2.${NC} Start a zsh shell (or launch tui which uses zsh automatically):"
    echo "     zsh"
    echo ""
    echo -e "  ${BOLD}3.${NC} Launch the TUI environment:"
    echo "     tui"
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
    echo -e "  ${BOLD}Tip:${NC} Run ${GREEN}tui -h${NC} or ${GREEN}tui --help${NC} for a full keybinding reference."
    echo ""
}

main "$@"
