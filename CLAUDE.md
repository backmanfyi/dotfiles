# Dotfiles project conventions

This repo is managed by [chezmoi](https://www.chezmoi.io/). Source dir is `~/.config/dotfiles`; chezmoi applies it to `$HOME` in `symlink` mode (see `.chezmoi.toml.tmpl`). Most files under `dot_<name>/` become symlinks at `~/.name`; edits to the source are live immediately for the target.

## Hard rules

### Secrets — 1Password only, never the filesystem

All credentials, tokens, and API keys must be fetched at runtime from 1Password via the `op` CLI. Never write secret values into any tracked file (no plaintext in `.env`, no eager `export FOO=…` in shell rc, no `onepasswordRead` template that bakes values onto disk).

**Convention:**

- Vault: `env`
- Item type: **Password** (single concealed `password` field — keeps the field name uniform)
- Item name: exactly the env-var name (e.g. `GITHUB_PERSONAL_ACCESS_TOKEN`)
- Reference shape: `op://env/<VAR>/password`
- Multi-part credentials → one item per env var (e.g. `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are two items).

**Wiring (auto-wrapper):**

- Per-tool env files live at `~/.config/op/env/<tool>.env` (source: `dot_config/op/env/<tool>.env`), each containing only `VAR="op://env/VAR/password"` references — safe to commit, no secret values.
- `dot_zshrc` scans that directory at shell startup and registers a function `<tool>` that runs `op run --env-file=<file> -- <tool> "$@"`. Adding a new wrapper = drop a new `.env` file; no zshrc edit.
- Bypass the wrapper with `command <tool>` or `\<tool>` when you need the raw binary.
- Adding a new secret: create the item in the `env` vault → append one `VAR="op://env/VAR/password"` line to the relevant tool's env file → done.

### Required CLI tools — Brewfile only

Any binary the dotfiles or our chezmoi scripts depend on must be declared in `Brewfile`. `brew bundle` is the single source of truth for system packages; adding a `command -v foo` check to a script is not a substitute for adding `brew "foo"`.

### Containers — podman, not docker

Local container workflows use `podman`. Do not introduce `docker` commands. When porting a recipe that uses `docker run ...`, swap the binary and verify the flags still apply (most do).

## How things wire up

### Claude Code MCP servers

Claude Code does **not** read MCP server definitions from `~/.claude/settings.json`. The valid user-scope location is `~/.claude.json` (managed by `claude mcp add -s user ...`). To keep that reproducible:

- Source of truth: `.chezmoidata/claude.json` (key path: `.claude.mcpServers`)
- Reconciler: `.chezmoiscripts/run_onchange_after_08-claude-mcp-sync.sh.tmpl` — calls `claude mcp add-json --scope user` per entry and tracks managed names in `~/.claude/.chezmoi-mcp-managed` so removals propagate
- Editing the JSON and running `chezmoi apply` is the supported workflow; never hand-edit `~/.claude.json`

### Chezmoi script naming

`run_once_*` runs once per machine. `run_onchange_*` re-runs when the rendered script content changes — embed any state you want to track into the template so changes trigger re-runs.

### Diff hygiene

`.chezmoi.toml.tmpl` excludes `scripts` from `chezmoi diff` output to keep diffs readable; use `chezmoi execute-template < path` to inspect a rendered script.
