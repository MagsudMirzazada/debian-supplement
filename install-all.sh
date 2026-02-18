#!/bin/bash

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Resolve script directory so the script works when called from any location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

# Detect architecture once for all download URLs.
readonly ARCH="$(detect_arch)"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

# Backup function
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
    fi
}

# Add line to file if not present (idempotent).
# FIX: 'grep -F ""' matches any non-empty file, so empty lines were never
#      written.  We now special-case an empty $line and skip the grep entirely.
# FIX: Use -x (whole-line match) to avoid substring false-positives, e.g.
#      a commented-out line matching the uncommented version.
add_to_file() {
    local line="$1"
    local file="$2"

    if [[ -z "$line" ]]; then
        # Always append blank separator lines; there is no sensible way to
        # deduplicate them and they are purely cosmetic.
        echo "" >> "$file"
        return
    fi

    if ! grep -qxF "$line" "$file" 2>/dev/null; then
        echo "$line" >> "$file"
        log_info "Added to $file: $line"
    else
        log_warn "Already in $file: $line"
    fi
}

# ---------------------------------------------------------------------------
# Installation sections
# ---------------------------------------------------------------------------

install_core_packages() {
    log_info "Updating package lists..."
    sudo apt update

    log_info "Installing core packages..."
    readonly PACKAGES=(
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
}

install_starship() {
    log_info "Installing Starship..."

    if command_exists starship; then
        log_warn "Starship already installed, skipping..."
        return
    fi

    readonly STARSHIP_URL="https://github.com/starship/starship/releases/latest/download/starship-${ARCH}-unknown-linux-gnu.tar.gz"
    local starship_temp="/tmp/starship.tar.gz"
    register_temp "$starship_temp"

    if download "$STARSHIP_URL" "$starship_temp"; then
        tar -xzf "$starship_temp" -C /tmp
        sudo mv /tmp/starship /usr/local/bin/starship
        rm -f "$starship_temp"
        log_info "Starship installed successfully"
    else
        log_error "Failed to download Starship"
        exit 1
    fi
}

install_dotfiles() {
    if [[ -x "$SCRIPT_DIR/install-dotfiles.sh" ]]; then
        log_info "Installing dotfiles..."
        "$SCRIPT_DIR/install-dotfiles.sh"
    else
        log_warn "install-dotfiles.sh not found or not executable, skipping..."
    fi
}

configure_zsh() {
    log_info "Configuring Zsh..."

    # Create .zshrc if it doesn't exist
    [[ ! -f ~/.zshrc ]] && touch ~/.zshrc
    backup_file ~/.zshrc

    # Source alias file from .zshrc (aliases managed via dotfiles/zsh stow package)
    add_to_file '' ~/.zshrc
    add_to_file '# Load aliases' ~/.zshrc
    add_to_file '[[ -f ~/.zsh_aliases ]] && source ~/.zsh_aliases' ~/.zshrc

    # FIX: The '--zsh' shell-integration flag was introduced in fzf 0.48.0.
    #      Debian stable ships much older fzf builds (e.g. 0.38), so calling
    #      'fzf --zsh' on those versions prints an error and breaks .zshrc.
    #      We check the version and fall back to the legacy sourcing method when
    #      necessary.
    add_to_file '' ~/.zshrc
    add_to_file '# Set up fzf key bindings and fuzzy completion' ~/.zshrc

    local fzf_min_version="0.48.0"
    local fzf_current_version
    fzf_current_version="$(fzf --version 2>/dev/null | awk '{print $1}' || echo "0.0.0")"

    if version_gte "$fzf_current_version" "$fzf_min_version"; then
        add_to_file 'source <(fzf --zsh)' ~/.zshrc
    else
        log_warn "fzf $fzf_current_version detected (< $fzf_min_version); using legacy integration"
        # Legacy paths shipped with the Debian fzf package
        add_to_file '[[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh' ~/.zshrc
        add_to_file '[[ -f /usr/share/doc/fzf/examples/completion.zsh  ]] && source /usr/share/doc/fzf/examples/completion.zsh'  ~/.zshrc
    fi

    # Initialize Starship prompt
    add_to_file '' ~/.zshrc
    add_to_file '# Initialize Starship prompt' ~/.zshrc
    add_to_file 'eval "$(starship init zsh)"' ~/.zshrc
}

install_neovim() {
    log_info "Installing Neovim..."

    # Idempotency: skip if nvim already exists and the opt directory is present
    if command_exists nvim && compgen -G "/opt/nvim-linux-*" >/dev/null 2>&1; then
        log_warn "Neovim already installed at $(command -v nvim), skipping..."
        return
    fi

    # Remove old neovim if present (apt-installed or stale binary)
    if command_exists nvim; then
        log_warn "Removing existing Neovim installation..."
        sudo apt remove -y neovim 2>/dev/null || true
        sudo rm -f /usr/local/bin/nvim
        sudo rm -rf /usr/local/lib/nvim-squashfs-root
    fi

    # Map architecture to Neovim release naming convention
    local nvim_arch
    case "$ARCH" in
        x86_64)  nvim_arch="x86_64"  ;;
        aarch64) nvim_arch="aarch64" ;;
    esac

    readonly NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${nvim_arch}.tar.gz"
    local nvim_temp="/tmp/nvim-linux-${nvim_arch}.tar.gz"
    register_temp "$nvim_temp"

    if download "$NVIM_URL" "$nvim_temp"; then
        sudo rm -rf "/opt/nvim-linux-${nvim_arch}"
        sudo tar -C /opt -xzf "$nvim_temp"
        rm -f "$nvim_temp"

        sudo ln -sf "/opt/nvim-linux-${nvim_arch}/bin/nvim" /usr/local/bin/nvim
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
}

