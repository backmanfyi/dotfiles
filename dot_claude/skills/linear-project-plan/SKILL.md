---
name: linear-project-plan
description: Structure a new Linear project (or restructure an existing one) using the Legora master-plan template — exec summary, scope, decisions (D1..Dn), architecture, phasing with dated windows, dependencies (P1..Pn), risks (R1..Rn), references, sign-off — paired with a thin project description and structured tickets. Use when a developer asks to "create a new Linear project", "draft a project plan", "structure this project", "write the master doc", "convert milestones to phases", "add a decisions section", "apply the project template", or anything similar. Also use when an existing Linear project has only a description and needs a proper master doc, or when restructuring an existing backlog with the standard ticket template.
---

# Linear Project Plan

Produce a master-plan Linear Document paired with a thin project description and structured tickets. Pattern derived from the Tailscale Phase 1 plan and adopted as the Legora project standard.

## Workflow

### 1. Gather metadata

Ask once, in a single message, for the minimum required fields. Skip any the user can clearly fill in later.

- **Title** — short, scannable, action-oriented
- **Owner** — single accountable name
- **Approvers** — 1-3 names with role (e.g. "VP Eng", "CISO", "GRC lead")
- **Target window** — overall project window, e.g. `2026-05-18 → 2026-12-31`
- **Status** — Draft for circulation / Ready for review / Approved / In flight
- **Prerequisite** — link to predecessor project(s), or `None`
- **Team** — the Linear team (e.g. Security Engineering)

If the user can't answer a field, write `TBD — <what's missing>` and move on. Don't block on metadata.

### 2. Draft the master document

Use the 9-section template in [references/template.md](references/template.md). Fill in what you know; mark gaps explicitly as `TBD — <person or info needed>`. See [references/example.md](references/example.md) for a worked example.

The 9 sections (in order):

1. Executive summary
2. Scope (in / out, with links to projects that own the out-of-scope items)
3. Decisions requiring approval (D-table)
4. Architecture
5. Phasing
6. Dependencies (P-table)
7. Risks (R-table)
8. References
9. Sign-off

### 3. Number cross-cutting elements

Use stable prefixes so the project can be referenced in conversation and from tickets:

- `D1, D2, ...` for Decisions Requiring Approval
- `P1, P2, ...` for Dependencies (prerequisites)
- `R1, R2, ...` for Risks

Never renumber after publication. New items get the next free number, even if order changes.

### 4. Convert milestones to phases

Each phase has four fields: **name**, **window** (date range), **scope** (bulleted), **exit criteria** (what proves it's done). Only the first phase is pre-committed by the plan; later phases are conditional on earlier phases' exit criteria.

### 5. Apply the ticket template

For each ticket use the structure in [references/ticket-template.md](references/ticket-template.md) — Why / What / Done when / References. Link tickets back to the project-level elements they implement (e.g. `Implements D3`, `Closes R2`) in the References block.

### 6. Show the user, then push to Linear

Always **show the full Markdown to the user first**. Only push after explicit confirmation. Never push silently.

When pushing:

- **Master doc** — `mcp__linear__save_document` with `project: <id>`, `title: "<Project name> — Master Plan"`, and the matching project icon if known.
- **Project description** — `mcp__linear__save_project` with a thin description: title, 1-paragraph summary, link to the master doc. Move any pre-existing body content into the doc rather than duplicating it.
- **Tickets** — `mcp__linear__save_issue` per ticket, populating Description from the ticket template.

## Rules

1. **Imperative voice.** "Run", "Configure", "Approve" — not "we should run", "we will configure".
2. **One decision per row in the D-table.** If you can't articulate it as a choice between options with a recommendation, it isn't a decision yet — list it as a risk or open question in the relevant section.
3. **Recommendations accompany every decision.** "Pending discussion" is acceptable when truly undecided; flag as `TBD — needs <person>`.
4. **Dates on phases, not on tickets** — unless a ticket has a hard external deadline (e.g. SOC 2 audit date).
5. **Cross-link related Linear projects** in §2 Scope (out-of-scope items handed off) and §6 Dependencies.
6. **Sign-off section is mandatory** even with one approver. Forces explicit gating.
7. **Keep the project description thin.** Title, 1-paragraph summary, link to master doc. The doc carries the weight.
8. **Don't move ticket-level detail into the master doc.** Target 80% strategic / 20% architectural. Implementation lives in tickets.
9. **No emojis in the master doc.** Tables and prose only.
10. **Don't invent decisions or risks.** If the user hasn't surfaced one, ask. Padding the D- or R-table dilutes its value.
11. **Stable IDs are append-only.** Never reorder D/P/R numbers after publication, even if the visual order changes.
12. **Out-of-scope items must be assigned** — every "not doing in this project" line in §2 Scope names the owning project, ticket, or person, or is flagged `TBD — owner`.

## References

- [references/template.md](references/template.md) — full 9-section master doc skeleton with placeholders
- [references/ticket-template.md](references/ticket-template.md) — ticket description template (Why / What / Done when / References)
- [references/example.md](references/example.md) — annotated worked example (fictional "Apex Robotics" project) showing the pattern fully applied
