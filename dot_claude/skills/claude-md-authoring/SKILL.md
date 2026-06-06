---
name: claude-md-authoring
description: >
  Principles and workflow for writing or editing any Claude instruction file —
  user-level CLAUDE.md (~/.claude/CLAUDE.md), project CLAUDE.md (./CLAUDE.md or
  ./.claude/CLAUDE.md), CLAUDE.local.md, subagent definitions
  (.claude/agents/*.md), and path-scoped rules (.claude/rules/*.md). Use
  whenever creating, restructuring, trimming, or adding a rule to any of these
  files, and especially when deciding WHERE a new instruction or preference
  belongs (CLAUDE.md vs. skill vs. subagent vs. hook vs. linter). Triggers:
  "add this to CLAUDE.md", "update my Claude instructions", "this file is too
  long / swamps context", "where should this rule go", "review my CLAUDE.md",
  "make a rule for…", editing any *-expert.md agent file.
---

# Authoring Claude instruction files

Every CLAUDE.md is loaded **in full into every session**. Instruction-following
degrades as the rule count rises (frontier models follow ~150–200 reliably, and
the harness already spends ~50), so a bloated file makes Claude *ignore* the
rules that matter. Therefore: **every line must earn its tokens, and most
content does not belong in CLAUDE.md at all.** This skill is the gate for any
edit to these files.

## First: route the content (the core decision)

Before adding ANY instruction, run it through this test in order. Most content
gets redirected away from CLAUDE.md.

1. **Must it hold every session, even when the agent is working on something
   unrelated?** (e.g. "never push to main", response style, secrets policy)
   → Belongs in **CLAUDE.md**. Keep it to one tight line. Pick the scope: user
   if it's true for *all* your projects, project if it's true for *this repo*.

2. **Must it happen every time with zero exceptions, or is it mechanically
   checkable?** (e.g. block-push-to-main, formatting, `const` over `let`)
   → Use a **hook** (deterministic) or a **linter/`tsc`** — NOT prose. CLAUDE.md
   is advisory; never send an LLM to do a linter's job.

3. **Is it detailed, procedural, or only sometimes relevant?** (e.g. a release
   runbook, framework conventions, a domain workflow)
   → Use a **skill** (a multi-step workflow), a **subagent** (`*-expert.md`
   domain depth, loaded only when delegated), or a **path-scoped rule**
   (`.claude/rules/*.md` with `paths:` frontmatter, loaded only when touching
   matching files).

4. **Is it discoverable from the codebase in seconds, or generic good practice
   the model already follows?** (e.g. "write clean code", a file-by-file map)
   → **Don't add it.** It's bloat.

Only content that survives step 1 gets written into a CLAUDE.md. See
`references/patterns.md` for the full placement table and the reasoning.

## Authoring rules (for content that does belong in CLAUDE.md)

- **Lean.** Target well under 200 lines (Anthropic's stated ceiling); shorter is
  better. For every line ask: *"would removing this cause Claude to make a
  mistake?"* If not, cut it.
- **Specific and verifiable.** Measurable caps and exact formats beat adjectives.
  Write "cap routine answers at ~6 bullets / ~150 words", never "be concise";
  "run `pnpm turbo lint` before PR", never "test your changes".
- **Most-important-first.** Lead with hard guardrails / prohibitions, where
  attention is highest. Push identity/"about me" context to the bottom.
- **One source of truth.** Never duplicate a rule across user and project files,
  or between CLAUDE.md and a subagent file. State it once, at the narrowest
  scope that covers it, and let the other layer reference it.
- **Emphasis is rationed.** Reserve `IMPORTANT` / `NEVER` / `YOU MUST` for the
  few genuine hard rules; if everything shouts, nothing does.
- **Hand-write it.** Don't ship raw `/init` output — review every line.

## Scope: user vs. project

- **User (`~/.claude/CLAUDE.md`)** — true across *all* your projects: global
  guardrails, response style, citation style, cross-project workflow, and
  routing to your subagents. Not repo-specific anything.
- **Project (`./CLAUDE.md`)** — true for *this repo*: build/test/lint commands,
  architecture, repo conventions, issue-label sets. Team-shared, checked in.
- A rule that names a repo-specific path, tool, or convention belongs in
  **project** scope even if it feels personal. If you find the same rule in
  both, delete it from the user file and keep the detailed version in project.

## Workflow for an edit

1. Identify the file and its scope (user / project / local / agent / rule).
2. For each addition or change, run the **routing test** above. Redirect
   anything that fails step 1 to a hook, linter, skill, subagent, rule, or the
   trash — don't just paste it in.
3. Write or trim following the **authoring rules**. Prefer editing down over
   adding; when a section grows, that's a signal to split it out, not to keep it.
4. Before finishing, verify against the checklist in `references/patterns.md`.
5. Report the line-count delta and state explicitly what was cut, moved, or
   redirected and where.

## Reusable material

Read `references/patterns.md` when you need: the full placement table, the
non-obvious Claude Code mechanics (load order, `@import` caveat, advisory vs.
deterministic), ready-to-paste rule blocks (response style, IEEE citations,
subagent routing), a before/after example, the standard "cut list", and the
pre-finish checklist.
