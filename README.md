# dotfiles

[![Lint](https://github.com/backmanfyi/dotfiles/actions/workflows/lint.yml/badge.svg)](https://github.com/backmanfyi/dotfiles/actions/workflows/lint.yml)
[![chezmoi smoke test](https://github.com/backmanfyi/dotfiles/actions/workflows/chezmoi-smoke-test.yml/badge.svg)](https://github.com/backmanfyi/dotfiles/actions/workflows/chezmoi-smoke-test.yml)
[![Secret scan](https://github.com/backmanfyi/dotfiles/actions/workflows/trufflehog.yml/badge.svg)](https://github.com/backmanfyi/dotfiles/actions/workflows/trufflehog.yml)

Personal macOS developer environment for platform and infrastructure engineering. Managed with [chezmoi](https://chezmoi.io) in symlink mode — the repo is the source of truth, `~/.config/*` symlinks back into it.

Migration plan and rationale: [`docs/chezmoi-migration.md`](docs/chezmoi-migration.md).

---

## Contents

- [What's included](#whats-included)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [How it works](#how-it-works)
- [Shell](#shell)
- [Tools](#tools)
- [Claude Code](#claude-code)
- [Security](#security)
- [CI/CD](#cicd)
- [Customisation](#customisation)
- [Updating](#updating)

---

## What's included

| Config | Tool | Purpose |
|---|---|---|
| `dot_config/zsh/` | zsh | Shell config, aliases, environment |
| `dot_config/nvim/` | Neovim (LazyVim) | Editor |
| `dot_config/tmux/` | tmux | Terminal multiplexer |
| `dot_config/ghostty/` | Ghostty | Terminal emulator |
| `dot_config/aerospace/` | AeroSpace | Tiling window manager |
| `dot_config/git/` | git | Version control, signing, aliases |
| `dot_config/starship/` | Starship | Shell prompt |
| `dot_config/private_ssh/` | SSH | Client config, 1Password agent (dir mode 0700) |
| `dot_config/bat/` | bat | Syntax-highlighted `cat` replacement |
| `dot_config/go/env` | Go | `GOPRIVATE`, toolchain env |
| `Brewfile` | Homebrew | Package manifest |
| `dot_claude/` | Claude Code | CLAUDE.md, MCP servers, custom agents, hooks, skills, templates |
| `scripts/` | — | Utility scripts (not deployed by chezmoi) |

---

## Prerequisites

- macOS (Apple Silicon)
- An internet connection for the initial setup
- [1Password](https://1password.com) with the SSH agent enabled (Settings → Developer → SSH Agent)
- `sudo` access (required for `/etc/zshenv` and `/etc/shells`)

---

## Installation

### Fresh machine

```sh
# 1. Xcode CLT (provides git)
xcode-select --install

# 2. Clone the repo and run the bootstrap script
git clone git@github.com:backmanfyi/dotfiles.git ~/.config/dotfiles
bash ~/.config/dotfiles/setup.sh
```

`setup.sh` installs chezmoi if it is not already present (via `brew` if available, otherwise the official installer into `~/.local/bin`), then runs `chezmoi init --apply --source ~/.config/dotfiles`.

The `--source` flag is required because `.chezmoi.toml.tmpl` pins `sourceDir` to that path — without it, chezmoi would look for source state at `~/.local/share/chezmoi`, which would be empty.

What `chezmoi init --apply` does:
1. Renders `.chezmoi.toml.tmpl` → `~/.config/chezmoi/chezmoi.toml`
2. Runs the `run_once_before_*` scripts (ZDOTDIR, Homebrew, brew bundle, shell, legacy cleanup)
3. Symlinks `~/.config/*` and `~/.claude/*` back into the source dir
4. Runs the `run_onchange_*` and `run_once_after_*` scripts (SSH Include, macOS defaults, AeroSpace reload, Accessibility prompt, launchd update-indicator)

Restart your terminal when complete.

### What chezmoi does on first apply

| Phase | Script | What happens |
|---|---|---|
| `before_01` | `run_once_before_01-zdotdir.sh.tmpl` | Writes `ZDOTDIR=~/.config/zsh` to `/etc/zshenv` (sudo) |
| `before_02` | `run_once_before_02-homebrew.sh.tmpl` | Installs Homebrew if missing |
| `before_03` | `run_onchange_before_03-brew-packages.sh.tmpl` | `brew bundle` — re-runs when Brewfile changes |
| `before_04` | `run_once_before_04-shell.sh.tmpl` | Registers brew zsh in `/etc/shells` + `chsh` |
| `before_05` | `run_once_before_05-cleanup-legacy.sh` | Removes legacy `~/.zshrc` and `~/.zshenv` |
| files | (chezmoi) | Symlinks `~/.config/*` and `~/.claude/*` into the source dir |
| `after_01` | `run_once_after_01-ssh-include.sh.tmpl` | Adds `Include ~/.config/ssh/config` to `~/.ssh/config` |
| `after_02` | `run_onchange_after_02-macos-defaults.sh.tmpl` | Fast key repeat, Finder, Dock, screenshots, etc. |
| `after_03` | `run_onchange_after_03-aerospace-reload.sh.tmpl` | `aerospace reload-config` |
| `after_04` | `run_once_after_04-accessibility.sh.tmpl` | Interactive Accessibility prompt (skips if AeroSpace already running) |
| `after_05` | `run_onchange_after_05-install-update-launchd.sh.tmpl` | Installs the launchd agent that powers the tmux update indicator |

### Manual follow-ups

A few things macOS won't let scripts do silently:

| What | Why | Where |
|---|---|---|
| Grant **AeroSpace** Accessibility | TCC requires a human toggle to allow window management | System Settings → Privacy & Security → Accessibility |
| Set **system accent** to dawnfox pine | macOS won't let `defaults write` set a Custom Color hex; preset accents (Pink, Purple, etc.) all clash with the cream terminal palette | System Settings → Appearance → Accent → Custom Color → `#286983` |

To preview what chezmoi would do without applying:

```sh
chezmoi diff             # unified diff of pending changes
chezmoi apply --dry-run  # full plan, no execution
```

---

## How it works

Everything lives in `~/.config/dotfiles`. chezmoi runs in symlink mode, so each tool finds its config at the expected XDG path via a symlink back into the source dir:

```
~/.config/git  →  ~/.config/dotfiles/dot_config/git
~/.config/nvim →  ~/.config/dotfiles/dot_config/nvim
~/.config/zsh/.zshrc  →  ~/.config/dotfiles/dot_config/zsh/dot_zshrc
~/.claude/CLAUDE.md  →  ~/.config/dotfiles/dot_claude/CLAUDE.md
...
```

chezmoi's source-state naming conventions:

- `dot_` prefix becomes a leading `.` at the target (`dot_zshrc` → `.zshrc`)
- `private_` on a directory gives it mode 0700 (used for the SSH config dir)
- `run_once_*` and `run_onchange_*` scripts live in `.chezmoiscripts/` and replace the old `setup.sh` steps

Editing a config file in the repo is immediately live — symlink mode means `~/.config/foo/bar` and `~/.config/dotfiles/dot_config/foo/bar` are the same file on disk. Commit when ready.

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

[LazyVim](https://lazyvim.org) distribution. Config at `dot_config/nvim/lua/`.

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

## Claude Code

Config at `dot_claude/`. Tracked:

| File / dir | Purpose |
|---|---|
| `CLAUDE.md` | Global instructions — workflow preferences, git rules, communication style, auto-allowed commands |
| `settings.json` | MCP server definitions and Claude Code preferences. No secrets — tokens are passed via environment variables |
| `agents/` | Custom subagent definitions (auth0-expert, owasp-top10-expert, terraform-expert, testing-expert, tracer, typescript-expert) |
| `hooks/` | Pre-tool-use hooks (skill-reminder, outbound-write-warn) |
| `skills/` | Custom skills (skill-creator) |
| `templates/` | Per-project CLAUDE.md templates (web, iac) |

Everything else in `~/.claude/` (sessions, tasks, cache, telemetry, etc.) is runtime state and not tracked.

---

## Security

### Commit signing

All commits are signed with your SSH key via 1Password:

```sh
# Verify signatures on recent commits
git log --show-signature -5
```

The `dot_config/git/allowed_signers` file maps your email to your public key for local verification.

### Secret scanning

[TruffleHog](https://github.com/trufflesecurity/trufflehog) runs at two points:

**Pre-commit hook** (`dot_config/git/hooks/pre-commit`) — blocks the commit if verified secrets are found in staged changes. Installed globally via `core.hooksPath` so it runs in every repository on the machine.

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
| `toml` | taplo | `dot_config/starship/config.toml` is valid TOML |
| `repo-checks` | bash | Source-state directories exist (`dot_config/*`, `dot_claude/*`), no hardcoded `/Users/<name>/` paths in any tracked file |

### `chezmoi-smoke-test.yml` — PRs to main (macOS)

Runs on a fresh `macos-latest` runner:
- `brew install chezmoi`
- `chezmoi init --source $(pwd)` — render `.chezmoi.toml.tmpl` against the checkout
- `chezmoi data` — confirm template variables resolve
- `chezmoi diff` — preview the plan
- `chezmoi apply --dry-run -v` — full plan, validates source-state parses cleanly
- `ruby -c Brewfile` — Brewfile syntax check
- Forbids hardcoded `/Users/` paths in tracked source-state files

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

```sh
chezmoi add ~/.config/newtool/config
```

chezmoi copies the file into source state with the correct prefix attributes and tracks it from then on.

### Adding a git hook

Drop the script into `dot_config/git/hooks/`. Set the executable bit (`chmod +x`) — git tracks it, and symlink-mode chezmoi preserves it through the deployed symlink.

---

## Updating

### Pulling remote changes

```sh
chezmoi update -v
```

This is `git pull --rebase --autostash` + `chezmoi apply` in one command. Any `run_onchange_*` script whose tracked content changed re-fires automatically (so editing the Brewfile in a remote commit triggers `brew bundle` on update).

### Checking what would change

```sh
chezmoi status       # M/A/D per file (source vs target)
chezmoi diff         # unified diff of pending changes
```

### Installing new packages

Add the package to `Brewfile`, then either:

- `chezmoi apply` — re-runs the `run_onchange_before_03-brew-packages` script (because the embedded Brewfile hash changes)
- `brew bundle --file=Brewfile` — direct invocation

### Committing config changes

Symlink mode means changes you make through `~/.config/foo` land in the source repo immediately. Just commit:

```sh
cd ~/.config/dotfiles    # or: chezmoi cd
git add <changed files>
git commit -m "describe the change"
git push
```

The pre-commit hook will scan for secrets before the commit goes through.

---

## License

MIT — see [LICENSE](LICENSE).
