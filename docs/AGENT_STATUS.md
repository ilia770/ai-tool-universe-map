# Agent Status Dashboard

Last updated: 2026-06-10

Use this as the fast handoff file before asking Codex or Claude Code to continue.

## Current Product State

Web app:
- Production URL: `https://ai-tool-universe-map.vercel.app`.
- Main experience: interactive AI tool universe map with 3D scene, categories, tool details, search, logos, and pocket-world interactions.
- Active visual polish history is documented in `docs/LOOP_PLAN.md` and `docs/LOOP_LOG.md`.

iOS app:
- Native SwiftUI/RealityKit prototype is now fully merged to `main` (`ios-app/`).
- Build succeeded locally with Xcode 26.5.
- `build-for-testing` succeeded.
- Full simulator launch/test was blocked by local CoreSimulator runtime migration, not by Swift compile errors.

## PR Stack — MERGED 2026-06-10

The full handoff stack is flat. Everything below landed on `main` via squash merges (branches deleted on origin):

| PR | Branch | Purpose | Status |
| --- | --- | --- | --- |
| #3 | `chore/cto-cleanup` | docs canon + CI + changelog + budget guardrail | merged |
| #16 (re-opened #4) | `feat/ios-strategy` | iOS strategy + design refs + Apple skills | merged |
| #5 | `feat/ios-phase0-scaffold` | SwiftUI + RealityKit scaffold | merged |
| #6 | `feat/ios-phase1-product-shell` | Native product shell + test host config | merged |
| #7 | `feat/ios-design-and-phase2-plan` | design tokens + iPhone patterns + Phase 2 plan | merged |
| #8 | `feat/ios-theme-and-effects` | UI theme + Liquid Glass + haptics + effects | merged |
| #2 | `track-L-lens-slim-and-hover-stability` | L1 lens slim + L2 hover stability | merged |
| #13 | `codex/agent-product-ops-plan` | agent product operating system docs | merged |

Notes from the merge session:
- #4 was auto-closed by GitHub when its base branch was deleted; recreated verbatim as #16 and merged. GitHub does not retarget stacked PRs reliably after squash+delete — merge first, retarget dependents, then delete the branch.
- #6 and #13 needed merge commits to resolve squash-induced add/add conflicts; conflict resolutions kept branch-side content (verified byte-identical for `ios-app/**`), plus a union merge of `.agent/INSTRUCTIONS.md` (technical canon from main + canonical-docs pointers and product invariants from #13).
- CI (`Verify: typecheck • lint • unit • build`) passed on every merged PR.

Still open:
- #18 `codex/intake-relation-intelligence` — Codex WIP (explainable intake relation suggestions). Do not merge without Codex.
- Dependabot PRs #9 #10 #11 #12 #14 #15 #17 — need owner decision.

## Current Blockers

| Area | Blocker | Evidence | Next Action |
| --- | --- | --- | --- |
| iOS simulator launch | CoreSimulator hung during runtime/data migration after iOS 26.5 simulator install | `xcodebuild test` reached simulator launch, then `NSMachErrorDomain -308`; `simctl bootstatus` waited on BackBoard/Data Migration | Retry after Xcode finishes runtime cache/migration, or run on real iPhone with Apple signing |
| TestFlight | Apple Developer team id not configured | TestFlight requires signed archive | Add team id to `ios-app/project.yml` after enrollment |
| Web data model | Tool data still TypeScript literal | `docs/LOOP_LOG.md` D1 skipped JSON migration as risky without schema | Create schema-backed JSON migration PR |

## Where To Fix Next

| Goal | Primary Files |
| --- | --- |
| iOS Phase 2 (state + camera + gestures) | `docs/PHASE_2_PLAN.md`, `ios-app/Sources/MyAIMap/**` (Claude Code, branch `feat/ios-phase2-state-and-camera`) |
| Improve web hover/focus | `src/components/AIToolUniverse3D/Scene.tsx`, `ToolNode.tsx`, `ConnectionLines.tsx`, `src/index.css` |
| Improve category mini-worlds | `src/components/AIToolUniverse3D/layout.ts`, `Scene.tsx`, `CameraController.tsx` |
| Simplify side panel | `src/components/AIToolUniverseMap.tsx`, `src/index.css` |
| Improve logos | `src/lib/tool-logos.ts`, `src/components/ToolLogo.tsx` |
| Improve classifier | `src/lib/classify-ai-tool.ts`, `src/lib/classify-ai-tool.test.ts` |
| Move data to JSON/schema | `src/data/ai-tool-universe.ts`, new `src/data/*.json`, new `src/data/schema.ts` |
| Continue iOS | `ios-app/project.yml`, `ios-app/Sources/MyAIMap/**`, `ios-app/Tests/MyAIMapTests/**` |

## Minimum Next-Agent Startup

```bash
git status --short --branch
sed -n '1,220p' .agent/INSTRUCTIONS.md
sed -n '1,220p' docs/PRODUCT_CTO.md
sed -n '1,220p' docs/AGENT_OPERATING_MODEL.md
sed -n '1,220p' docs/AGENT_STATUS.md
```

Then choose the relevant plan or PR and continue.

