#!/bin/bash

# Install all packages in order
# 1. install zsh
# 2. install starship
# 3. install neovim
# 4. install lazyvim
# 5. install ripgrep
# 6. install tree
# 7. install tmux

# 8. install stow
# 9. install-dotfiles.sh



# 1. Install Zsh
if ! command -v zsh &>/dev/null; then
    sudo apt install -y zsh
fi
# Set zsh as default
./set-shell.sh

# 2. Install starship
sudo apt install -y starship

# 3. Install Neovim
sudo apt remove neovim
wget https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
chmod u+x nvim-linux-x86_64.appimage
sudo mv nvim-linux-x86_64.appimage /usr/local/bin/nvim

# Install lazyvim
mv ~/.config/nvim{,.bak}
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

# 5. Install ripgrep
sudo apt-get install ripgrep
# 6.. Install tree
sudo apt install -y tree

# 7. Install tmux
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


# 8. Install stow
sudo apt install -y stow
# 9. Install dotfiles
./install-dotfiles.sh
