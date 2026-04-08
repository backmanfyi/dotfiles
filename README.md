# dotfiles

Personal developer environment config for macOS, managed via symlinks.

## What's included

| Tool | Config |
|---|---|
| zsh | `zsh/zshrc`, `zsh/zshenv` |
| neovim | `nvim/` (LazyVim) |
| tmux | `tmux/tmux.conf` |
| ghostty | `ghostty/config` |
| git | `git/config`, `git/ignore`, `git/alias.ini` |
| starship | `starship/config.toml` |
| bat | `bat/config` |
| ssh | `ssh/config` (1Password agent) |

## Setup

```sh
git clone git@github.com:backmanfyi/dotfiles.git ~/.config/dotfiles
bash ~/.config/dotfiles/setup.sh
```

The script will:
1. Write `ZDOTDIR` to `/etc/zshenv` (requires sudo)
2. Install Homebrew if not present
3. Install all packages via `brew bundle`
4. Register Homebrew zsh as a login shell and set it as default
5. Symlink all configs into `~/.config`
6. Set correct permissions on the SSH config directory

## SSH commit signing

Commits are signed via SSH using 1Password. After setup, verify with:

```sh
git log --show-signature
```

## Notes

- `zshrc_local` at `~/.config/zsh/.zshrc_local` is sourced last and not tracked — put machine-specific overrides there
- tmux auto-attaches to a `main` session on shell start
- AWS profile switching: `aws_environment [profile]`
