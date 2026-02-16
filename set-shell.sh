#!/bin/bash

set -euo pipefail

# Resolve script directory so the script works when called from any location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

# FIX: 'which zsh' exits with a non-zero status when zsh is not installed.
#      Under 'set -e' this terminates the script immediately — before the
#      null-check below ever runs, making the friendly error message and
#      'exit 1' dead code.  We now use 'command -v ... || true' so that a
#      missing zsh yields an empty string instead of an abrupt exit, and the
#      explicit null-check below handles it correctly.
ZSH_PATH="$(command -v zsh 2>/dev/null || true)"

if [[ -z "$ZSH_PATH" ]]; then
    log_warn "Zsh is not installed. Please install it first:"
    log_warn "  sudo apt install -y zsh"
    exit 1
fi

# Check if zsh is already the default shell
if [[ "$SHELL" == "$ZSH_PATH" ]]; then
    log_info "Zsh is already your default shell ($ZSH_PATH)"
    exit 0
fi

# Ensure zsh is listed in /etc/shells (required by chsh)
if ! grep -q "^${ZSH_PATH}$" /etc/shells; then
    log_info "Adding $ZSH_PATH to /etc/shells..."
    echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
fi

# Change default shell
log_info "Changing default shell to Zsh ($ZSH_PATH)..."
chsh -s "$ZSH_PATH"

log_info "Default shell changed to Zsh"
log_info "Please log out and back in for changes to take effect"
