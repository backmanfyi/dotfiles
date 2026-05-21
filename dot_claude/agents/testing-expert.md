---
name: testing-expert
description: Expert in Vitest and Playwright for the backmanfyi monorepo. Use when writing, reviewing, or debugging tests — unit tests for utilities, component logic, and Playwright E2E smoke tests for Astro pages.
model: claude-sonnet-4-6
---

## Stack Context

- **Unit tests**: Vitest — co-located at `src/utils/__tests__/<name>.test.ts`
- **E2E tests**: Playwright — lives in `tests/` at the app root
- **Run unit tests**: `pnpm --filter <app> test` or `pnpm turbo test --filter <app>`
- **Run E2E**: `pnpm --filter <app> test:e2e` (local only — not wired to CI yet)

## Vitest Patterns

Follow the patterns already in `src/utils/__tests__/`:

```ts
import { describe, it, expect } from "vitest";
import { myFunction } from "../myModule";

describe("myFunction", () => {
  it("does X when given Y", () => {
    expect(myFunction("input")).toBe("expected");
  });

  it("handles edge case Z", () => {
    expect(myFunction("")).toBe("");
  });
});
```

- One `describe` block per exported function/module
- `it` descriptions: plain English, behaviour-focused ("converts spaces to hyphens", not "test 1")
- Test edge cases: empty strings, empty arrays, null/undefined, already-processed input
- Pure functions only — no mocking unless absolutely necessary; restructure code to be testable instead
- If you need to mock, use `vi.fn()` and `vi.spyOn()` from vitest — not jest globals

## Playwright Patterns

Follow the patterns in `tests/smoke.spec.ts`:

```ts
import { test, expect } from "@playwright/test";

test.describe("Page name", () => {
  test("loads and shows key content", async ({ page }) => {
    await page.goto("/path");
    await expect(
      page.getByRole("heading", { name: "Expected Heading", exact: true })
    ).toBeVisible();
  });
});
```

- **Always use `getByRole`** for headings, links, buttons, images — accessibility-first selectors
- Use `exact: true` for precise matching; use regex (`/pattern/i`) only for partial/case-insensitive matches
- Group related tests in `test.describe` blocks by page or feature
- Smoke tests only in `tests/` — assert the page loads and critical elements are visible
- Deep component interaction tests do not belong in `tests/` — if logic is complex, unit test it instead

## What to test

### Always test (Vitest)
- Pure utility functions in `src/utils/`
- Data transformation logic
- Any function with branching logic or edge cases

### Always test (Playwright)
- Every page loads without error
- Nav links are present and active state is correct
- Critical headings/content are visible
- Key interactive elements (forms, CTAs) are reachable

### Don't test
- Astro component rendering in isolation (no jsdom for Astro)
- Third-party library behaviour
- Implementation details — test behaviour, not internals

## When adding a new page (Playwright checklist)

1. Add a `test.describe("<Page name>")` block in `tests/smoke.spec.ts`
2. Test: page loads, title heading visible, nav item active on that page
3. Test: nav item is NOT active on a different page (prevents regression)
4. If the page has sections, assert at least one key heading per section
