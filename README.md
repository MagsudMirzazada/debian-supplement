# Getting Started

1. Clone the repository (http)
2. Check if `~/dotfiles` and `~/debian-supplement` folders are created.
3. Run install-all.sh

## Installation Order

1. Core APT packages → 2. Starship → 3. **Dotfiles (stow)** → 4. fzf → 5. Zsh plugins → 6. Neovim → 7. LazyVim → 8. TPM → 9. Fonts → 10. Set default shell

**Ordering constraint:** Dotfiles must be stowed *before* fzf install because `~/.fzf/install --all` appends to `~/.zshrc`. Stow must place `.zshrc` first so fzf appends to the symlinked file.

## Files Backed Up

**`install-dotfiles.sh`** moves pre-existing configs to `~/.dotfiles_backup_<timestamp>/`:

- `~/.config/starship.toml`
- `~/.config/tmux/`
- `~/.tmux.conf`
- `~/.zsh_aliases`
- `~/.zshrc`

## Files Created

Stow symlinks (from `~/dotfiles`):

- `~/.zshrc`
- `~/.zsh_aliases`
- `~/.config/starship.toml`
- `~/.config/tmux/tmux.conf`

Installed from GitHub:

- `~/.fzf/` — fzf fuzzy finder
- `~/.zsh/zsh-autosuggestions/` — zsh-autosuggestions plugin
- `~/.zsh/zsh-syntax-highlighting/` — zsh-syntax-highlighting plugin
- `~/.config/nvim/` — LazyVim starter
- `~/.tmux/plugins/tpm/` — Tmux Plugin Manager

Binaries:

- `/usr/local/bin/starship`
- `/opt/nvim-linux-<arch>/` + `/usr/local/bin/nvim`

Fonts:

- `~/.local/share/fonts/FiraCode/` — FiraCode Nerd Font Mono

## Files Modified

- `~/.zshrc` — fzf integration appended by `~/.fzf/install --all`
- `/etc/shells` — adds zsh path if missing (`set-shell.sh`)
