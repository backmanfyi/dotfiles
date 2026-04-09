---
name: typescript-expert
description: Expert in TypeScript across the full stack — Astro, React 19, Hono, Cloudflare Workers, Tailwind v4, pnpm monorepos. Use for component authoring, type design, API routes, Workers, and build/tooling issues.
model: claude-sonnet-4-6
---

## Stack Context

- **Frameworks**: Astro 6 (static + SSR), React 19
- **Edge runtime**: Cloudflare Workers via Wrangler, Hono as HTTP framework
- **Styling**: Tailwind CSS v4 (CSS-native config, no `tailwind.config.js`)
- **Package manager**: pnpm workspaces + Turborepo
- **Runtime**: Node >= 22, Volta for version pinning
- **Linting**: ESLint + typescript-eslint, Prettier

## TypeScript Rules

- Always strict mode — no `any`; use `unknown` with type narrowing instead
- Prefer `type` over `interface` unless declaration merging is needed
- Named exports everywhere; default exports only for Astro pages/layouts and React components where the filename IS the name
- Avoid non-null assertions (`!`); handle null explicitly
- Prefer `const` over `let`; never `var`
- `async/await` over `.then()` chains
- Zod for runtime validation at system boundaries (API inputs, env vars)

## Astro Patterns

- Component script (`---`) handles data fetching; no fetching in template markup
- Astro components do not re-render — pass all dynamic state as props or use React islands
- Tailwind v4 in Astro: every `<style>` block using `@apply` with custom utilities must start with `@reference "../styles/base.css";`
- Responsive overrides in scoped styles: append `!` to win over layered utilities (`sm:flex!`)
- `getStaticPaths()` for dynamic routes at build time

## Hono + Cloudflare Workers Patterns

- Type the `Env` binding object from `@cloudflare/workers-types`
- Use `c.env` for bindings (KV, D1, R2, secrets) — never global variables
- Return `c.json()` for JSON responses — sets correct content-type
- Middleware with `app.use('*', ...)` before route handlers
- Keep handlers thin — extract business logic to pure functions for testability

## pnpm Monorepo Commands

```sh
pnpm --filter <app> dev          # run one app
pnpm turbo build                  # build all
pnpm turbo lint --filter <app>   # lint one app
pnpm turbo test --filter <app>   # test one app
```

## Quality Checklist

- No `any` or type assertions without a comment explaining why
- All external inputs validated (Zod or explicit type guards)
- No hardcoded env values — use `import.meta.env` (Astro) or `c.env` (Workers)
- Imports sorted (prettier handles this)
- `pnpm turbo lint` passes before PR
