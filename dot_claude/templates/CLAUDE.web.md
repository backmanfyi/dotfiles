# <App Name> — Claude Instructions

## Location in monorepo

`apps/<app-name>/` — run commands from the monorepo root or use `pnpm --filter <app-name> <script>`.

## Stack

- **Framework**: Astro 6 <!-- or: Astro 6 + React 19 / Hono + Cloudflare Workers -->
- **Styling**: Tailwind CSS v4
- **Tests**: Vitest (unit) + Playwright (E2E)
- **Deploy target**: Netlify / Cloudflare Workers

## Key files

- `src/config.ts` — site/app config and constants
- `src/pages/` — routes (file-based)
- `src/components/` — reusable Astro/React components
- `src/layouts/` — page wrappers
- `src/utils/` — pure utility functions (unit tested)
- `src/styles/base.css` — Tailwind v4 config, design tokens, custom utilities

## Tailwind v4 rules

- Every `<style>` block using `@apply` with custom utilities must start with: `@reference "../styles/base.css";`
- Responsive overrides competing with scoped styles: append `!` (`sm:flex!`)

## Local development

```sh
pnpm --filter <app-name> dev           # dev server
pnpm --filter <app-name> build         # production build
pnpm turbo lint --filter <app-name>    # lint
pnpm turbo test --filter <app-name>    # vitest unit tests
pnpm --filter <app-name> test:e2e      # playwright (local only)
```

## Testing conventions

- Unit tests: `src/utils/__tests__/<module>.test.ts` — pure functions only
- E2E: `tests/smoke.spec.ts` — page loads, key headings visible, nav active states
- Always use `getByRole` selectors in Playwright

## Permissions

- Auto-allow: `pnpm --filter <app-name> dev`, `build`, `test`, `lint`, read-only file exploration
- Ask before: `pnpm --filter <app-name> deploy`, any wrangler deploy

## Known quirks / constraints

<!-- Document anything non-obvious: env var requirements, build order deps, etc. -->
