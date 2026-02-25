# Getting Started

1. Clone the repository (http)
2. Check if `~/dotfiles` and `~/debian-supplement` folders are created.
3. Run install-all.sh

## Installation Order

1. Core APT packages → 2. Starship → 3. **Dotfiles (stow)** → 4. fzf → 5. Zsh plugins → 6. Neovim → 7. LazyVim → 8. TPM → 9. Fonts → 10. Set default shell

fzf uses `--bin` (binary only), and `.zshrc` handles fzf integration directly in the template — no strict ordering required between dotfiles and fzf.

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

- `~/.fzf/` — fzf fuzzy finder (binary only via `--bin`; shell integration in `.zshrc` template)
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

- `/etc/shells` — adds zsh path if missing (`set-shell.sh`)