install_lazyvim() {
    log_info "Installing LazyVim..."

    readonly NVIM_CONFIG="$HOME/.config/nvim"

    #   1. Fresh install  — neither dir exists   -> clone
    #   2. First backup   — config exists, no .bak -> back up then clone
    #   3. Subsequent run — .bak already exists  -> warn and skip rather than
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
}

install_tpm() {
    log_info "Installing Tmux Plugin Manager..."

    readonly TPM_DIR="$HOME/.tmux/plugins/tpm"

    if [[ ! -d "$TPM_DIR" ]]; then
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
        log_info "TPM installed successfully"
    else
        log_warn "TPM already installed, skipping..."
    fi
}

install_fonts() {
    log_info "Installing FiraCode Nerd Font Mono..."

    readonly FONT_DIR="$HOME/.local/share/fonts/FiraCode"
    readonly FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    local font_temp="/tmp/FiraCode.zip"
    register_temp "$font_temp"

    if [[ -d "$FONT_DIR" ]]; then
        log_warn "FiraCode Nerd Font already installed, skipping..."
        return
    fi

    mkdir -p "$FONT_DIR"

    if download "$FONT_URL" "$font_temp"; then
        unzip -o "$font_temp" "*Mono*.ttf" -d "$FONT_DIR"
        rm -f "$font_temp"
        fc-cache -fv
        log_info "FiraCode Nerd Font Mono installed successfully"
    else
        log_error "Failed to download FiraCode Nerd Font"
        exit 1
    fi
}

set_default_shell() {
    if [[ -f "$SCRIPT_DIR/set-shell.sh" ]]; then
        if [[ ! -x "$SCRIPT_DIR/set-shell.sh" ]]; then
            chmod +x "$SCRIPT_DIR/set-shell.sh"
            log_info "Adding executable bit to set-shell.sh"
        fi
        log_info "Setting Zsh as default shell..."
        "$SCRIPT_DIR/set-shell.sh"
    else
        log_warn "set-shell.sh not found or cannot be made executable"
        log_info "Fallback method executing, setting shell directly"

        # Fallback: set shell directly
        local zsh_path
        zsh_path="$(command -v zsh 2>/dev/null || true)"
        if [[ -n "$zsh_path" ]] && [[ "$SHELL" != "$zsh_path" ]]; then
            log_info "Changing default shell to Zsh..."
            chsh -s "$zsh_path"
            log_info "Shell changed. Please log out and back in for changes to take effect."
        fi
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi

    trap cleanup_temp EXIT

    log_info "Starting installation process..."

    install_core_packages
    install_starship

    # NOTE: Dotfiles must be installed BEFORE configure_zsh.
    # install-dotfiles.sh backs up and moves pre-existing config files.
    # If it ran after we wrote ~/.zshrc, it would silently move that file
    # away and leave no .zshrc behind.
    install_dotfiles
    configure_zsh

    install_neovim
    install_lazyvim
    install_tpm
    install_fonts
    set_default_shell

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
}

main "$@"
