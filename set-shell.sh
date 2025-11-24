#!/bin/bash

set -euo pipefail

# Color output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Get zsh path
ZSH_PATH="$(which zsh)"

if [[ -z "$ZSH_PATH" ]]; then
    log_warn "Zsh is not installed. Please install it first."
    exit 1
fi

# Check if zsh is already the default shell
if [[ "$SHELL" == "$ZSH_PATH" ]]; then
    log_info "Zsh is already your default shell"
    exit 0
fi

# Check if zsh is in /etc/shells
if ! grep -q "^${ZSH_PATH}$" /etc/shells; then
    log_info "Adding $ZSH_PATH to /etc/shells..."
    echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
fi

# Change default shell
log_info "Changing default shell to Zsh..."
chsh -s "$ZSH_PATH"

log_info "Default shell changed to Zsh"
log_info "Please log out and back in for changes to take effect"