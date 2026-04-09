# Personal Claude Code Preferences

## About Me
- Platform Engineer / Infrastructure Engineer + Full-stack TypeScript developer
- Focus: IaC, Kubernetes, cloud infrastructure, DevOps, Astro/React, Cloudflare Workers

## Permissions - Auto-Allow
- Always read files without asking for permission
- Always run `kubectl get` commands without asking
- Always run read-only exploration commands (ls, cat, grep, find, etc.)

## Git Safety
- NEVER push to main or master branches
- Always create feature branches for changes
- Always Ask before any git push operation
- Commit messages: short and concise, no AI-generated boilerplate (skip the emoji, "Generated with Claude Code" footer, and Co-Authored-By lines)
- Branch naming: `<type>/<short-description>` (e.g., `fix/auth-bug`, `feat/new-api`)

## Workflow
1. Read the codebase for relevant files and plan the work
2. For multi-step tasks, create a GitHub issue to track it: `gh issue create --title "..." --label "..."`
3. Check in with me to verify the plan before starting work
4. Work through the steps, giving high-level explanations at each milestone
5. Close the issue when the PR merges: `gh issue close <number>`
6. Use `gh issue list` to review outstanding work at the start of a session

## Issue Labels
- `security` — security hardening, CVEs, supply chain
- `ci` — CI/CD pipeline changes
- `deps` — dependency updates
- `content` — blog content and copy
- `tooling` — developer tooling and workflow

## Implementation Approach
- ALWAYS present multiple options/approaches before starting any implementation
- Explain trade-offs for each option
- Wait for my selection before proceeding with code changes
- When there are architectural decisions, list at least 2-3 alternatives
- Keep changes as simple as possible - minimal code impact
- Find root causes, no temporary fixes
- Only touch code relevant to the task - avoid introducing bugs

## Code Style
- Clear, readable variable and function names instead of comments (clean and straightforward code)
- Only add comments for non-obvious business logic or "why" explanations
- NO lazy type workarounds - add proper enum values instead of `| string`, extend interfaces properly instead of using `any` or type assertions

## TypeScript
- Strict mode always — no `any`; use `unknown` with type narrowing instead
- `const` over `let`, never `var`
- `async/await` over `.then()` chains
- Named exports preferred; default exports only for Astro pages/layouts
- Zod for runtime validation at system boundaries (API inputs, env vars)
- pnpm for package management — never npm or yarn in JS/TS projects
- Run `pnpm turbo test --filter <app>` for unit tests (Vitest)
- Run `pnpm --filter <app> test:e2e` for E2E tests (Playwright)

## Communication
- Keep explanations concise - bullet points over paragraphs
- Skip obvious context I already know

## Security Workflow (blog project)
- Always run `npm audit --audit-level=high` after any package changes
- Run `/security-review` before opening PRs that touch src/, package.json, or .github/
- safe-chain must be installed AFTER npm ci/audit steps in CI — it intercepts all npm metadata and breaks audit commands if placed before them
- Dependabot PRs for packages < 5 days old will fail CI (expected — safe-chain age gate)
