# chezmoi migration plan

Status: **executed** — migration landed via PR #23.
This document was the source of truth during the migration from `setup.sh` + symlinks to [chezmoi](https://chezmoi.io). Kept as a historical artifact: §1–§5 describe the design decisions, §6–§9 describe the phased migration steps, §10–§12 capture risks and decisions. Inline section bodies may reference the planned numbering of scripts and files; the actual shipped numbering can drift slightly — when in doubt, check `.chezmoiscripts/` and `dot_config/` on disk.

---

## 1. Why migrate

Today the repo is:

- A bash bootstrap (`setup.sh`, 477 lines, 12 numbered steps).
- Hand-written `ln -s` for `~/.config/*`, `~/.claude/*`, and `~/.ssh/config` include.
- Implicit lifecycle: edit-in-repo, manual `git pull`, manual re-run of `setup.sh` when something needs reinstalling.
- No drift detection, no "you're behind upstream" surfacing, no per-machine variance.

chezmoi gives us:

- **Single binary, no daemon, no central service.** Backend is bbolt for state (one file at `~/.config/chezmoi/chezmoi.boltdb`), everything else is the existing git repo.
- **Declarative apply** with diff/status/verify commands.
- **`run_once_*` and `run_onchange_*` scripts** that replace bespoke idempotency checks in `setup.sh` — chezmoi tracks "did this run / did this content change" in its state DB.
- **Templating** for the (small) set of values that should vary per-machine.
- **`chezmoi update` as the one canonical command** for "pull and apply" — clean integration point for the tmux update indicator.

What we keep:

- The repo location (`~/.config/dotfiles`) — chezmoi can use any source dir.
- The edit-in-repo workflow — by running chezmoi in `mode = "symlink"` everything that doesn't have a templating/perms/secret carve-out stays a live symlink into the repo.
- All existing logic from `setup.sh`, just relocated to chezmoi scripts.

What we drop:

- `setup.sh` itself (replaced by `chezmoi init --apply <url>` + a handful of `run_once_*` scripts).
- The hand-rolled symlink helper (`_link`, `--force`, backup-and-replace logic) — chezmoi handles all of that.

---

## 2. chezmoi capability review (just the parts relevant to this repo)

### 2.1 Source-state file naming

chezmoi parses each filename in the source dir as a sequence of prefix attributes + the target name. Combined prefixes in order: `remove_ external_ exact_ private_ readonly_ dot_ encrypted_ empty_ executable_ create_ modify_ run_ once_|onchange_ before_|after_ literal_`. Examples we'll use:

| Source path | Target | Meaning |
|---|---|---|
| `dot_zshrc` | `~/.zshrc` | rename leading `dot_` to `.` |
| `private_dot_ssh/config` | `~/.ssh/config` | strip group/world perms on the dir |
| `executable_dot_local/bin/foo` | `~/.local/bin/foo` (0755) | set exec bit |
| `run_once_before_01-zdotdir.sh` | (script, runs once) | runs before file apply phase |
| `run_onchange_install-brew-packages.sh.tmpl` | (script, runs when contents change) | the Brewfile lives in here so changes trigger re-run |
| `symlink_dot_config/Code/User/settings.json.tmpl` | symlink at `~/.config/Code/User/settings.json` whose target is the template's output | rendered to a path string |

### 2.2 Symlink mode

Two flavours:

1. **Per-file `symlink_` prefix** — source file's *contents* become the symlink *target*. Useful for one-offs.
2. **Global `mode = "symlink"`** in `chezmoi.toml` — every eligible target is materialised as a symlink pointing into the source dir. The carve-outs (always copied, never symlinked) are: encrypted, executable, private, templated files. Everything else stays "edit in repo, see live in `$HOME`".

We'll use **global symlink mode**. Files that need templating (`chezmoi.toml.tmpl`, the brew install script, hostname-dependent things) are automatically excluded and become managed copies — which is correct behaviour.

**Important consequence of the carve-out** — we deliberately avoid using `executable_` and `private_` prefixes on **individual files**, because both would force a real-file copy (breaking live-edit). Instead:

- Executable scripts/hooks keep their +x bit in git (mode 100755) and are deployed as symlinks. The symlink resolves to the source file and execute access uses the source's mode. No prefix needed.
- Sensitive files like `~/.config/ssh/config` are protected by their parent **directory** being `private_` (mode 0700). The directory becomes a real dir (chezmoi creates it with restricted perms), but the file inside can still be a symlink. SSH and similar tools are satisfied because the dir mode prevents anyone else from traversing in.

### 2.3 Scripts (replacement for `setup.sh` steps)

| Prefix | Semantics |
|---|---|
| `run_` | runs every `chezmoi apply` |
| `run_once_` | runs once per unique SHA256 of post-template content. State at `~/.config/chezmoi/chezmoi.boltdb`, bucket `scriptState` |
| `run_onchange_` | runs when content changes since last successful run, keyed by filename. State bucket `entryState` |
| `run_before_` | executes in apply phase 4 (before files are written) |
| `run_after_` | executes in apply phase 6 (after files are written) |

Ordering is strictly ASCII on the stripped target name. We prefix with `NN-` numbers to keep deterministic order. Scripts placed under `.chezmoiscripts/` at source root run normally but **do not** create a corresponding target dir — useful for keeping these out of `$HOME`.

Idiom for "re-run when an external file changes": embed a hash of the dependency in a script comment so the script's own SHA256 changes:

```sh
# Brewfile hash: {{ include "Brewfile" | sha256sum }}
brew bundle --file="$(chezmoi source-path)/Brewfile"
```

`run_once_*` scripts skip on a fresh machine if the BoltDB has already recorded their SHA256. Resetting state: `chezmoi state delete-bucket --bucket=scriptState`.

### 2.4 Hooks (different from scripts)

Hooks are config-level, fire around chezmoi *commands* themselves (`apply`, `update`, `read-source-state`, etc.), and **always run including under `--dry-run`**. We don't need any for this migration but worth knowing they exist for future work (e.g. unlocking a password manager pre-`read-source-state`).

### 2.5 Templating

- `.tmpl` suffix → Go `text/template` + Sprig + chezmoi functions.
- Static data: `.chezmoidata/*.{json,yaml,toml}` files at source root.
- Per-machine data: `data = { ... }` block in `~/.config/chezmoi/chezmoi.toml`, rendered from `.chezmoi.toml.tmpl` at `chezmoi init` time with `promptStringOnce` / `promptBoolOnce`.

Built-in variables we'll touch: `.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.homeDir`, `.chezmoi.sourceDir`. macOS hostname is volatile; if we need stable per-machine identity later, use `output "scutil" "--get" "ComputerName" | trim`.

### 2.6 Externals

`.chezmoiexternal.toml` lets chezmoi fetch files/archives/git repos. Refresh on a duration. **Footgun:** externals are validated on every `apply`/`diff`/`verify`, so the docs warn against large binaries. We have no externals today and probably never will — neovim plugins are managed by lazy.nvim via `lazy-lock.json`, which is already vendored in this repo. Skip externals entirely.

### 2.7 Commands we'll use

| Command | Purpose |
|---|---|
| `chezmoi init --source ~/.config/dotfiles` | one-time init pointing at the existing repo |
| `chezmoi apply -v` | make `$HOME` match source state |
| `chezmoi update -v` | `git pull` + `apply` in one shot |
| `chezmoi status` | two-column dirty/diff status |
| `chezmoi diff` | unified diff of pending changes |
| `chezmoi edit <file> --apply` | open source in `$EDITOR`, apply on save |
| `chezmoi add <path>` | bring an existing dotfile into source state |
| `chezmoi re-add` | refresh source from current target (the inverse of apply) |
| `chezmoi managed` | list everything chezmoi knows about |
| `chezmoi unmanaged` | the inverse — things in `$HOME` not yet tracked |
| `chezmoi chattr +executable file` | flip attributes without manual rename |
| `chezmoi cd` | subshell in the source dir |
| `chezmoi git -- <args>` | git wrapped to the source dir |
| `chezmoi doctor` | environment / dependency check |
| `chezmoi state delete-bucket --bucket=…` | nuke `run_once_` or `run_onchange_` memory |

### 2.8 Footguns we're explicitly steering around

| Footgun | Mitigation |
|---|---|
| `.chezmoiignore` matches **target paths**, not source. So write `.zshrc` not `dot_zshrc`. | Documented in §6 below. |
| Symlink mode's carve-outs aren't obvious — anything with `private_`, `executable_`, encrypted, or `.tmpl` becomes a real file not a symlink. | Acceptable. SSH and the scripts genuinely need the file form. |
| `run_once_` keys off SHA256 globally; renaming a `run_once_*.sh` does not cause re-run if contents are unchanged. | Use `run_onchange_` whenever we want filename to matter. |
| BoltDB is per-machine, not in the repo. Restoring a machine without restoring state re-fires `run_once_*` scripts. | Acceptable — they're idempotent (already designed to be by `setup.sh`'s author, i.e. us). |
| `chezmoi apply --dry-run` does NOT execute scripts. | We rely on `--dry-run` for apply-time review; we accept script-side verification happens on real runs only. |
| Externals validate on every command. | We don't use externals. |
| `exact_` on a dir DELETES untracked children. | We don't use `exact_` anywhere in this plan. |

