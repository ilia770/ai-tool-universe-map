<!-- Keep this PR focused. If you find yourself describing two unrelated things, split it. -->

## Summary

<!-- One paragraph: what changes, why now. -->

## Changes

<!-- Bullet list of user-visible / reviewer-relevant deltas. -->
-
-

## Risk & blast radius

<!-- Mark all that apply. -->
- [ ] Touches 3D scene math (`src/components/AIToolUniverse3D/layout.ts`, camera, lighting).
- [ ] Touches data source of truth (`src/data/ai-tool-universe.ts`).
- [ ] Touches shared agent rules (`.agent/INSTRUCTIONS.md`).
- [ ] Touches CI, build, or deploy.
- [ ] Drops or changes a public surface (env vars, exported modules, URLs).
- [ ] Pure visual / copy / docs.

## Verify

<!-- Confirm before requesting review. CI runs the same chain. -->
- [ ] `npm run typecheck`
- [ ] `npm run lint`
- [ ] `npm test`
- [ ] `npm run build`
- [ ] (if visual) `npm run smoke:visual`
- [ ] (if perf-sensitive) Lighthouse run captured in PR description and within budget (see `.agent/INSTRUCTIONS.md`).

## Notes for reviewer

<!-- Anything not obvious from the diff: assumptions, follow-ups, screenshots. -->
