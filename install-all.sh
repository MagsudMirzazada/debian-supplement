#!/bin/bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root"
   exit 1
fi

# Backup function
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Add line to file if not exists (idempotent)
add_to_file() {
    local line="$1"
    local file="$2"
    if ! grep -qF "$line" "$file" 2>/dev/null; then
        echo "$line" >> "$file"
        log_info "Added to $file: $line"
    else
        log_warn "Already in $file: $line"
    fi
}

# ============================================
# Main Installation
# ============================================

log_info "Starting installation process..."

# Update package list
log_info "Updating package lists..."
sudo apt update

# Batch install core packages
log_info "Installing core packages..."
PACKAGES=(
    zsh
    starship
    bat
    fzf
    ripgrep
    tree
    tmux
    stow
    wget
    curl
    git
)

sudo apt install -y "${PACKAGES[@]}"

# ============================================
# Configure Zsh
# ============================================
log_info "Configuring Zsh..."

# Create .zshrc if it doesn't exist
[[ ! -f ~/.zshrc ]] && touch ~/.zshrc
backup_file ~/.zshrc

# Add bat alias (idempotent)
if command_exists batcat && ! command_exists bat; then
    add_to_file 'alias bat="batcat"' ~/.zshrc
fi

# Configure fzf
add_to_file '' ~/.zshrc
add_to_file '# Set up fzf key bindings and fuzzy completion' ~/.zshrc
add_to_file 'source <(fzf --zsh)' ~/.zshrc
add_to_file 'alias nv='\''nvim $(fzf -m --preview="batcat --color=always {}")'\''' ~/.zshrc

# ============================================
# Install Neovim
# ============================================
log_info "Installing Neovim..."

# Remove old neovim if exists
if command_exists nvim; then
    log_warn "Removing existing neovim installation..."
    sudo apt remove -y neovim 2>/dev/null || true
    sudo rm -f /usr/local/bin/nvim
fi

# Download and install latest Neovim
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage"
NVIM_TEMP="/tmp/nvim.appimage"

if wget -O "$NVIM_TEMP" "$NVIM_URL"; then
    chmod u+x "$NVIM_TEMP"
    sudo mv "$NVIM_TEMP" /usr/local/bin/nvim
    log_info "Neovim installed successfully"
else
    log_error "Failed to download Neovim"
    exit 1
fi

# Verify Neovim installation
if ! command_exists nvim; then
    log_error "Neovim installation verification failed"
    exit 1
fi

# ============================================
# Install LazyVim
# ============================================
log_info "Installing LazyVim..."

NVIM_CONFIG="$HOME/.config/nvim"

if [[ -d "$NVIM_CONFIG" ]] && [[ ! -d "${NVIM_CONFIG}.bak" ]]; then
    log_info "Backing up existing nvim config..."
    mv "$NVIM_CONFIG" "${NVIM_CONFIG}.bak"
fi

if [[ ! -d "$NVIM_CONFIG" ]]; then
    git clone https://github.com/LazyVim/starter "$NVIM_CONFIG"
    rm -rf "${NVIM_CONFIG}/.git"
    log_info "LazyVim installed successfully"
else
    log_warn "LazyVim config already exists, skipping..."
fi

# ============================================
# Install TPM (Tmux Plugin Manager)
# ============================================
log_info "Installing Tmux Plugin Manager..."

TPM_DIR="$HOME/.tmux/plugins/tpm"

if [[ ! -d "$TPM_DIR" ]]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    log_info "TPM installed successfully"
else
    log_warn "TPM already installed"
fi

# ============================================
# Install Dotfiles
# ============================================
if [[ -x "./install-dotfiles.sh" ]]; then
    log_info "Installing dotfiles..."
    ./install-dotfiles.sh
else
    log_warn "install-dotfiles.sh not found or not executable"
fi

# ============================================
# Set Zsh as Default Shell
# ============================================
if [[ -x "./set-shell.sh" ]]; then
    log_info "Setting Zsh as default shell..."
    ./set-shell.sh
else
    log_warn "set-shell.sh not found or not executable"
    
    # Fallback: set shell directly
    if [[ "$SHELL" != "$(which zsh)" ]]; then
        log_info "Changing default shell to Zsh..."
        chsh -s "$(which zsh)"
        log_info "Shell changed. Please log out and back in for changes to take effect."
    fi
fi

# ============================================
# Final Steps
# ============================================
log_info ""
log_info "============================================"
log_info "Installation completed successfully!"
log_info "============================================"
log_info ""
log_info "Next steps:"
log_info "1. Log out and back in (or restart) for shell changes to take effect"
log_info "2. Launch tmux and press 'prefix + I' to install tmux plugins"
log_info "3. Open nvim to let LazyVim install plugins"
log_info ""
log_info "Backups of modified files are saved with .backup.* extensions"