---

## 3. Current repo requirements (what the migration must preserve)

### 3.1 File inventory (current)

```
aerospace/aerospace.toml           → ~/.config/aerospace/aerospace.toml
bat/config                          → ~/.config/bat/config
Brewfile (was brew/Brewfile)        → consumed by run_onchange script, not deployed
ghostty/config                      → ~/.config/ghostty/config
git/{config,alias.ini,allowed_signers,ignore,themes.ini} → ~/.config/git/*
git/hooks/pre-commit                → ~/.config/git/hooks/pre-commit (chmod +x)
go/env                              → ~/.config/go/env  (NEW deploy — fixes existing bug)
nvim/{init.lua,lazy-lock.json,lazyvim.json,lua/,after/} → ~/.config/nvim/*
ssh/config                          → ~/.config/ssh/config (chmod 600, dir 700)
starship/config.toml                → ~/.config/starship/config.toml
tmux/tmux.conf                      → ~/.config/tmux/tmux.conf
tmux/scripts/*                      → ~/.config/tmux/scripts/*
zsh/zshrc                           → ~/.config/zsh/.zshrc
zsh/zshenv                          → ~/.config/zsh/.zshenv
claude/CLAUDE.md                    → ~/.claude/CLAUDE.md
claude/settings.json                → ~/.claude/settings.json
claude/agents/                      → ~/.claude/agents/
claude/hooks/                       → ~/.claude/hooks/ (chmod +x on all files)
claude/skills/                      → ~/.claude/skills/
claude/templates/                   → ~/.claude/templates/  (NEW deploy)
```

