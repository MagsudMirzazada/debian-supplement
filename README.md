# Getting Started

1. Clone the repository (http)
2. Check if `~/dotfiles` and `~/debian-supplement` folders are created.
3. Run install-all.sh

## Files Backed Up

**`install-dotfiles.sh`** moves pre-existing configs to `~/.dotfiles_backup_<timestamp>/`:

- `~/.config/starship.toml`
- `~/.config/tmux/`
- `~/.tmux.conf`
- `~/.zsh_aliases`

**`install-all.sh`** copies `~/.zshrc` to `~/.zshrc.backup.<timestamp>` before modifying it.

## Files Created

Stow symlinks (from `~/dotfiles`):

- `~/.config/starship.toml`
- `~/.config/tmux/tmux.conf`
- `~/.zsh_aliases`

Installed from GitHub:

- `~/.config/nvim/` — LazyVim starter
- `~/.tmux/plugins/tpm/` — Tmux Plugin Manager

Binaries:

- `/usr/local/bin/starship`
- `/opt/nvim-linux-<arch>/` + `/usr/local/bin/nvim`

Fonts:

- `~/.local/share/fonts/FiraCode/` — FiraCode Nerd Font Mono

## Files Modified

- `~/.zshrc` — appends alias sourcing, fzf integration, Starship init
- `/etc/shells` — adds zsh path if missing (`set-shell.sh`)
