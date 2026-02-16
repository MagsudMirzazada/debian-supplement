#!/bin/bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
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

# Add line to file if not present (idempotent).
# FIX: 'grep -F ""' matches any non-empty file, so empty lines were never
#      written.  We now special-case an empty $line and skip the grep entirely.
add_to_file() {
    local line="$1"
    local file="$2"

    if [[ -z "$line" ]]; then
        # Always append blank separator lines; there is no sensible way to
        # deduplicate them and they are purely cosmetic.
        echo "" >> "$file"
        return
    fi

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
    bat
    fzf
    ripgrep
    tree
    tmux
    stow
    wget
    curl
    git
    unzip
    fontconfig
)

sudo apt install -y "${PACKAGES[@]}"

# ============================================
# Install Starship
# ============================================
log_info "Installing Starship..."

# starship is not available in Debian/Ubuntu apt repos;
# download the prebuilt binary from GitHub releases via wget (proxy-friendly)
if ! command_exists starship; then
    STARSHIP_URL="https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz"
    STARSHIP_TEMP="/tmp/starship.tar.gz"

    if wget -O "$STARSHIP_TEMP" "$STARSHIP_URL"; then
        tar -xzf "$STARSHIP_TEMP" -C /tmp
        sudo mv /tmp/starship /usr/local/bin/starship
        rm -f "$STARSHIP_TEMP"
        log_info "Starship installed successfully"
    else
        log_error "Failed to download Starship"
        exit 1
    fi
else
    log_warn "Starship already installed, skipping..."
fi

# ============================================
# Install Dotfiles
# ============================================
# NOTE: This must run BEFORE the "Configure Zsh" section below.
#       install-dotfiles.sh backs up and moves pre-existing config files.
#       If it ran after we wrote ~/.zshrc, it would silently move that file
#       away and leave no .zshrc behind (the zshrc stow package is commented
#       out, so nothing would replace it).
if [[ -x "./install-dotfiles.sh" ]]; then
    log_info "Installing dotfiles..."
    ./install-dotfiles.sh
else
    log_warn "install-dotfiles.sh not found or not executable, skipping..."
fi

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

# FIX: The '--zsh' shell-integration flag was introduced in fzf 0.48.0.
#      Debian stable ships much older fzf builds (e.g. 0.38), so calling
#      'fzf --zsh' on those versions prints an error and breaks .zshrc.
#      We check the version and fall back to the legacy sourcing method when
#      necessary.
add_to_file '' ~/.zshrc
add_to_file '# Set up fzf key bindings and fuzzy completion' ~/.zshrc

FZF_MIN_VERSION="0.48.0"
FZF_CURRENT_VERSION="$(fzf --version 2>/dev/null | awk '{print $1}' || echo "0.0.0")"

version_gte() {
    # Returns 0 (true) if $1 >= $2 using sort -V
    [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

if version_gte "$FZF_CURRENT_VERSION" "$FZF_MIN_VERSION"; then
    add_to_file 'source <(fzf --zsh)' ~/.zshrc
else
    log_warn "fzf $FZF_CURRENT_VERSION detected (< $FZF_MIN_VERSION); using legacy integration"
    # Legacy paths shipped with the Debian fzf package
    add_to_file '[[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh' ~/.zshrc
    add_to_file '[[ -f /usr/share/doc/fzf/examples/completion.zsh  ]] && source /usr/share/doc/fzf/examples/completion.zsh'  ~/.zshrc
fi

add_to_file 'alias nv='\''nvim $(fzf -m --preview="batcat --color=always {}")'\''' ~/.zshrc

# Initialize Starship prompt
add_to_file '' ~/.zshrc
add_to_file '# Initialize Starship prompt' ~/.zshrc
add_to_file 'eval "$(starship init zsh)"' ~/.zshrc

# ============================================
# Install Neovim
# ============================================
log_info "Installing Neovim..."

# Remove old neovim if present
if command_exists nvim; then
    log_warn "Removing existing Neovim installation..."
    sudo apt remove -y neovim 2>/dev/null || true
    sudo rm -f /usr/local/bin/nvim
    sudo rm -rf /usr/local/lib/nvim-squashfs-root
fi

# Download and install latest Neovim
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
NVIM_TEMP="/tmp/nvim-linux-x86_64.tar.gz"

if curl -Lo "$NVIM_TEMP" "$NVIM_URL"; then
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar -C /opt -xzf "$NVIM_TEMP"
    rm -f "$NVIM_TEMP"

    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    log_info "Neovim installed successfully"
else
    log_error "Failed to download Neovim"
    rm -f "$NVIM_TEMP"
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

#   1. Fresh install  — neither dir exists   → clone
#   2. First backup   — config exists, no .bak → back up then clone
#   3. Subsequent run — .bak already exists  → warn and skip rather than
#                       silently leaving nvim unconfigured

if [[ ! -d "$NVIM_CONFIG" ]]; then
    git clone https://github.com/LazyVim/starter "$NVIM_CONFIG"
    rm -rf "${NVIM_CONFIG}/.git"
    log_info "LazyVim installed successfully"
elif [[ ! -d "${NVIM_CONFIG}.bak" ]]; then
    log_info "Backing up existing nvim config to ${NVIM_CONFIG}.bak ..."
    mv "$NVIM_CONFIG" "${NVIM_CONFIG}.bak"
    git clone https://github.com/LazyVim/starter "$NVIM_CONFIG"
    rm -rf "${NVIM_CONFIG}/.git"
    log_info "LazyVim installed successfully"
else
    log_warn "Both $NVIM_CONFIG and ${NVIM_CONFIG}.bak already exist."
    log_warn "Skipping LazyVim install to avoid overwriting data."
    log_warn "Remove or rename one of them and re-run if you want a fresh install."
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
    log_warn "TPM already installed, skipping..."
fi

# ============================================
# Install FiraCode Nerd Font Mono
# ============================================
log_info "Installing FiraCode Nerd Font Mono..."

FONT_DIR="$HOME/.local/share/fonts/FiraCode"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
FONT_TEMP="/tmp/FiraCode.zip"

if [[ ! -d "$FONT_DIR" ]]; then
    mkdir -p "$FONT_DIR"

    if wget -O "$FONT_TEMP" "$FONT_URL"; then
        unzip -o "$FONT_TEMP" "*Mono*.ttf" -d "$FONT_DIR"
        rm -f "$FONT_TEMP"
        fc-cache -fv
        log_info "FiraCode Nerd Font Mono installed successfully"
    else
        log_error "Failed to download FiraCode Nerd Font"
        exit 1
    fi
else
    log_warn "FiraCode Nerd Font already installed, skipping..."
fi

# ============================================
# Set Zsh as Default Shell
# ============================================
if [[ -f ./set-shell.sh ]]; then
    if [[ ! -x ./set-shell.sh ]]; then
        chmod +x ./set-shell.sh
        log_info "Adding executable bit to set-shell.sh"
    else
        log_info "Setting Zsh as default shell..."
        ./set-shell.sh
    fi
else
    log_warn "set-shell.sh not found or cannot be made executable"
    log_info "Fallback method executing, setting shell directly"
    
    # Fallback: set shell directly
    ZSH_PATH="$(command -v zsh 2>/dev/null || true)"
    if [[ -n "$ZSH_PATH" ]] && [[ "$SHELL" != "$ZSH_PATH" ]]; then
        log_info "Changing default shell to Zsh..."
        chsh -s "$ZSH_PATH"
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