Files NOT to manage with chezmoi (kept in repo only, not deployed):

```
.githooks/pre-commit                 # repo-local hook chain
.github/workflows/*                  # CI
Brewfile                             # data file consumed by a script (at repo root)
README.md, LICENSE
scripts/*                            # repo-local utility scripts
```

### 3.2 Non-file operations (`setup.sh` 12 steps)

Mapped to chezmoi destinations:

| `setup.sh` step | New home in chezmoi |
|---|---|
| 1. ZDOTDIR in `/etc/zshenv` (sudo) | `.chezmoiscripts/run_once_before_01-zdotdir.sh.tmpl` (darwin-only) |
| 2. Homebrew install | `.chezmoiscripts/run_once_before_02-homebrew.sh.tmpl` |
| 2. `brew bundle` | `.chezmoiscripts/run_onchange_before_03-brew-packages.sh.tmpl` (hash of Brewfile embedded) |
| 3. Register `/opt/homebrew/bin/zsh` in `/etc/shells` + `chsh` | `.chezmoiscripts/run_once_before_04-shell.sh.tmpl` |
| 4. Symlinks for `~/.config/*` | **chezmoi itself**, via `mode = "symlink"` + `dot_config/...` source layout |
| 5. Claude Code config | **chezmoi itself**, via `dot_claude/...` source layout |
| 5. `chmod +x` on Claude hooks | git already tracks them as mode 100755; symlink-mode deploy inherits +x via the symlink → source file |
| 6. Git hooks `chmod +x` | Same — git mode bits preserved through symlink |
| 7. SSH `Include` line in `~/.ssh/config` | `.chezmoiscripts/run_once_after_01-ssh-include.sh.tmpl` |
| 8. SSH permissions (700 dir) | `dot_config/private_ssh/` — `private_` on the dir gives mode 0700; file inside is a symlink with no per-file prefix |
| 9. Remove legacy `~/.zshrc` / `~/.zshenv` | `.chezmoiscripts/run_once_before_05-cleanup-legacy.sh` |
| 10. macOS defaults | `.chezmoiscripts/run_onchange_after_02-macos-defaults.sh.tmpl` (darwin-only, re-runs when contents change) |
| 11. AeroSpace reload | `.chezmoiscripts/run_onchange_after_03-aerospace-reload.sh.tmpl` |
| 12. Accessibility prompts | `.chezmoiscripts/run_once_after_04-accessibility.sh.tmpl` (skips if AeroSpace already running) |

### 3.3 CI

`.github/workflows/setup-smoke-test.yml` exists today and:

- syntax-checks `setup.sh`
- runs `setup.sh --dry-run`
- runs `setup.sh --help`
- expects unknown flags to exit non-zero
- ruby-syntax-checks the Brewfile
- forbids hard-coded `/Users/` paths in `setup.sh`

Migration must replace this with a chezmoi-equivalent smoke test:

- install chezmoi on the runner (`brew install chezmoi` is already in our Brewfile; CI may need to install it separately)
- `chezmoi init --source $(pwd)` against the checkout
- `chezmoi apply --dry-run -v`
- `chezmoi verify`
- ruby-syntax-check on the Brewfile (still applies — it stays a file, just included by a script)

---

## 4. Target source-tree layout

