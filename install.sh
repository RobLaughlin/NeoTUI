#!/usr/bin/env bash
# ============================================================
# NeoTUI - Remote Installer (Bootstrap Script)
# Clones the repo and runs the local installer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/RobLaughlin/NeoTUI/main/install.sh | bash
#   curl -fsSL ... | bash -s -- --yes
#   curl -fsSL ... | bash -s -- --skip-unsupported
# ============================================================
set -euo pipefail

REPO_URL="https://github.com/RobLaughlin/NeoTUI.git"
REPO_DIR="$HOME/.local/share/neotui/repo"

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

header "NeoTUI Bootstrap Installer"
echo ""

missing=()
has git   || missing+=("git")
has curl  || missing+=("curl")

if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required tools: ${missing[*]}"
    echo ""
    echo "Install them with your package manager:"
    echo "  apt:    sudo apt install ${missing[*]}"
    echo "  dnf:    sudo dnf install ${missing[*]}"
    echo "  pacman: sudo pacman -S ${missing[*]}"
    echo "  brew:   brew install ${missing[*]}"
    exit 1
fi

if [[ -d "$REPO_DIR" ]]; then
    info "Repository exists at $REPO_DIR"
    info "Pulling latest changes..."
    if git -C "$REPO_DIR" pull; then
        success "Repository updated"
    else
        warn "Could not pull updates, using existing version"
    fi
else
    info "Cloning NeoTUI to $REPO_DIR..."
    mkdir -p "$(dirname "$REPO_DIR")"
    if git clone --depth 1 "$REPO_URL" "$REPO_DIR"; then
        success "Repository cloned"
    else
        error "Failed to clone repository"
        exit 1
    fi
fi

info "Running installer..."
echo ""

cd "$REPO_DIR"
exec ./install-local.sh "$@"
