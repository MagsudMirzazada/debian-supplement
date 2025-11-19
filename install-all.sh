#!/bin/bash

# Install all packages in order
./install-zsh.sh
./install-tmux.sh
./install-tree.sh
./install-stow.sh

./install-dotfiles.sh

./set-shell.sh