```
~/.config/dotfiles/
├── .chezmoi.toml.tmpl                    # rendered at chezmoi init → ~/.config/chezmoi/chezmoi.toml
├── .chezmoiignore                        # patterns matching target paths to skip
├── .chezmoiversion                       # min chezmoi version
├── .chezmoidata/
│   └── paths.yaml                        # static data (homebrew prefix per arch, etc.)
├── .chezmoiscripts/                      # scripts that don't produce a target dir
│   ├── run_once_before_01-zdotdir.sh.tmpl
│   ├── run_once_before_02-homebrew.sh.tmpl
│   ├── run_onchange_before_03-brew-packages.sh.tmpl
│   ├── run_once_before_04-shell.sh.tmpl
│   ├── run_once_before_05-cleanup-legacy.sh
│   ├── run_once_after_01-ssh-include.sh.tmpl
│   ├── run_onchange_after_02-macos-defaults.sh.tmpl
│   ├── run_onchange_after_03-aerospace-reload.sh.tmpl
│   ├── run_once_after_04-accessibility.sh.tmpl
│   └── run_once_after_05-install-update-launchd.sh.tmpl   # tmux update indicator (Phase 7)
│
├── dot_config/                           # → ~/.config/
│   ├── aerospace/aerospace.toml
│   ├── bat/config
│   ├── ghostty/config
│   ├── git/
│   │   ├── config
│   │   ├── alias.ini
│   │   ├── allowed_signers
│   │   ├── ignore
│   │   ├── themes.ini
│   │   └── hooks/pre-commit              # +x preserved via git mode bits + symlink
│   ├── go/env
│   ├── nvim/                             # init.lua, lua/, after/, lazy-lock.json, lazyvim.json
│   ├── private_ssh/                      # → ~/.config/ssh/ (mode 0700)
│   │   └── config                        # symlinked; protected by parent dir mode
│   ├── starship/config.toml
│   ├── tmux/
│   │   ├── tmux.conf
│   │   └── scripts/
│   │       ├── check-updates.sh          # NEW — drives the tmux indicator
│   │       ├── get-AWS-profile.sh
│   │       ├── kill_session.sh
│   │       ├── zoom.sh
│   │       ├── assume-role.sh
│   │       ├── aws-sso-assume-role.sh
│   │       └── macros/
│   └── zsh/
│       ├── dot_zshrc                     # → ~/.config/zsh/.zshrc
│       └── dot_zshenv                    # → ~/.config/zsh/.zshenv
│
├── dot_claude/                            # → ~/.claude/
│   ├── CLAUDE.md
│   ├── settings.json
│   ├── agents/                            # *.md files, just symlinked
│   ├── hooks/                             # +x preserved via git mode bits + symlink
│   │   ├── skill-reminder.sh
│   │   └── outbound-write-warn.sh
│   ├── skills/                            # may contain skill dirs
│   └── templates/                         # CLAUDE.iac.md, CLAUDE.web.md
│
├── Brewfile                               # data, NOT deployed; consumed by run_onchange script
│
├── .githooks/pre-commit                   # NOT deployed; for the dotfiles repo itself
├── .github/workflows/                     # NOT deployed; CI
├── README.md, LICENSE, .gitignore
└── docs/                                  # this file lives here
    └── chezmoi-migration.md
```

`.chezmoiignore` content (target paths):

```
README.md
LICENSE
Brewfile
.gitignore
.gitmodules
docs
docs/**
scripts
scripts/**
.githooks
.githooks/**
.github
.github/**
.chezmoi.toml.tmpl
```

Note: chezmoi auto-ignores `.chezmoi*` / `.chezmoiscripts/` / `.chezmoidata/` / `.chezmoiexternal*`. We list `.chezmoi.toml.tmpl` defensively in case some surface treats it as data.

---

## 5. `chezmoi.toml` (the rendered config)

`.chezmoi.toml.tmpl` at source root:

```toml
sourceDir = "{{ .chezmoi.homeDir }}/.config/dotfiles"
mode = "symlink"

[diff]
exclude = ["scripts"]   # don't dump 40-line bash scripts on every `chezmoi diff`
pager = "delta"         # we have git-delta in Brewfile

[status]
exclude = ["scripts"]

[edit]
apply = true            # `chezmoi edit foo` always re-applies after save
watch = false

[git]
autoCommit = false
autoPush   = false      # CLAUDE.md says: never push without asking

[data]
email = "claude@backman.fyi"
```

We don't use prompts on first init — the only piece of state we'd vary per machine is `data.email`, which is already known from the user's CLAUDE.md. If/when we get a second machine with a different identity, switch to:

```toml
{{- $email := promptStringOnce . "email" "Git/Claude email" -}}
[data]
email = {{ $email | quote }}
```

---

## 6. Migration phases

### Phase 0 — preparation (no chezmoi installed yet)

- Read this doc end-to-end. Verify the file inventory in §3.1 against `git ls-files` and adjust if anything has moved.
- Confirm `chezmoi` is in `brew/Brewfile`. (It will need to be added — currently absent.)
- Create a working branch: `chezmoi/migration`.
- Open a GitHub issue tracking the migration (per CLAUDE.md workflow).

### Phase 1 — install chezmoi and add `.chezmoi.toml.tmpl`

```bash
brew install chezmoi
```

Add `chezmoi` to `brew/Brewfile` so future installs pick it up.

Write `.chezmoi.toml.tmpl` at repo root (contents above). Run:

```bash
chezmoi init --source ~/.config/dotfiles
chezmoi data        # sanity-check: renders config, shows merged data
chezmoi doctor      # surfaces missing dependencies
```

This will create `~/.config/chezmoi/chezmoi.toml` from the template. State DB is created on first `apply`.

At this point chezmoi knows about the repo but **nothing in `$HOME` has changed** — the existing symlinks remain. We'll only break them in phase 4.

### Phase 2 — rename files to chezmoi conventions (no behaviour change)

This is a single bulk rename commit. The repo stops working with `setup.sh` after this commit and only works with chezmoi from then on.

