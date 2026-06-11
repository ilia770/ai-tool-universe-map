# Dependency Migration Plan

Last updated: 2026-06-11

This project has two open dependency PRs that should not be treated as routine
patch updates:

- #12 `dependabot/npm_and_yarn/tooling-6e3cb1f384`
- #14 `dependabot/npm_and_yarn/eslint/js-10.0.1`

## Why They Are Held

The updates include major-version movement across the build and lint toolchain:

- ESLint 10 line items.
- TypeScript 6 line items.
- Vite/Vitest/plugin updates.
- React refresh and TypeScript ESLint compatibility risk.

These can change lint defaults, parser behavior, generated diagnostics, Vite
chunk output, and Vitest runtime behavior. Merge them as a migration, not as a
green-button Dependabot patch.

## Migration Order

1. Create a dedicated branch: `codex/tooling-migration-eslint10-ts6`.
2. Rebase or recreate the dependency updates on current `main`.
3. Update ESLint config first.
4. Run `npm run lint` and fix config-level failures before touching app code.
5. Update TypeScript-specific issues second.
6. Run `npm run typecheck`.
7. Run unit tests.
8. Run production build.
9. Run bundle size budget.
10. Run visual smoke if Vite output or R3F behavior changed.

## Required Commands

```bash
npm ci
npm run typecheck
npm run lint
npm test -- --run
npm run build
npm run size:check
```

For visual impact:

```bash
npm run dev
npm run smoke:visual
```

## Rollback Strategy

If config migration fails or app behavior changes unexpectedly:

1. Stop merging #12/#14.
2. Close the failing migration branch or leave it as draft.
3. Keep current known-good toolchain on `main`.
4. Split the migration into smaller PRs:
   - ESLint config only.
   - TypeScript only.
   - Vite/Vitest only.
   - React plugin only.

## PR Requirements

The migration PR must include:

- Exact dependency list.
- Config changes summary.
- Full command results.
- Bundle size before/after.
- Visual smoke notes if build output changes.
- Clear rollback plan.
