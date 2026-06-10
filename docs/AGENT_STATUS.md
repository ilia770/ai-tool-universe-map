# Agent Status Dashboard

Last updated: 2026-06-10

Use this as the fast handoff file before asking Codex or Claude Code to continue.

## Current Product State

Web app:
- Production URL: `https://ai-tool-universe-map.vercel.app`.
- Main experience: interactive AI tool universe map with 3D scene, categories, tool details, search, logos, and pocket-world interactions.
- Active visual polish history is documented in `docs/LOOP_PLAN.md` and `docs/LOOP_LOG.md`.
- Night-cycle polish through PR #32 is merged: non-focus nodes now use one compact logo+label bubble so hover/focus labels overlap less.
- Safe dependency patch queue is merged: #9 `actions/checkout@6`, #10 `actions/setup-node@6`, #15 `globals@17.6.0`, #17 `typescript-eslint@8.61.0`, #11 React stack patch.
- Latest release-path verification after #34/#35/#36: GitHub CI on `main` passed. Run the full local release gate again immediately before production deploy.
- Data migration follow-up is merged (PR #34): production universe data lives in `src/data/ai-tool-universe.seed.json`, while `src/data/ai-tool-universe.ts` remains the typed facade.

iOS app:
- Native SwiftUI/RealityKit prototype is now fully merged to `main` (`ios-app/`).
- Phase 2 slice 1 merged (PR #26, 2026-06-10): `UniverseViewModel`
  (@Observable single source of truth, environment-injected) +
  `CameraController` (drei-parity: clamp 7.5–46, smoothTime 0.55,
  per-view-mode focus offsets) + pinch-to-zoom dolly. 22 new Swift
  Testing tests committed. Plan with execution log:
  `docs/superpowers/plans/2026-06-10-ios-phase2-state-and-camera.md`.
- Build + `build-for-testing` succeed locally with Xcode 26.5 (use
  simulator **id**, not name — name matching is flaky:
  `-destination 'platform=iOS Simulator,id=<simctl id>'`).
- `xcodebuild test` still blocked: test runner hangs before
  establishing connection (CoreSimulator environment issue; the app
  itself boots and renders). Committed tests will run once the runner
  unblocks or on a real device.
- Next iOS slices per `docs/PHASE_2_PLAN.md`: ProximityCategorySystem
  (ECS, hysteresis 11/22) → PocketShellEntity + PocketTransition →
  SearchDock → Sheets → haptics wiring. Owner: Claude Code.
- Repo wart fixed (PR #35): `.github/PULL_REQUEST_TEMPLATE.md` is the
  canonical PR template and the lowercase duplicate was removed from Git.

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
| #32 | `codex/merge-nonfocus-label-bubbles` | compact non-focus logo+label bubbles | merged |
| #33 | `codex/night-cycle-status-refresh` | night-cycle handoff/status refresh | merged |
| #34 | `codex/data-json-seed` | universe data JSON seed + typed facade | merged |
| #35 | `codex/fix-pr-template-case-collision` | remove duplicate lowercase PR template | merged |

Notes from the merge session:
- #4 was auto-closed by GitHub when its base branch was deleted; recreated verbatim as #16 and merged. GitHub does not retarget stacked PRs reliably after squash+delete — merge first, retarget dependents, then delete the branch.
- #6 and #13 needed merge commits to resolve squash-induced add/add conflicts; conflict resolutions kept branch-side content (verified byte-identical for `ios-app/**`), plus a union merge of `.agent/INSTRUCTIONS.md` (technical canon from main + canonical-docs pointers and product invariants from #13).
- CI (`Verify: typecheck • lint • unit • build`) passed on every merged PR.

Still open:
- #12 `dependabot/npm_and_yarn/tooling-6e3cb1f384` — hold for a deliberate tooling migration. It includes major updates to ESLint 10 and TypeScript 6 plus Vite/Vitest/plugin bumps; do not merge as a routine dependency patch.
- #14 `dependabot/npm_and_yarn/eslint/js-10.0.1` — hold with #12. It is unstable because `@eslint/js@10` expects an ESLint 10 migration.

## Current Blockers

| Area | Blocker | Evidence | Next Action |
| --- | --- | --- | --- |
| iOS simulator launch | CoreSimulator hung during runtime/data migration after iOS 26.5 simulator install | `xcodebuild test` reached simulator launch, then `NSMachErrorDomain -308`; `simctl bootstatus` waited on BackBoard/Data Migration | Retry after Xcode finishes runtime cache/migration, or run on real iPhone with Apple signing |
| TestFlight | Apple Developer team id not configured | TestFlight requires signed archive | Add team id to `ios-app/project.yml` after enrollment |
| Web data model | Data is JSON-backed but not yet database-backed | `src/data/ai-tool-universe.seed.json` is the source fixture; `src/data/ai-tool-universe.ts` keeps typed exports | Define the eventual DB/API schema and sync path |
| Tooling migration | ESLint 10 + TypeScript 6 grouped update is open but risky | PR #12 touches `@vitejs/plugin-react`, `eslint`, `eslint-plugin-react-refresh`, `typescript`, `vite`, and `vitest`; PR #14 is unstable | Create a dedicated migration branch, update config/docs/tests together, and run the full release matrix |

## Where To Fix Next

| Goal | Primary Files |
| --- | --- |
| iOS Phase 2 (state + camera + gestures) | `docs/PHASE_2_PLAN.md`, `ios-app/Sources/MyAIMap/**` (Claude Code, branch `feat/ios-phase2-state-and-camera`) |
| Improve web hover/focus | `src/components/AIToolUniverse3D/Scene.tsx`, `ToolNode.tsx`, `ConnectionLines.tsx`, `src/index.css` |
| Improve category mini-worlds | `src/components/AIToolUniverse3D/layout.ts`, `Scene.tsx`, `CameraController.tsx` |
| Simplify side panel | `src/components/AIToolUniverseMap.tsx`, `src/index.css` |
| Improve logos | `src/lib/tool-logos.ts`, `src/components/ToolLogo.tsx` |
| Improve classifier | `src/lib/classify-ai-tool.ts`, `src/lib/classify-ai-tool.test.ts` |
| Move data beyond JSON seed | `src/data/ai-tool-universe.seed.json`, `src/data/ai-tool-universe.ts`, `src/data/universe-schema.ts` |
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