```
aerospace/                  → dot_config/aerospace/
bat/                        → dot_config/bat/
brew/Brewfile               → Brewfile                       # flattens brew/ subdir
ghostty/                    → dot_config/ghostty/
git/                        → dot_config/git/
go/                         → dot_config/go/                 # NEW deploy (fixes setup.sh bug)
nvim/                       → dot_config/nvim/
starship/                   → dot_config/starship/
tmux/                       → dot_config/tmux/               # whole-dir move; scripts retain +x via git
zsh/                        → dot_config/zsh/
zsh/zshrc                   → dot_config/zsh/dot_zshrc        # within-dir rename for leading dot
zsh/zshenv                  → dot_config/zsh/dot_zshenv
ssh/                        → dot_config/private_ssh/         # private_ on DIR (mode 0700)
claude/                     → dot_claude/                     # hooks/ keeps +x via git
claude/templates/           → dot_claude/templates/           # NEW deploy (covered by whole-dir move)
```

No `executable_` or per-file `private_` prefixes — git's mode bits + symlink-mode deploy handle execute and the parent-dir `private_` handles SSH protection. See §2.2.

Use `git mv` so history is preserved. After the renames, **do not** run `chezmoi apply` yet — the existing symlinks in `$HOME` still point at the *old* paths, which no longer exist. That's fine; we fix it in phase 4.

### Phase 3 — write the chezmoi scripts

Drop the contents of `setup.sh`'s steps 1–3, 6–12 into `.chezmoiscripts/`. Each script is a thin wrapper around the existing logic. Step bodies are copy-pasted from `setup.sh` more or less verbatim, with two changes:

- `${DOTFILES_DIR}` becomes `{{ .chezmoi.sourceDir }}` (templated at render time)
- `${HOME}` and `${CONFIG_DIR}` come from `{{ .chezmoi.homeDir }}` and `{{ .chezmoi.homeDir }}/.config`

Each script's `{{ if eq .chezmoi.os "darwin" -}}` … `{{ end -}}` guard makes it OS-conditional (everything in `setup.sh` today is darwin-only).

Script contents are sketched in §8.

### Phase 4 — first `chezmoi apply`

Before applying:

```bash
# Manually remove the old symlinks so chezmoi can take ownership.
# Loop captures all of them deterministically.
for link in \
  ~/.config/aerospace ~/.config/bat ~/.config/ghostty \
  ~/.config/git ~/.config/nvim ~/.config/starship ~/.config/tmux \
  ~/.config/go ~/.config/zsh/.zshrc ~/.config/zsh/.zshenv \
  ~/.claude/CLAUDE.md ~/.claude/settings.json \
  ~/.claude/agents ~/.claude/hooks ~/.claude/skills ~/.claude/templates; do
  if [[ -L "$link" ]]; then rm "$link"; fi
done
```

Then:

```bash
chezmoi diff           # review every change chezmoi wants to make
chezmoi apply -v -n    # dry-run first
chezmoi apply -v       # for real
```

Expected result: every old symlink is recreated by chezmoi, now pointing into `~/.config/dotfiles/dot_config/...` instead of `~/.config/dotfiles/...`. `run_once_*` scripts fire once and write to the BoltDB. `run_onchange_*` scripts fire once on first apply.

Verify with:

```bash
chezmoi status            # should be empty
chezmoi verify; echo $?   # should be 0
ls -la ~/.config/aerospace   # should be a symlink to a path under dotfiles
echo $SHELL && which zsh     # sanity check shell didn't change
nvim +q                      # sanity check nvim still loads
```

### Phase 5 — replace CI smoke test

Update `.github/workflows/setup-smoke-test.yml`:

```yaml
name: chezmoi smoke test

on:
  pull_request:
    branches: [main]

concurrency:
  group: smoke-test-${{ github.head_ref }}
  cancel-in-progress: true

jobs:
  smoke-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: brew install chezmoi
      - name: chezmoi init
        run: chezmoi init --source "$(pwd)"
      - name: chezmoi diff
        run: chezmoi diff
      - name: chezmoi apply --dry-run
        run: chezmoi apply --dry-run -v
      - name: chezmoi verify
        run: chezmoi verify
      - name: Validate Brewfile syntax
        run: ruby -c Brewfile
```

Rename the workflow file to `chezmoi-smoke-test.yml`.

### Phase 6 — retire `setup.sh`

Replace `setup.sh` with a one-line stub that prints the new bootstrap command and exits:

```bash
#!/usr/bin/env bash
echo "setup.sh has been retired. Use chezmoi instead:"
echo
echo "  sh -c \"\$(curl -fsLS https://get.chezmoi.io)\" -- init --apply backman-fyi/dotfiles"
echo
echo "On an existing machine: chezmoi update -v"
exit 1
```

Keep the stub for one release/grace period, then delete.

Update `README.md` with the new fresh-machine bootstrap and daily commands.

### Phase 7 — tmux update notification

See §9 for the full design. This phase wires up:

- `dot_config/tmux/scripts/check-updates.sh` (the polling script). No `executable_` prefix — git tracks it as mode 100755 and symlink-mode preserves +x through the deployed symlink.
- A `run_onchange_after_05-install-update-launchd.sh.tmpl` that installs `~/Library/LaunchAgents/fyi.backman.chezmoi-check.plist` and `launchctl load`s it. (`run_onchange_` so plist edits redeploy automatically.)
- Updated `dot_config/tmux/tmux.conf` adding the status-bar indicator and `prefix + U` binding.

---

## 7. Lifecycle workflows (post-migration)

