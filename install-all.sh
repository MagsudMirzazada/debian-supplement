#!/bin/bash

# Install all packages in order
# 1. install zsh
# 2. install starship
# 3. install stow
# 4. install tree
# 5. install tmux
./install-dotfiles.sh



# 1. Install Zsh
if ! command -v zsh &>/dev/null; then
    sudo apt install -y zsh
fi
# Set zsh as default
./set-shell.sh

# 2. Install starship
sudo apt install -y starship
# 3. Install stow
sudo apt install -y stow
# 4. Install tree
sudo apt install -y tree

# 5. Install tmux
yay -S --noconfirm --needed tmux

# Check if tmux is installed
if ! command -v tmux &>/dev/null; then
  echo "tmux installation failed."
  exit 1
fi

TPM_DIR="$HOME/.tmux/plugins/tpm"

# Check if TPM is already installed
if [ -d "$TPM_DIR" ]; then
  echo "TPM is already installed in $TPM_DIR"
else
  echo "Installing Tmux Plugin Manager (TPM)..."
  git clone https://github.com/tmux-plugins/tpm $TPM_DIR
fi

echo "TPM installed successfully!"
