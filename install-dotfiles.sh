#!/bin/bash

set -euo pipefail

# Resolve script directory so the script works when called from any location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

# Configuration
readonly REPO_URL="https://github.com/MagsudMirzazada/dotfiles"
readonly REPO_NAME="dotfiles"
readonly DOTFILES_DIR="$HOME/$REPO_NAME"
readonly BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Store original directory
ORIGINAL_DIR="$(pwd)"

# Cleanup function to return to original directory
cleanup() {
    cleanup_temp
    cd "$ORIGINAL_DIR" || true
}
trap cleanup EXIT

# Check if stow is installed
check_stow() {
    if ! command_exists stow; then
        log_error "GNU Stow is not installed. Please install it first:"
        log_error "  sudo apt install -y stow"
        exit 1
    fi
    log_info "GNU Stow found: $(stow --version | head -n1)"
}

# Backup existing configs
# FIX: The old code used basename + a fragile ".config" glob check, which
#      flattened nested paths (e.g. .config/tmux and .config/ghostty both
#      became just their basename under .config/).  We now preserve the full
#      relative path from $HOME so the backup directory mirrors the original
#      directory structure exactly.
backup_configs() {
    local files_to_backup=(
        "$HOME/.config/starship.toml"
        "$HOME/.config/tmux"
        # "$HOME/.config/nvim"
        "$HOME/.config/ghostty"
        "$HOME/.tmux.conf"
        # "$HOME/.zshrc" is intentionally excluded: the zshrc stow package is
        # commented out, so backing up and moving .zshrc would delete it with
        # nothing to replace it.  .zshrc is managed directly by install.sh.
    )

    local backed_up=false

    for file in "${files_to_backup[@]}"; do
        if [[ -e "$file" ]] && [[ ! -L "$file" ]]; then
            if [[ "$backed_up" == false ]]; then
                mkdir -p "$BACKUP_DIR"
                log_info "Creating backup directory: $BACKUP_DIR"
                backed_up=true
            fi

            # Preserve full directory structure relative to $HOME
            local rel_path="${file#"$HOME"/}"
            local dest_dir
            dest_dir="$(dirname "$BACKUP_DIR/$rel_path")"
            mkdir -p "$dest_dir"
            mv "$file" "$BACKUP_DIR/$rel_path"

            log_info "Backed up: $file"
        fi
    done

    if [[ "$backed_up" == true ]]; then
        log_info "Backups saved to: $BACKUP_DIR"
    else
        log_info "No existing configs to backup"
    fi
}

# Clone or update dotfiles repository
setup_dotfiles_repo() {
    cd "$HOME" || exit 1

    if [[ -d "$DOTFILES_DIR" ]]; then
        log_warn "Repository '$REPO_NAME' already exists"
        log_step "Updating existing repository..."

        cd "$DOTFILES_DIR" || exit 1

        # Check if it's a git repository
        if [[ -d .git ]]; then
            # Stash any local changes
            if ! git diff-index --quiet HEAD --; then
                log_warn "Local changes detected, stashing..."
                git stash
            fi

            # FIX: Detect the default branch from the remote instead of
            #      guessing main/master and suppressing stderr.
            local default_branch
            default_branch="$(git remote show origin 2>/dev/null \
                | sed -n 's/.*HEAD branch: //p')" || true

            if [[ -z "$default_branch" ]]; then
                log_warn "Could not detect default branch, trying main then master"
                default_branch="main"
            fi

            if git pull origin "$default_branch"; then
                log_info "Repository updated successfully"
            elif [[ "$default_branch" == "main" ]] && git pull origin master; then
                log_info "Repository updated successfully (fell back to master)"
            else
                log_error "Failed to update repository — check your network and remote URL"
                return 1
            fi
        else
            log_warn "Directory exists but is not a git repository"
            log_warn "Using existing directory as-is"
        fi
    else
        log_step "Cloning dotfiles repository..."

        if git clone "$REPO_URL" "$DOTFILES_DIR"; then
            log_info "Repository cloned successfully"
            cd "$DOTFILES_DIR" || exit 1
        else
            log_error "Failed to clone repository from $REPO_URL"
            exit 1
        fi
    fi
}

# Stow dotfiles
stow_dotfiles() {
    log_step "Stowing dotfiles..."

    cd "$DOTFILES_DIR" || exit 1

    # List of packages to stow
    local packages=(
        "starship"
        "tmux"
        # "zshrc"
        # "ghostty"
        # "nvim"
    )

    # Check which packages are available
    local available_packages=()
    for pkg in "${packages[@]}"; do
        if [[ -d "$pkg" ]]; then
            available_packages+=("$pkg")
        else
            log_warn "Package directory not found: $pkg (skipping)"
        fi
    done

    if [[ ${#available_packages[@]} -eq 0 ]]; then
        log_error "No valid package directories found"
        exit 1
    fi

    local failed=0
    for pkg in "${available_packages[@]}"; do
        log_info "Checking: $pkg (dry-run)"

        local dry_output
        dry_output=$(stow -nv "$pkg" 2>&1 || true)

        if echo "$dry_output" | grep -q "CONFLICT"; then
            log_error "Conflict detected while stowing $pkg:"
            echo "$dry_output" | grep "CONFLICT" >&2
            log_error "Remove the conflicting files manually and re-run, or use --adopt"
            failed=$((failed + 1))
            continue
        fi

        log_info "Stowing: $pkg"
        if stow "$pkg"; then
            log_info "Successfully stowed: $pkg"
        else
            log_error "Failed to stow: $pkg"
            failed=$((failed + 1))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        log_warn "$failed package(s) failed to stow"
        log_warn "You may need to resolve conflicts manually"
        return 1
    fi

    log_info "All packages stowed successfully!"
}

# Verify stow results
verify_stow() {
    log_step "Verifying stowed configurations..."

    local configs_to_check=(
        "$HOME/.config/starship.toml"
        "$HOME/.config/tmux/tmux.conf"
    )

    local all_ok=true
    for config in "${configs_to_check[@]}"; do
        if [[ -L "$config" ]]; then
            local target
            target="$(readlink -f "$config")"
            log_info "$config -> $target"
        elif [[ -e "$config" ]]; then
            log_warn "$config exists but is not a symlink"
            all_ok=false
        else
            log_warn "$config not found"
            all_ok=false
        fi
    done

    if [[ "$all_ok" == true ]]; then
        log_info "All configurations verified successfully!"
    else
        log_warn "Some configurations may need attention"
    fi
}

# Main execution
main() {
    log_info "Starting dotfiles installation..."
    log_info ""

    check_stow
    backup_configs
    setup_dotfiles_repo
    stow_dotfiles
    verify_stow

    log_info ""
    log_info "============================================"
    log_info "Dotfiles installation completed!"
    log_info "============================================"
    log_info ""

    if [[ -d "$BACKUP_DIR" ]]; then
        log_info "Your old configs are backed up in:"
        log_info "  $BACKUP_DIR"
        log_info ""
    fi

    log_info "Next steps:"
    log_info "1. Restart your terminal or run: exec zsh"
    log_info "2. Open tmux to verify configuration"
    log_info "3. Check starship prompt is loaded"
}

main "$@"