### 7.1 Editing a file day-to-day

No change from today, because of `mode = "symlink"`:

```bash
cd ~/.config/dotfiles                    # or `chezmoi cd`
nvim dot_config/aerospace/aerospace.toml # symlink target; edit is live in ~/.config/aerospace
# verify
chezmoi status                            # nothing — no diff between source & target
git add -p && git commit -m "..." && git push
```

For files that aren't symlinked (templates, private SSH config), use the apply-on-save flow:

```bash
chezmoi edit --apply ~/.ssh/config
```

### 7.2 Pulling remote changes

One command:

```bash
chezmoi update -v
```

= `git pull --autostash --rebase` in the source dir + `chezmoi apply`. The `run_onchange_*` scripts re-fire whenever their hashed contents change (so editing the Brewfile in a remote commit triggers `brew bundle` automatically on `chezmoi update`).

### 7.3 Drift detection

Before pulling (or any time):

```bash
chezmoi status       # M = modified, A = added, D = deleted (per source/target)
chezmoi diff         # unified diff of everything pending
```

The tmux indicator (§9) surfaces "you're behind upstream" passively.

### 7.4 Fresh machine bootstrap

```bash
xcode-select --install
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply git@github.com:backmanfyi/dotfiles.git
```

On a fresh machine `chezmoi init --apply`:

1. Clones the repo into `~/.config/dotfiles` (overridden by `sourceDir` in `.chezmoi.toml.tmpl`).
2. Renders `.chezmoi.toml.tmpl` → `~/.config/chezmoi/chezmoi.toml`.
3. Runs all `run_once_before_*` scripts in ASCII order (ZDOTDIR → Homebrew → Brewfile → shell → cleanup-legacy).
4. Materialises files and symlinks.
5. Runs all `run_onchange_*` scripts (Brewfile install, macOS defaults).
6. Runs all `run_once_after_*` scripts (SSH include, accessibility prompt, launchd plist install).

Total interaction: same as today — sudo prompts for ZDOTDIR / shells / chsh, and the System Settings click-through for Accessibility.

### 7.5 Per-machine differences (future)

