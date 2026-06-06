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

## About me

Platform / infrastructure engineer + full-stack TypeScript developer — IaC, Kubernetes, cloud, DevOps, Astro/React, Cloudflare Workers.
