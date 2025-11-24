#!/bin/bash

# Install all packages in order
# install zsh
# install starship
# install batcat (bat)
# install fzf

# install neovim
# install lazyvim
# install ripgrep
# install tree
# install tmux

# install stow
# install-dotfiles.sh
# set-shell.sh


# 1. Install Zsh
if ! command -v zsh &>/dev/null; then
    sudo apt install -y zsh
fi
# Set zsh as default
./set-shell.sh

# 2. Install starship
sudo apt install -y starship

# Install batcat
sudo apt install -y bat
echo '\nalias bat="batcat"' >> ~/.zshrc 

# 3. Install fzf
sudo apt install fzf

echo "\n# Set up fzf key bindings and fuzzy completion" >> ~/.zshrc
echo "source <(fzf --zsh)" >> ~/.zshrc
echo "alias nv='nvim \$(fzf -m --preview=\"batcat --color=always {}\")'" >> ~/.zshrc

source ~/.zshrc

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
sudo apt install -y tmux

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

# 10. Check and, Set ZSH as default shell
./set-shell.sh
