# Patterns & reference: authoring Claude instruction files

Contents:
- [Placement table](#placement-table)
- [Claude Code mechanics you must know](#claude-code-mechanics-you-must-know)
- [Reusable rule blocks](#reusable-rule-blocks)
- [The cut list](#the-cut-list)
- [Before / after example](#before--after-example)
- [Pre-finish checklist](#pre-finish-checklist)

## Placement table

Route every candidate instruction to its correct home. CLAUDE.md is the
*last* resort, not the default.

| Content | Lives in | Why |
|---|---|---|
| Always-on guardrail / prohibition (never push to main, secrets policy) | **CLAUDE.md** (user or project) | Must be active every session, even off-topic. Short. |
| Response style, citation style, cross-project workflow | **User CLAUDE.md** | True for all your projects. |
| Build/test/lint commands, repo architecture, label sets | **Project CLAUDE.md** | True for this repo; team-shared. |
| Personal, untracked notes for one repo | **CLAUDE.local.md** (gitignored) | Yours only; not for the team. |
| Must-happen-every-time / mechanically checkable | **Hook** (PreToolUse/Stop) or **linter/`tsc`** | Deterministic; CLAUDE.md is only advisory. |
| Framework/domain conventions, type design, code style | **Subagent** (`.claude/agents/*-expert.md`) | Loaded only when delegated; owns the depth. |
| File-type-specific rules (e.g. only `src/api/**/*.ts`) | **Path-scoped rule** (`.claude/rules/*.md`, `paths:` frontmatter) | Loads only when touching matching files. |
| Multi-step procedure / runbook | **Skill** (`.claude/skills/<n>/SKILL.md`) | Loads on demand by description match. |
| Discoverable from code, or generic good practice | **Nowhere — delete** | Bloat; the model already does it. |

## Claude Code mechanics you must know

Non-obvious facts that drive correct placement:

- **CLAUDE.md loads in full, every session.** Length is a per-turn input cost
  paid on every conversation, not just once.
- **`@path` imports do NOT save context.** Imported files are expanded into
  context at launch (max depth 4 hops). Use imports for organization, never as
  a context-reduction trick. The real levers for shrinking the always-on file
  are skills, subagents, and path-scoped rules.
- **CLAUDE.md is advisory, hooks are deterministic.** CLAUDE.md is delivered as
  a user message — no guaranteed compliance, especially for vague or conflicting
  rules. A rule that *must* hold with zero exceptions belongs in a hook.
- **Subagents have their own context** and do NOT inherit your CLAUDE.md. This
  is why a `*-expert.md` agent restates its conventions — and why duplicating
  those conventions in CLAUDE.md is pure redundancy and a drift risk.
- **Load order is broadest → most specific:** enterprise/managed → user
  (`~/.claude/CLAUDE.md`) → project (`./CLAUDE.md`) → local
  (`./CLAUDE.local.md`). Contradictions across layers make Claude pick one
  arbitrarily — avoid them.
- **Specificity + emphasis tune adherence.** `IMPORTANT`/`YOU MUST` raise the
  odds a soft rule sticks, but they don't make it deterministic — and overuse
  burns their signal.

## Reusable rule blocks

Proven, ready-to-paste. Adapt wording, keep the structure.

### Response style (verbosity control)

```markdown
## Response style
Default to the shortest answer that fully resolves the question; expand only when I ask.
- Lead with the answer. No preamble ("Sure", "Great question"), no closing summary
  restating what you did, no recapping my request back to me.
- Simple/factual → one line or 1–3 sentences. Complex/open-ended → as long as needed, in bullets.
- Cap routine answers at ~6 bullets / ~150 words unless I ask for more.
- Never agree reflexively ("You're absolutely right"). If I'm wrong, say so.
- Override: "deep dive" / "explain fully" / "verbose" lifts these caps.
```

### Sourcing & citations (IEEE)

```markdown
## Sourcing & citations
IMPORTANT: when I ask you to research something, or you pull information from the web
or external docs/blogs/repos, cite it IEEE-style:
- Inline bracketed numeral at the point of mention — "…as Block describes [1]".
  Reuse the same number for repeated cites of one source.
- End the response with a numbered References list; each entry carries the full URL:
  `[1] Org, "Title," https://…`. This list is the canonical home of the URL.
- No real URL for a claim? Say so and label it unverified from training knowledge —
  never invent a citation.
- Everyday answers derived from the codebase don't need citations.
```

### Subagent routing (instead of inlining conventions)

```markdown
- Delegate specialist work to the matching subagent — they own the detailed
  conventions: TypeScript/Astro/React/Workers → `typescript-expert`;
  Terraform/infra → `terraform-expert`; tests → `testing-expert`; plus the
  other `*-expert` agents as relevant. Let linters/`tsc` enforce mechanical style.
```

## The cut list

Delete on sight when found in a CLAUDE.md:

- Generic good practice: "write clean code", "use best practices", "avoid bugs",
  "be careful", "think step by step".
- Standard language/tooling conventions the model already follows.
- Detailed API docs or long tutorials — link to the source instead.
- File-by-file codebase descriptions — discoverable by reading the code.
- Stale instructions describing how the code *used to* work.
- Anything duplicated in another CLAUDE.md layer or a subagent file.
- Meta-commentary documenting what a hook already does at runtime.
- Pasted code snippets — reference `file:line` instead; snippets go stale.

## Before / after example

**Before** (vague, unenforceable, duplicated):

```markdown
## Communication
- Keep explanations concise - bullet points over paragraphs
- When citing a source, embed the URL as an inline markdown hyperlink.
## TypeScript
- Strict mode, no any; const over let; pnpm not npm.   ← duplicates typescript-expert
```

**After** (specific, routed, deduped):

```markdown
## Response style
- Lead with the answer; cap routine replies at ~6 bullets / ~150 words unless asked.  (+ full block above)
## Sourcing & citations
- IMPORTANT: cite web/external facts IEEE-style …  (+ full block above)
## Working style
- Delegate TS work to `typescript-expert`; it owns the conventions.  ← no duplication
```

## Pre-finish checklist

Before declaring an edit done:

- [ ] Every new/changed line survives the routing test (step 1 = belongs here).
- [ ] No rule is vague — each has a measurable cap or exact format.
- [ ] No duplication across user/project layers or with a subagent file.
- [ ] Hard guardrails are near the top; identity/context near the bottom.
- [ ] Emphasis markers used only on genuine hard rules.
- [ ] Anything mechanical/zero-exception was sent to a hook or linter, not prose.
- [ ] Line-count delta reported; cuts and moves stated explicitly with destinations.
- [ ] File is comfortably under 200 lines.