Migrate the file from `dot_*` to `dot_*.tmpl`. Branch on `{{ if eq .chezmoi.os "darwin" }}` or `{{ if .work }}` (if we add a `work` bool to `.chezmoi.toml.tmpl`'s prompts). Example for a work-vs-personal git config:

```ini
# dot_config/git/config.tmpl
[user]
{{- if .work }}
    email = lars@workcorp.com
{{- else }}
    email = claude@backman.fyi
{{- end }}
    name = Lars Backman
```

### 7.6 Adding a new dotfile

```bash
chezmoi add ~/.config/newtool/config
# chezmoi copies the file into source state with the right prefix attributes
git -C ~/.config/dotfiles add . && git commit -m "feat: track newtool config"
```

### 7.7 Removing a tracked file

```bash
chezmoi forget ~/.config/oldtool/config     # leaves $HOME alone
# OR
chezmoi destroy ~/.config/oldtool/config    # removes from BOTH source and $HOME (--force)
```

### 7.8 Nuking state (rare, but useful to know)

```bash
chezmoi state delete-bucket --bucket=scriptState   # forget run_once history
chezmoi state delete-bucket --bucket=entryState    # forget run_onchange history
```

---

## 8. Migration script bodies (sketches)

Each is a near-verbatim port of the corresponding `setup.sh` step. Annotations only highlight what changes from the original.

### `.chezmoiscripts/run_once_before_01-zdotdir.sh.tmpl`

```sh
{{- if eq .chezmoi.os "darwin" -}}
#!/usr/bin/env bash
set -euo pipefail

if grep -qE '^[[:space:]]*export[[:space:]]+ZDOTDIR=' /etc/zshenv 2>/dev/null; then
  exit 0
fi

printf '\nexport XDG_CONFIG_HOME="$HOME/.config"\nexport ZDOTDIR="${XDG_CONFIG_HOME}/zsh"\n' \
  | sudo tee -a /etc/zshenv > /dev/null
{{- end -}}
```

### `.chezmoiscripts/run_once_before_02-homebrew.sh.tmpl`

```sh
{{- if eq .chezmoi.os "darwin" -}}
#!/usr/bin/env bash
set -euo pipefail

if command -v brew >/dev/null 2>&1; then
  exit 0
fi

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
{{- end -}}
```

### `.chezmoiscripts/run_onchange_before_03-brew-packages.sh.tmpl`

```sh
{{- if eq .chezmoi.os "darwin" -}}
#!/usr/bin/env bash
# Brewfile hash: {{ include "Brewfile" | sha256sum }}
set -euo pipefail

eval "$(/opt/homebrew/bin/brew shellenv)"
brew bundle --quiet --file="{{ .chezmoi.sourceDir }}/Brewfile"
{{- end -}}
```

The embedded SHA256 of `Brewfile` means *any* edit to the Brewfile changes this script's own SHA256 → chezmoi re-runs it. No hidden state.

### `.chezmoiscripts/run_once_before_04-shell.sh.tmpl`

```sh
{{- if eq .chezmoi.os "darwin" -}}
#!/usr/bin/env bash
set -euo pipefail
BREW_ZSH="/opt/homebrew/bin/zsh"

if ! grep -qF "${BREW_ZSH}" /etc/shells 2>/dev/null; then
  echo "${BREW_ZSH}" | sudo tee -a /etc/shells > /dev/null
fi

if [[ "${SHELL:-}" != "${BREW_ZSH}" ]]; then
  chsh -s "${BREW_ZSH}"
fi
{{- end -}}
```

### `.chezmoiscripts/run_once_before_06-cleanup-legacy.sh`

```sh
#!/usr/bin/env bash
set -euo pipefail
for f in "${HOME}/.zshrc" "${HOME}/.zshenv"; do
  if [[ -f "${f}" && ! -L "${f}" ]]; then
    rm "${f}"
  fi
done
```

### `.chezmoiscripts/run_onchange_07-macos-defaults.sh.tmpl`

```sh
{{- if eq .chezmoi.os "darwin" -}}
#!/usr/bin/env bash
set -euo pipefail

# Keyboard
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Finder
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.4
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false

# Screenshots
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# Dialogs
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Security
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
{{- end -}}
```

### `.chezmoiscripts/run_once_after_05-ssh-include.sh.tmpl`

```sh
{{- if eq .chezmoi.os "darwin" -}}
#!/usr/bin/env bash
set -euo pipefail

SYSTEM_SSH="${HOME}/.ssh/config"
MANAGED_INCLUDE="Include ~/.config/ssh/config"

mkdir -p "${HOME}/.ssh"

if [[ -f "${SYSTEM_SSH}" ]] && grep -qE '^[[:space:]]*Include[[:space:]]+~/.config/ssh/config' "${SYSTEM_SSH}"; then
  exit 0
fi

printf '\n# Managed dotfiles config — edit at ~/.config/dotfiles\n%s\n' "${MANAGED_INCLUDE}" >> "${SYSTEM_SSH}"
chmod 600 "${SYSTEM_SSH}"
{{- end -}}
```

Note: `~/.ssh/config` itself is **not** managed by chezmoi (we only manage `~/.config/ssh/config` and Include it from the system file). This avoids chezmoi fighting OrbStack and other tools that mutate `~/.ssh/config`.

### `.chezmoiscripts/run_onchange_after_08-aerospace-reload.sh.tmpl`

```sh
{{- if eq .chezmoi.os "darwin" -}}
#!/usr/bin/env bash
# Aerospace config hash: {{ include "dot_config/aerospace/aerospace.toml" | sha256sum }}
set -euo pipefail

if [[ ! -d /Applications/AeroSpace.app ]]; then
  exit 0
fi

if command -v aerospace >/dev/null 2>&1 && pgrep -x AeroSpace >/dev/null 2>&1; then
  aerospace reload-config || true
fi
{{- end -}}
```

### `.chezmoiscripts/run_once_after_09-accessibility.sh.tmpl`

```sh
{{- if eq .chezmoi.os "darwin" -}}
#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d /Applications/AeroSpace.app ]]; then
  exit 0
fi

if [[ ! -t 0 ]]; then
  echo "Non-interactive — grant Accessibility manually for AeroSpace" >&2
  exit 0
fi

open -a "AeroSpace" 2>/dev/null || true
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

printf '\nAction needed: enable Accessibility for AeroSpace\n'
read -r -p 'Press enter once enabled (or Ctrl-C to skip)... ' _
{{- end -}}
```

---

## 9. Tmux update notification + shortcut

### 9.1 The polling script

`dot_config/tmux/scripts/check-updates.sh`:

```sh
#!/usr/bin/env bash
# Background-poll the dotfiles remote for new commits on main and write a
# presence-only indicator that the tmux status bar consumes. Compares
# against origin/main directly so the indicator reflects "main has
# commits I haven't pulled" regardless of the currently checked-out branch.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi"
STATE_FILE="${STATE_DIR}/update-status"
mkdir -p "$STATE_DIR"

if ! chezmoi git -- fetch --quiet origin main 2>/dev/null; then
  exit 0
fi

behind=$(chezmoi git -- rev-list --count main..origin/main 2>/dev/null || echo 0)

if [ "$behind" -eq 0 ]; then
  : > "$STATE_FILE"
else
  printf '  ' > "$STATE_FILE"
fi
```

Output is intentionally tiny — just the glyph or nothing.  is a Nerd Font cloud-download character. No count: presence-only, as decided in §12.

### 9.2 launchd agent

`launchd` is the right place for periodic background work on macOS — survives across tmux sessions, survives reboot via `RunAtLoad`, doesn't tie up a tmux pane.

`.chezmoiscripts/run_onchange_after_05-install-update-launchd.sh.tmpl`:

```sh
{{- if eq .chezmoi.os "darwin" -}}
#!/usr/bin/env bash
set -euo pipefail

PLIST="${HOME}/Library/LaunchAgents/fyi.backman.chezmoi-check.plist"
SCRIPT="{{ .chezmoi.homeDir }}/.config/tmux/scripts/check-updates.sh"

cat > "${PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>fyi.backman.chezmoi-check</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>${SCRIPT}</string>
  </array>
  <key>StartInterval</key><integer>900</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>${HOME}/.cache/chezmoi-check.log</string>
  <key>StandardErrorPath</key><string>${HOME}/.cache/chezmoi-check.log</string>
</dict>
</plist>
EOF

# (re)load
launchctl unload "${PLIST}" 2>/dev/null || true
launchctl load "${PLIST}"
{{- end -}}
```

Why 900s (15 min): polling cadence is a network/usefulness tradeoff. 15 min is small enough to surface a recent push, large enough that you'd never notice the load.

### 9.3 Tmux config additions

In `dot_config/tmux/tmux.conf`, append a status segment that reads the state file, plus a binding for "pull and apply":

```tmux
# chezmoi update indicator — populated by ~/.config/tmux/scripts/check-updates.sh
# via launchd every 15 min. Empty file = silent.
set -ga status-right '#(cat ${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi/update-status 2>/dev/null)'

# prefix + U → pull + apply in a popup so you see output and can cancel
bind-key U display-popup -E -h 80% -w 80% \
  "chezmoi update -v; echo; echo '── press any key to close ──'; read -n 1"
```

When the polling script finds updates, the status bar shows just ``. After running `prefix + U` and successfully updating, the next poll clears the indicator.

### 9.4 Optional: in-pane on-demand check

For when you're impatient and want to refresh the indicator immediately:

```tmux
bind-key u run-shell -b "${XDG_CONFIG_HOME}/tmux/scripts/check-updates.sh"
```

---

## 10. Risks and rollback

### Risks

| Risk | Mitigation |
|---|---|
| First `chezmoi apply` blows away symlinks we forgot about | Phase 4 explicitly enumerates the symlinks to remove; `chezmoi diff` before applying surfaces anything unexpected |
| `run_once_*` script fails midway through fresh-machine bootstrap | Each script is `set -euo pipefail`, focused, idempotent; re-running `chezmoi apply` resumes |
| BoltDB state lost (e.g. wipe `~/.config/chezmoi/`) and `run_once_*` re-fires | All `run_once_*` scripts are designed to be idempotent (no-op if already done) |
| Symlink mode carve-outs surprise us — e.g. an `executable_` file we expected to be a symlink is a copy | Documented in §2.2; only impacts hook files and scripts, which we don't edit live |
| CI smoke test regresses | Phase 5 replaces the workflow; runs `chezmoi apply --dry-run` and `chezmoi verify` on every PR |
| Lazy.nvim's `lazy-lock.json` updated by nvim itself diverges from source | This file is owned by nvim, not by us. Keep it as a regular tracked file in `dot_config/nvim/` (symlink mode preserves edit-in-place); commit updates separately as before |

### Rollback (any time before Phase 6)

```bash
git checkout main               # if migration was on a branch
chezmoi purge                   # removes chezmoi state files (NOT $HOME files)
bash setup.sh                   # re-establishes the old symlinks
```

`chezmoi purge` does not touch `$HOME` or the source repo — only chezmoi's own state files. Safe.

After Phase 6 (`setup.sh` retired), rollback is more involved: restore `setup.sh` from git history, then `bash setup.sh`. Practically: just keep the migration on a branch until we're confident.

---

## 11. Acceptance criteria

Migration is done when:

- `chezmoi status` is empty after `chezmoi apply` on the dev machine.
- `chezmoi verify` exits 0.
- All apps still work (manual smoke: open ghostty → tmux → nvim → aerospace).
- CI smoke test passes on a fresh PR.
- `chezmoi update` is the documented daily command in README.
- Fresh-machine bootstrap runs successfully end-to-end via pre-clone + `chezmoi init --apply --source ~/.config/dotfiles` on a clean macOS VM (or a fresh user account). The pinned `sourceDir` in `.chezmoi.toml.tmpl` requires the explicit `--source` flag; see README §"Fresh machine".
- Tmux indicator shows the right state — empty when local `main` matches `origin/main`, cloud-download glyph when `origin/main` has commits not yet pulled (presence-only per §12 decision 7).
- `prefix + U` pulls and applies in a popup.

---

## 12. Decisions (resolved)

| # | Topic | Resolution |
|---|---|---|
| 1 | Fresh-machine clone URL | `git@github.com:backmanfyi/dotfiles.git` (confirmed via `git remote -v`) |
| 2 | Brewfile location | Move from `brew/Brewfile` → repo root `./Brewfile`. Drop the `brew/` subdir. |
| 3 | `go/env` | Currently in repo (`GOPRIVATE=github.com/backmanfyi/*`) but NOT deployed (silent bug in `setup.sh` — `go` missing from configs array). Migration deploys it via `dot_config/go/env`. |
| 4 | `claude/templates/` | Deploy to `~/.claude/templates/` (was previously untracked by `setup.sh` step 5). Add to source layout as `dot_claude/templates/`. |
| 5 | Tmux indicator glyph | `` (cloud-download, Nerd Font). |
| 6 | Polling cadence | 15 min. |
| 7 | Indicator scope | Presence-only — show the glyph when there's anything to update (upstream-behind OR local-drift). No count. Empty when in sync. |

All blockers cleared — ready to start Phase 0.
