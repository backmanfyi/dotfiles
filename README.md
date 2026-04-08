# dotfiles

[![Lint](https://github.com/backmanfyi/dotfiles/actions/workflows/lint.yml/badge.svg)](https://github.com/backmanfyi/dotfiles/actions/workflows/lint.yml)
[![Setup smoke test](https://github.com/backmanfyi/dotfiles/actions/workflows/setup-smoke-test.yml/badge.svg)](https://github.com/backmanfyi/dotfiles/actions/workflows/setup-smoke-test.yml)
[![Secret scan](https://github.com/backmanfyi/dotfiles/actions/workflows/trufflehog.yml/badge.svg)](https://github.com/backmanfyi/dotfiles/actions/workflows/trufflehog.yml)

Personal macOS developer environment for platform and infrastructure engineering. Managed via symlinks — the repo is the source of truth, `~/.config/*` just points here.

---

## Contents

- [What's included](#whats-included)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [How it works](#how-it-works)
- [Shell](#shell)
- [Tools](#tools)
- [Security](#security)
- [CI/CD](#cicd)
- [Customisation](#customisation)
- [Updating](#updating)

---

## What's included

| Config | Tool | Purpose |
|---|---|---|
| `zsh/` | zsh | Shell config, aliases, environment |
| `nvim/` | Neovim (LazyVim) | Editor |
| `tmux/` | tmux | Terminal multiplexer |
| `ghostty/` | Ghostty | Terminal emulator |
| `git/` | git | Version control, signing, aliases |
| `starship/` | Starship | Shell prompt |
| `ssh/` | SSH | Client config, 1Password agent |
| `bat/` | bat | Syntax-highlighted `cat` replacement |
| `brew/` | Homebrew | Package manifest (Brewfile) |
| `scripts/` | — | Utility scripts on `$PATH` |

---

## Prerequisites

- macOS (Apple Silicon)
- An internet connection for the initial setup
- [1Password](https://1password.com) with the SSH agent enabled (Settings → Developer → SSH Agent)
- `sudo` access (required for `/etc/zshenv` and `/etc/shells`)

---

## Installation

```sh
git clone git@github.com:backmanfyi/dotfiles.git ~/.config/dotfiles
bash ~/.config/dotfiles/setup.sh
```

Restart your terminal when complete.

### What setup.sh does

The script is fully idempotent — safe to re-run at any time. Each step checks before acting.

| Step | What happens |
|---|---|
| **1. ZDOTDIR bootstrap** | Writes `ZDOTDIR=~/.config/zsh` to `/etc/zshenv` so zsh finds your config on a fresh machine |
| **2. Homebrew** | Installs Homebrew if missing, then runs `brew bundle` from the Brewfile |
| **3. Login shell** | Registers `/opt/homebrew/bin/zsh` in `/etc/shells` and sets it as your default shell |
| **4. Symlinks** | Creates `~/.config/{bat,ghostty,git,nvim,ssh,starship,tmux}` → dotfiles repo |
| **5. Git hooks** | `chmod +x` on all files in `git/hooks/` |
| **6. SSH permissions** | `chmod 700` on the SSH dir, `chmod 600` on all files (SSH silently ignores loose permissions) |

To preview what the script would do without making any changes:

```sh
bash setup.sh --dry-run
```

---

## How it works

Everything lives in `~/.config/dotfiles`. The setup script creates symlinks so each tool finds its config at the expected XDG path:

```
~/.config/git  →  ~/.config/dotfiles/git
~/.config/nvim →  ~/.config/dotfiles/nvim
~/.config/zsh/.zshrc  →  ~/.config/dotfiles/zsh/zshrc
...
```

Editing a config file in the repo is immediately live — no re-linking needed. Committing it persists the change.

The zsh startup chain on a fresh machine:

```
/etc/zshenv          sets ZDOTDIR=~/.config/zsh
~/.config/zsh/.zshenv   sets PATH, exports, Go/Volta/pyenv vars
~/.config/zsh/.zshrc    aliases, completions, tool inits, plugins
~/.config/zsh/.zshrc_local  machine-local overrides (not tracked)
```

---

## Shell

### Performance

Shell startup is kept fast deliberately:

- **`compinit` runs once per day** — the completion dump is only rebuilt when stale, not on every shell start
- **pyenv is lazy-loaded** — the `pyenv` function only initialises the full shim stack on first use
- **No `brew --prefix` subprocesses** — paths are hardcoded to `/opt/homebrew`
- **`zoxide` instead of autojump** — faster directory jumping with frecency ranking

### Key aliases and functions

| Command | Does |
|---|---|
| `z <query>` / `j <query>` | Jump to frecent directory (zoxide) |
| `zi` | Interactive directory picker (zoxide + fzf) |
| `l` / `la` | `eza -l` / `eza -al` |
| `cat` | `bat` (syntax highlighted) |
| `vim` / `vi` | `nvim` |
| `t` / `tree` | `eza -T` (directory tree) |
| `aws_environment [profile]` | Assumes AWS SSO role and exports credentials to the shell |

### Prompt

[Starship](https://starship.rs) — minimal single-line prompt showing:
- Current directory (truncated to 2 levels, fish-style)
- Git branch + status (ahead/behind/diverged)
- Python virtualenv when active
- Current time (right-aligned)

---

## Tools

### Neovim

[LazyVim](https://lazyvim.org) distribution. Config at `nvim/lua/`.

### tmux

Prefix: `C-q`

| Binding | Action |
|---|---|
| `C-q h/j/k/l` | Navigate panes (vim-style) |
| `C-q H/J/K/L` | Resize panes |
| `C-q s` | Session picker |
| `C-q E` | New named session |
| `C-q X` | Kill session (switches to alternate first) |
| `C-q y` | Toggle pane synchronisation |
| `C-q R` | Reload tmux config |

Status bar shows: public IP (via DNS lookup), active AWS profile + role, session/window/pane, date, week number, time.

Auto-attaches to a session named `main` on shell start.

### git

Signed commits via SSH key through 1Password (`gpg.format = ssh`, `op-ssh-sign`).

Useful defaults enabled:

| Setting | Value | Why |
|---|---|---|
| `pull.rebase` | `true` | Clean linear history |
| `fetch.prune` | `true` | Auto-remove stale remote branches |
| `rebase.autoStash` | `true` | Stash dirty tree before rebase automatically |
| `rerere.enabled` | `true` | Remember conflict resolutions |
| `diff.algorithm` | `histogram` | Better diff output |
| `merge.conflictstyle` | `zdiff3` | Shows base in conflict markers |
| `branch.sort` | `-committerdate` | Recent branches first |

Diff output via [delta](https://github.com/dandavison/delta) with side-by-side view.

### Runtime version managers

| Language | Manager | Notes |
|---|---|---|
| Node.js | [Volta](https://volta.sh) | Per-project pinning via `package.json` |
| Python | [pyenv](https://github.com/pyenv/pyenv) | Lazy-loaded, also [uv](https://docs.astral.sh/uv/) available |
| Go | Homebrew | Single system version |

---

## Security

### Commit signing

All commits are signed with your SSH key via 1Password:

```sh
# Verify signatures on recent commits
git log --show-signature -5
```

The `git/allowed_signers` file maps your email to your public key for local verification.

### Secret scanning

[TruffleHog](https://github.com/trufflesecurity/trufflehog) runs at two points:

**Pre-commit hook** (`git/hooks/pre-commit`) — blocks the commit if verified secrets are found in staged changes. Installed globally via `core.hooksPath` so it runs in every repository on the machine.

```sh
# To bypass in an emergency (use with caution)
git commit --no-verify
```

**CI pipeline** — TruffleHog scans the full branch diff on every push and PR.

### SSH

All SSH authentication goes through the 1Password agent (`IdentityAgent` in `ssh/config`). Keys never touch disk. Config also enforces:

- `StrictHostKeyChecking ask` — prompts on new hosts rather than silently accepting
- `HashKnownHosts yes` — hostnames in `known_hosts` are hashed
- `ServerAliveInterval 60` — detects dead connections

---

## CI/CD

Three GitHub Actions workflows:

### `lint.yml` — every push and PR (Linux)

Four parallel jobs:

| Job | Tool | Checks |
|---|---|---|
| `shellcheck` | shellcheck | All `.sh` files at `--severity=error` |
| `zsh-syntax` | `zsh -n` | `zshrc` and `zshenv` parse without errors |
| `toml` | taplo | `starship/config.toml` is valid TOML |
| `repo-checks` | bash | Symlink targets exist, no hardcoded `/Users/` paths, `setup.sh` is executable |

### `setup-smoke-test.yml` — PRs to main (macOS)

Runs on a fresh `macos-latest` runner:
- `bash -n setup.sh` — syntax check
- `bash setup.sh --dry-run` — full dry-run, validates all source paths exist
- `ruby -c brew/Brewfile` — Brewfile syntax check
- Rejects unknown flags (validates arg parsing)
- Verifies no hardcoded paths in `setup.sh`

### `trufflehog.yml` — every push and PR

Scans the branch diff for verified secrets.

---

## Customisation

### Machine-local overrides

`~/.config/zsh/.zshrc_local` is sourced at the end of `zshrc` and is not tracked by git. Use it for machine-specific config:

```sh
# Example: work machine extras
export SOME_WORK_VAR=value
export GOPRIVATE="gitlab.com/yourorg/*"
```

### Adding a new config

1. Add the config directory to the dotfiles repo
2. Add the directory name to the `configs` array in `setup.sh`
3. Run `bash setup.sh` to create the symlink

### Adding a git hook

Drop an executable file into `git/hooks/`. It will be picked up by `core.hooksPath` in `git/config` and made executable by `setup.sh` on the next run.

---

## Updating

### Applying changes from the repo

```sh
cd ~/.config/dotfiles
git pull
bash setup.sh   # re-run to apply any new symlinks or permissions
```

### Installing new packages

Add the package to `brew/Brewfile`, then:

```sh
brew bundle --file=~/.config/dotfiles/brew/Brewfile
```

### Committing config changes

Config files are live-edited through their symlinks, so changes are already in the repo working tree. Just commit:

```sh
cd ~/.config/dotfiles
git add <changed files>
git commit -m "describe the change"
git push
```

The pre-commit hook will scan for secrets before the commit goes through.

---

## License

MIT — see [LICENSE](LICENSE).
