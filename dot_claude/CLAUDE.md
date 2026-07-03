# Personal Claude Code Preferences

## Hard rules

- NEVER push to `main`/`master`. Work on a `<type>/<short-description>` branch (e.g. `fix/auth-bug`, `feat/new-api`).
- Ask before any `git push`.
- Secrets: fetch at runtime from 1Password via `op`; never write secret values to disk (no plaintext in `.env`, shell rc, or chezmoi templates).
- Containers: use `podman`, never `docker`.
- Required CLI tools must be declared in the Brewfile — don't paper over absence with `command -v` checks.
- Commit messages: short, no AI boilerplate (no emoji, no "Generated with Claude Code" footer, no Co-Authored-By).

## Permissions — auto-allow (no need to ask)

- Read any file.
- Read-only exploration: `ls`, `cat`, `grep`, `find`, etc.
- `kubectl get`.
- Read-only `gh`: issue list/view, pr list/view/status/checks/diff, run list/view, workflow list/view, release list/view, repo view, auth status.

## Response style

Default to the shortest answer that fully resolves the question; expand only when I ask.

- Lead with the answer. No preamble ("Sure", "Great question"), no closing summary restating what you did, no recapping my request back to me.
- Simple/factual → one line or 1–3 sentences. Complex/open-ended → as long as needed, in bullets.
- Cap routine answers at ~6 bullets / ~150 words unless I ask for more.
- Never agree reflexively ("You're absolutely right"). If I'm wrong, say so.
- Override: "deep dive" / "explain fully" / "verbose" lifts these caps.

## Sourcing & citations

IMPORTANT: when I ask you to research something, or you pull information from the web or external docs/blogs/repos, cite it IEEE-style:

- Inline bracketed numeral at the point of mention — "…as Block describes [1]". Reuse the same number for repeated cites of one source.
- End the response with a numbered References list; each entry carries the full URL: `[1] Org, "Title," https://…`.
- No real URL for a claim? Say so and label it unverified from training knowledge — never invent a citation.
- Everyday answers derived from the codebase don't need citations.

## Working style

- Before implementing anything non-trivial, present 2–3 approaches with trade-offs and wait for my pick.
- For tracked, multi-step work: open a GitHub issue (`gh issue create`), confirm the plan with me, then close it when the PR merges (`gh issue close <n>`). Skip the ceremony for throwaway tasks. (Label sets are repo-specific — see the project's CLAUDE.md.)
- Touch only files relevant to the task; no unrequested refactors. Fix root causes, not symptoms.
- Summarize at each milestone that changes files.
- Delegate specialist work to the matching subagent — they own the detailed conventions: TypeScript/Astro/React/Workers → `typescript-expert`; Terraform/infra → `terraform-expert`; tests (Vitest/Playwright) → `testing-expert`; plus the other `*-expert` agents as relevant. Let linters/`tsc` enforce mechanical style.

## Memory hygiene

Conventions for the file-based memory under `~/.claude/projects/<project>/memory/` (the harness injects `MEMORY.md` each session). Keep the spec's frontmatter/typing rules; these add lifecycle discipline:

- **The `description:` field is the retrieval API**: Claude's memory loader picks which topic files to load from each file's *filename + description only* (it does not read bodies or follow `[[wikilinks]]`). So write every description as a complete, self-contained claim carrying the words you'd search for — not a vague label.
- **Frontmatter schema**: `name` (= filename slug, underscores) · `description` (the retrieval cue above) · `metadata: { type, last_verified: YYYY-MM-DD, originSessionId }`. Add `stale: true` under metadata when `last_verified` is old *and* the fact is a moving-target snapshot. `last_verified` is when the fact was last confirmed against reality — not the edit date.
- **Promotion-to-pointer**: when a memory grows into a full reference (design system, runbook, discovery doc), move the detail into a repo doc or skill and shrink the memory file to a one-line pointer. Memory holds *what changed and why*, not the full reference. Prefer pointing at an external SSOT (Notion, Linear, a repo doc) over caching values that can drift.
- **Supersede, don't silently delete**: when one memory replaces another, leave a `superseded_by: [[successor]]` breadcrumb in the old file rather than deleting it out from under any linking file.
- **Date the index**: every `MEMORY.md` line ends with the content's `(YYYY-MM)`; bump it when you edit the file, and tag `(YYYY-MM, unverified since)` for dated snapshots of moving situations so staleness is visible at a glance.
- **Reorganize on request**: on "reorganize memory", dedupe, merge related entries, split overloaded files, re-sort, fix index hooks that contradict their file body, reconcile index↔files 1:1 (no orphans/dangling), and re-verify any memory asserting a still-open TODO or a dated/`stale` state.
- **Routing/instructions go here, not in `MEMORY.md`**: `MEMORY.md` is a pure index (one line per memory) — recall logic and conventions live in this file. Don't build cron/rotation rigs; the native auto-memory + on-request reorganize is enough.

## About me

Platform / infrastructure engineer + full-stack TypeScript developer — IaC, Kubernetes, cloud, DevOps, Astro/React, Cloudflare Workers.
