# 3D Focus Polish Execution Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. This branch contains dirty 3D/UI stabilization work, so only one integrator should edit shared scene files at a time.

**Goal:** Turn the current 3D universe map into a clearer, smoother product experience: hover should be calm, labels should not overwhelm the scene, pocket worlds should feel intentional, and the app should fail gracefully when WebGL or persistence breaks.

**Branch:** `codex/3d-focus-polish`

## Parallel Work Split

| Track | Owner | Scope | Status |
| --- | --- | --- | --- |
| 3D hover/focus audit | Subagent | `src/components/AIToolUniverse3D/**`, `src/index.css` | Complete |
| UX/readability audit | Subagent | `src/components/AIToolUniverseMap.tsx`, side/bottom panels | Complete |
| Verification audit | Subagent | `package.json`, `playwright.config.ts`, `tests/visual-smoke.spec.ts` | Complete |
| Integration | Codex main agent | Apply final patches, run browser checks, commit, PR | Complete |

## Tasks

- [x] Move dirty work from the gone tracking branch onto `codex/3d-focus-polish`.
- [x] Spawn subagents for independent 3D, UX, and verification audits.
- [x] Preserve existing dirty changes; do not revert user/Claude work.
- [x] Fix any high-confidence bugs found in the dirty 3D work.
- [x] Add/adjust focused unit tests for extracted relation logic.
- [x] Run `npm run typecheck`, `npm run lint`, `npm test`, `npm run build`, `npm run size:check`.
- [x] Run Playwright visual smoke against the local app.
- [x] Review subagent findings and apply any remaining targeted fixes.
- [x] Commit and open a focused PR.

## Known Risks To Check

- WebGL `contextlost/contextrestored` listeners must not leak on canvas remount.
- Hover state should not flicker when moving between mesh, logo badge, and label.
- The hover readout should make the active tool obvious while dimming unrelated nodes.
- Visual smoke should not depend on brittle accessible names that changed in the slim lens UI.
- Main stack PR #18/#19 is separate; merge order must preserve intake relation UI.
