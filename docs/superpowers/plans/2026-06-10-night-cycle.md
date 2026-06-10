# Night Cycle Plan — My AI Map

Date: 2026-06-10
Owner: Codex
Partner: Claude Code
Base branch: `codex/3d-focus-polish-main` / PR #22

## Goal

Continue the product-quality pass after PR #22 without destabilizing the
mergeable 3D focus work. Keep changes small, verified, and easy for Claude
Code or Codex to resume.

## Current Merge Stack

1. Merge PR #22 first: `codex/3d-focus-polish-main` -> `main`.
2. Recheck and merge safe Dependabot PRs one at a time: #9, #10, #15, #17, #12, #11.
3. Hold PR #14 until ESLint 10 is a deliberate migration.
4. Retarget/close stale stacked PRs #18 and #19 after #22 lands.

## Subagent Findings

### PR / CI Health

- PR #22 is clean, mergeable, and green in CI + Vercel.
- Dependabot PRs #9, #10, #15, #17, #12, #11 are green but should be merged one at a time.
- PR #14 fails because `@eslint/js@10` expects ESLint 10.
- PRs #18 and #19 are stale stack branches, not release-ready for `main`.

### UX / Product Shell

- Mobile/tablet selected-service panel can collapse into a handle-only strip.
- Public UI still had internal phrases like rule-based classifier, env var copy, JSON import, and raw visible fractions.
- Detail panel is still dense; deeper relation lens/nearby tools should later become tabs or collapsible sections.

### 3D / Rendering

- Manual pocket worlds did not always arm zoom-out exit because the arm threshold was lower than the default pocket camera distance.
- Canvas was paying extra cost from `preserveDrawingBuffer` and uncapped DPR.
- Dimmed nodes could still take hover focus while visually de-emphasized.
- Full screen-space label collision culling remains future work.

### Data / iOS Alignment

- Static data has no runtime/schema validation yet.
- Tests did not validate tool/category/link invariants.
- JSON/DB migration should wait until schema validation exists.
- iOS alignment needs shared fixtures or generated models to avoid web/Swift drift.

## This Branch

Branch: `codex/night-cycle-ux-polish`

### Done

- [x] Rename public intake UI to `Add service`.
- [x] Remove visible Logo.dev/env debug copy from product UI.
- [x] Replace custom-tool summary copy with user-facing language.
- [x] Replace raw visible fraction with softer map status copy.
- [x] Move mobile selected-service panel into normal document flow before sidebar controls.
- [x] Add Playwright copy-hygiene regression coverage.
- [x] Add Playwright mobile/tablet selected-service panel coverage.
- [x] Add universe data invariant tests.
- [x] Cap R3F DPR and remove `preserveDrawingBuffer`.
- [x] Raise pocket exit arm threshold for manually opened pockets.
- [x] Gate dimmed-node hover focus.
- [x] Add shared `validateUniverseData()` and custom tool import schema validation.
- [x] Simplify the detail panel first viewport with compact map position and collapsible deeper relation sections.
- [x] Add real pocket exit smoke for wheel zoom back to all-groups view.
- [x] Add reduced-motion bridge from CSS media query into R3F camera and ambient motion.
- [x] Split Playwright scripts into fast desktop smoke and full release matrix.
- [x] Merge non-focus logo and label into one compact bubble to reduce visual overlap.

### Verify Before PR

- [x] `npm run typecheck`
- [x] `npm run lint`
- [x] `npm test`
- [x] `npm run build`
- [x] `npm run size:check`
- [x] `npm run smoke:visual`

## Next Task Pool

### P0

- [ ] If visual smoke confirms mobile panel layout, open stacked PR on top of #22.
- [ ] After #22 merges, retarget this branch to `main`.

### P1

- [x] Make detail panel first viewport simpler: identity, summary, group/stage, primary actions, top connections.
- [x] Add real pocket exit smoke: click category -> wheel out -> expect all-groups state.
- [x] Add reduced-motion bridge from CSS media query into R3F animation/camera behavior.

### P2

- [x] Add screen-space label collision culling or merge non-focus logo+label into one bubble.
- [x] Add schema-backed `validateUniverseData()` and use it for custom imports.
- [x] Split Playwright scripts into fast desktop smoke and full release matrix.

### Claude Code Ownership Candidates

- 3D label collision solver: `src/components/AIToolUniverse3D/**`, `src/index.css`.
- iOS RealityKit sync: `ios-app/**`, shared fixtures.
- Visual QA screenshots: `tests/visual-smoke.spec.ts`, `screenshots/**`.

## Stop-Ship Checks

- Do not deploy if canvas is blank.
- Do not deploy if mobile selected details disappear or only the handle is visible.
- Do not deploy if copy exposes env vars, implementation strategy, or debug provider state.
- Do not deploy if relation ids point to missing tools.
