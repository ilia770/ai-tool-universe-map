# My AI Map 50-Task Master Roadmap

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` for independent implementation slices or `superpowers:executing-plans` for a single-branch slice. Steps use checkbox (`- [ ]`) syntax for tracking. Do not edit files owned by another active worker; use a fresh branch or worktree per slice.

**Goal:** Turn My AI Map into a premium, understandable, self-testable web + iOS product with a cosmic 3D universe, native iPhone interactions, clear release gates, and a path to TestFlight.

**Architecture:** The web app remains the production reference for the 3D AI tool universe. The iOS app incrementally ports the same domain model and interaction semantics into SwiftUI/RealityKit, while shared docs define file ownership, release gates, and QA expectations.

**Tech Stack:** React 19, Vite 8, Tailwind CSS 4, Three.js/R3F/drei/postprocessing, Vitest, Playwright, SwiftUI, RealityKit, Swift Testing, XcodeGen, Vercel, GitHub Actions.

---

## Current Baseline

- `main` includes web production, JSON-backed universe data, Logo.dev fallback plumbing, native iOS scaffold, SwiftUI/RealityKit Phase 2 state/camera/proximity/pocket shell, haptics, and drag-orbit projection.
- Production web URL: `https://ai-tool-universe-map.vercel.app`.
- iOS TestFlight is not ready until Apple team signing, archive validation, app icon/splash polish, device QA, and TestFlight metadata are complete.
- Open dependency PRs #12/#14 are migration work, not routine merges.

## Parallel Ownership Rules

- **Codex track:** release tooling, docs, web tests, data/classifier, CI, QA automation.
- **Claude Code track:** iOS visual/RealityKit slices, SwiftUI sheets, search dock, TestFlight-specific UI polish.
- **Shared files requiring coordination:** `ios-app/Sources/MyAIMap/Universe/UniverseView.swift`, `docs/AGENT_STATUS.md`, `package.json`, `.github/workflows/ci.yml`.
- **Preferred branch naming:** `codex/<track>-<slice>` for Codex, `feat/<track>-<slice>` for Claude.

## Verification Matrix

- Web narrow: `npm run typecheck && npm run lint && npm test -- --run`.
- Web release: `npm run typecheck && npm run lint && npm test -- --run && npm run build && npm run size:check`.
- Web visual: `npm run dev` then `npm run smoke:visual`.
- iOS build: `xcodebuild -project ios-app/MyAIMap.xcodeproj -scheme MyAIMap -destination 'generic/platform=iOS Simulator' -derivedDataPath ios-app/build ENABLE_DEBUG_DYLIB=NO build`.
- iOS test build: `xcodebuild -project ios-app/MyAIMap.xcodeproj -scheme MyAIMap -destination 'generic/platform=iOS Simulator' -derivedDataPath ios-app/build ENABLE_DEBUG_DYLIB=NO build-for-testing`.
- iOS full test when simulator is healthy: `xcodebuild -project ios-app/MyAIMap.xcodeproj -scheme MyAIMap -destination 'platform=iOS Simulator,id=<simctl id>' -derivedDataPath ios-app/build ENABLE_DEBUG_DYLIB=NO test`.

---

## Track A — iOS Interaction Core

### Task 1: Stabilize iOS verify commands

**Files:**
- Create: `scripts/ios-verify.sh`
- Modify: `package.json`
- Modify: `docs/RELEASE_REVIEW.md`
- Modify: `ios-app/README.md`

- [x] Add a reusable script that runs iOS build, test build, and optional simulator tests without hard-coding a simulator name.
- [x] Add `npm run ios:build`, `npm run ios:test-build`, and `npm run ios:verify`.
- [x] Document when to use generic simulator build vs device/simulator full tests.
- [x] Verify with `npm run ios:verify`.

### Task 2: Add iOS simulator/device runbook

**Files:**
- Create: `docs/ios/RUNBOOK.md`
- Modify: `docs/AGENT_STATUS.md`

- [x] Document Xcode version, `xcode-select`, `xcodebuild -version`, `xcrun simctl list devices available`, and safe simulator shutdown.
- [x] Document how to open `ios-app/MyAIMap.xcodeproj` and run on a connected iPhone.
- [x] Document how to recover from stuck `xcodebuild test` without killing unrelated processes.
- [x] Link the runbook from the status dashboard.

### Task 3: Bottom sheet interaction polish

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift`
- Create: `ios-app/Sources/MyAIMap/UI/Sheets/UniverseBottomSheet.swift`
- Test: `ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift`

- [ ] Extract the current bottom detail panel into a focused component.
- [ ] Add compact, mid, and expanded states driven by view state.
- [ ] Add drag handle and haptic detent changes.
- [ ] Verify with iOS build and manual simulator/device review.

### Task 4: Search dock with Enter-to-focus

**Files:**
- Create: `ios-app/Sources/MyAIMap/Search/SearchDock.swift`
- Modify: `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift`
- Test: `ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift`

- [ ] Add query state and filtered tool results.
- [ ] Add first-result focus intent using existing `focusTool(_:)`.
- [ ] Add keyboard submit behavior for iPad/hardware keyboard.
- [ ] Verify with tests and iOS build.

### Task 5: Spatial tap parity for RealityKit entities

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseView.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/Entities/PocketShellEntity.swift`
- Create: `ios-app/Sources/MyAIMap/Universe/Entities/ToolNodeEntity.swift`
- Create: `ios-app/Sources/MyAIMap/Universe/Entities/CategoryRingEntity.swift`

- [ ] Add entity-level tap targets for tool and category nodes.
- [ ] Route taps to the same view-model selection intents as SwiftUI overlay hit targets.
- [ ] Preserve accessibility labels for every interactive entity.
- [ ] Verify with iOS build and device/simulator smoke.

### Task 6: Drag-orbit gesture tuning

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/Camera/CameraController.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseView.swift`
- Test: `ios-app/Tests/MyAIMapTests/CameraControllerTests.swift`

- [ ] Add velocity damping and inertia cutoff for drag orbit.
- [ ] Prevent pinch and drag from fighting during pocket auto-enter.
- [ ] Add tests for pitch clamp and distance preservation.
- [ ] Verify with iOS build and manual gesture pass.

### Task 7: Pocket transition system

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/Camera/PocketTransition.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseView.swift`
- Test: `ios-app/Tests/MyAIMapTests/PocketTransitionTests.swift`

- [ ] Add pure interpolation helpers for opacity, scale, and focus progress.
- [ ] Apply transition progress to pocket shell and non-pocket nodes.
- [ ] Respect `accessibilityReduceMotion`.
- [ ] Verify with tests and iOS build.

### Task 8: Haptic taxonomy pass

**Files:**
- Modify: `ios-app/Sources/MyAIMap/UI/Haptics/BrandHaptics.swift`
- Modify: `ios-app/Sources/MyAIMap/UI/Haptics/CoreHapticsEngine.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift`
- Test: `ios-app/Tests/MyAIMapTests/BrandTokensTests.swift`

- [ ] Map category open, category close, tool select, reset camera, search focus, and classify success to distinct haptic intents.
- [ ] Ensure haptics are no-op when disabled.
- [ ] Avoid double haptics from button styles plus explicit actions.
- [ ] Verify with tests and device review.

### Task 9: VoiceOver map accessibility

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseView.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift`
- Test: `ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift`

- [ ] Add accessible names and hints for core, categories, tools, search, and sheet actions.
- [ ] Add a linear fallback list for VoiceOver users.
- [ ] Ensure Reduce Motion and haptics settings are respected.
- [ ] Verify with Accessibility Inspector and iOS build.

### Task 10: iOS app icon and launch polish

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Resources/Assets.xcassets/**`
- Modify: `ios-app/project.yml`
- Create: `docs/design/ios-icon-notes.md`

- [ ] Replace placeholder app icon with a branded My AI Map icon set.
- [ ] Add launch color/style notes aligned with deep-space product identity.
- [ ] Verify asset catalog build.
- [ ] Document source/design rationale.

## Track B — iOS TestFlight Readiness

### Task 11: Apple signing configuration

**Files:**
- Modify: `ios-app/project.yml`
- Create: `docs/ios/SIGNING.md`

- [ ] Add documented placeholders for development team id and signing style.
- [ ] Keep secrets and local signing identities out of git.
- [ ] Document how to set team id once Apple Developer enrollment is ready.
- [ ] Verify project generation and iOS build.

### Task 12: Archive script

**Files:**
- Create: `scripts/ios-archive.sh`
- Modify: `package.json`
- Modify: `docs/ios/RUNBOOK.md`

- [ ] Add a repeatable archive command for `generic/platform=iOS`.
- [ ] Fail fast with a clear message when signing team id is absent.
- [ ] Add `npm run ios:archive`.
- [ ] Verify script dry-run behavior without requiring secrets.

### Task 13: TestFlight checklist

**Files:**
- Create: `docs/ios/TESTFLIGHT_CHECKLIST.md`
- Modify: `docs/RELEASE_REVIEW.md`

- [ ] Add bundle id, display name, version/build, screenshots, privacy, export compliance, and internal tester checklist.
- [ ] Add pre-upload verification commands.
- [ ] Add stop-ship conditions specific to iPhone.
- [ ] Link from release review.

### Task 14: iOS crash/log capture runbook

**Files:**
- Create: `docs/ios/DEBUGGING.md`

- [ ] Document Xcode console, device logs, crash organizer, and simulator logs.
- [ ] Document how agents should request logs from the user without leaking private data.
- [ ] Include common failure symptoms for RealityKit/SwiftUI.
- [ ] Link from `docs/ios/RUNBOOK.md`.

### Task 15: iOS CI design

**Files:**
- Create: `docs/ios/CI_PLAN.md`
- Modify: `.github/workflows/ci.yml` only if the plan is approved in a follow-up PR.

- [ ] Document macOS runner costs and simulator runtime assumptions.
- [ ] Propose a staged CI: PR build-for-testing, nightly full simulator, release archive.
- [ ] Define cache and timeout strategy.
- [ ] Do not enable paid/slow CI until approved.

## Track C — Web 3D Visual Premium

### Task 16: Hover focus de-cluttering

**Files:**
- Modify: `src/components/AIToolUniverse3D/ToolNode.tsx`
- Modify: `src/components/AIToolUniverse3D/Scene.tsx`
- Test: `tests/visual-smoke.spec.ts`

- [ ] On hover/focus, dim unrelated labels and nodes with smooth opacity.
- [ ] Keep the hovered node label readable above neighboring bubbles.
- [ ] Avoid abrupt scale jumps.
- [ ] Verify desktop and mobile screenshots.

### Task 17: Pocket-world relation reveal

**Files:**
- Modify: `src/components/AIToolUniverse3D/ConnectionLines.tsx`
- Modify: `src/components/AIToolUniverse3D/Scene.tsx`
- Modify: `src/components/AIToolUniverse3D/layout.ts`

- [ ] Show more intra-category links when a pocket opens.
- [ ] Hide or soften unrelated cross-category links.
- [ ] Add selected-tool relation emphasis.
- [ ] Verify visual smoke and unit coverage for layout helpers.

### Task 18: Category transition choreography

**Files:**
- Modify: `src/components/AIToolUniverse3D/CameraController.tsx`
- Modify: `src/components/AIToolUniverse3D/CategoryRing.tsx`
- Modify: `src/components/AIToolUniverse3D/PocketWorldShell.tsx`

- [ ] Smooth category enter/exit with camera settle, shell bloom, and label fade.
- [ ] Prevent rapid hover/tap oscillation from causing sharp animation.
- [ ] Keep Escape behavior deterministic.
- [ ] Verify with Playwright and manual browser pass.

### Task 19: Premium starfield pass

**Files:**
- Modify: `src/components/AIToolUniverse3D/StarField.tsx`
- Modify: `src/components/AIToolUniverse3D/GalaxyDust.tsx`

- [ ] Improve star visibility without washing out labels.
- [ ] Use deterministic seeds for stable screenshots.
- [ ] Keep heavy ambient layers idle-mounted.
- [ ] Verify performance budget.

### Task 20: Bloom and postprocessing audit

**Files:**
- Modify: `src/components/AIToolUniverse3D/Scene.tsx`
- Modify: `src/components/AIToolUniverse3D/ToolNode.tsx`

- [ ] Tune bloom intensity for premium glow without text blur.
- [ ] Ensure postprocessing does not hide logo planes or labels.
- [ ] Add low-power fallback if needed.
- [ ] Verify build and visual smoke.

### Task 21: Logo scale and fallback polish

**Files:**
- Modify: `src/components/ToolLogo.tsx`
- Modify: `src/lib/tool-logos.ts`
- Modify: `src/components/AIToolUniverse3D/ToolNode.tsx`
- Test: `src/lib/tool-logos.test.ts`

- [ ] Make logos larger where readable and monograms more polished.
- [ ] Add explicit domains for tools that Logo.dev cannot infer.
- [ ] Ensure no secret Logo.dev key is bundled.
- [ ] Verify unit tests and visual smoke.

### Task 22: Map clarity mode UI

**Files:**
- Modify: `src/components/AIToolUniverseMap.tsx`
- Modify: `src/index.css`

- [ ] Make Focus / Context / Atlas controls more discoverable.
- [ ] Keep keyboard shortcuts but avoid visible instructional clutter.
- [ ] Ensure mobile layout does not overlap the bottom lens.
- [ ] Verify responsive screenshots.

### Task 23: Side panel simplification

**Files:**
- Modify: `src/components/AIToolUniverseMap.tsx`
- Modify: `src/index.css`

- [ ] Reduce right-panel density.
- [ ] Preserve answers to: what is it, category, why use it, connections, workflow stage.
- [ ] Move secondary metadata behind compact affordances.
- [ ] Verify mobile and desktop layouts.

### Task 24: Bottom lens interaction redesign

**Files:**
- Modify: `src/components/AIToolUniverseMap.tsx`
- Modify: `src/index.css`

- [ ] Make the lower panel an interactive navigation lens rather than passive text.
- [ ] Add stage/category relationship previews.
- [ ] Preserve touch-safe hit targets.
- [ ] Verify visual smoke.

### Task 25: 3D camera navigation affordances

**Files:**
- Modify: `src/components/AIToolUniverse3D/CameraController.tsx`
- Modify: `src/components/AIToolUniverse3D/Scene.tsx`
- Modify: `src/components/AIToolUniverseMap.tsx`

- [ ] Add smooth programmatic navigation between categories/tools.
- [ ] Ensure selecting a side-panel relation moves the camera.
- [ ] Add double-click/double-tap reset if it does not conflict with selection.
- [ ] Verify manual browser pass.

## Track D — Data, Classifier, and Tool Intelligence

### Task 26: Tool schema hardening

**Files:**
- Create: `src/data/universe-schema.ts`
- Modify: `src/data/ai-tool-universe.ts`
- Test: `src/data/ai-tool-universe.test.ts`

- [ ] Add runtime validation for category ids, tool ids, orbit values, link endpoints, and confidence.
- [ ] Keep JSON seed as source fixture.
- [ ] Fail tests on invalid data.
- [ ] Verify typecheck and unit tests.

### Task 27: Tool relation confidence UI

**Files:**
- Modify: `src/data/ai-tool-universe.seed.json`
- Modify: `src/components/AIToolUniverseMap.tsx`
- Test: `src/data/ai-tool-universe.test.ts`

- [ ] Add confidence where helpful to relation data.
- [ ] Show confidence as a subtle badge in details, not visual noise.
- [ ] Keep missing confidence valid for hand-curated links.
- [ ] Verify unit and visual smoke.

### Task 28: Classifier keyword expansion

**Files:**
- Modify: `src/lib/classify-ai-tool.ts`
- Test: `src/lib/classify-ai-tool.test.ts`

- [ ] Add rules for new tools: Kimi Webbridge, Deer Flow, Shannon, agent skills repos, OpenSwarm, Tauri/Rust/Xterm.
- [ ] Return explanation and suggested relation candidates.
- [ ] Keep rule order deterministic.
- [ ] Verify unit tests.

### Task 29: URL normalization and domain extraction

**Files:**
- Modify: `src/lib/classify-ai-tool.ts`
- Create: `src/lib/url-normalize.ts`
- Test: `src/lib/url-normalize.test.ts`

- [ ] Normalize pasted URLs and plain names into a stable candidate.
- [ ] Extract host/domain safely.
- [ ] Avoid throwing on malformed input.
- [ ] Verify tests.

### Task 30: Custom tool draft storage

**Files:**
- Create: `src/lib/custom-tools.ts`
- Modify: `src/components/AIToolUniverseMap.tsx`
- Test: `src/lib/custom-tools.test.ts`

- [ ] Persist user-added tool drafts in localStorage.
- [ ] Keep seed data immutable.
- [ ] Add reset/remove affordance.
- [ ] Verify unit and browser smoke.

### Task 31: Data migration plan beyond JSON

**Files:**
- Create: `docs/data/UNIVERSE_DATA_PLAN.md`

- [ ] Define eventual database tables or documents for categories, tools, links, workflow stages, custom user tools.
- [ ] Define import/export path from JSON seed.
- [ ] Define privacy boundaries for user-added tools.
- [ ] Link from CTO/product docs.

### Task 32: Content copy pass for tool explanations

**Files:**
- Modify: `src/data/ai-tool-universe.seed.json`
- Create: `docs/content/TOOL_COPY_GUIDE.md`

- [ ] Make summaries founder/operator oriented.
- [ ] Keep each summary short enough for mobile.
- [ ] Add category-specific usage language.
- [ ] Verify visual smoke after copy changes.

### Task 33: Tool coverage expansion

**Files:**
- Modify: `src/data/ai-tool-universe.seed.json`
- Test: `src/data/ai-tool-universe.test.ts`

- [ ] Add missing user-listed tools that are not in the seed.
- [ ] Assign category, orbit, workflow stage, and relations.
- [ ] Ensure no duplicate ids.
- [ ] Verify data tests.

## Track E — Web Performance and QA

### Task 34: Manual chunks and bundle budget

**Files:**
- Modify: `vite.config.ts`
- Modify: `scripts/check-bundle-size.mjs`
- Modify: `docs/perf.md`

- [ ] Split Three/R3F/postprocessing chunks intentionally.
- [ ] Keep budget checks meaningful after split.
- [ ] Document current chunk sizes.
- [ ] Verify build and size check.

### Task 35: Playwright visual smoke hardening

**Files:**
- Modify: `tests/visual-smoke.spec.ts`
- Modify: `playwright.config.ts`

- [ ] Add deterministic waits for canvas readiness.
- [ ] Capture desktop, tablet, and mobile states.
- [ ] Fail on blank canvas, overlapping primary panels, and missing details.
- [ ] Verify visual smoke locally.

### Task 36: Canvas pixel health check

**Files:**
- Create: `tests/canvas-health.spec.ts`
- Modify: `playwright.config.ts`

- [ ] Sample canvas pixels to detect blank/black-only renders.
- [ ] Keep thresholds tolerant of dark cosmic design.
- [ ] Run as part of visual smoke.
- [ ] Verify with dev server.

### Task 37: Accessibility smoke

**Files:**
- Create: `tests/accessibility-smoke.spec.ts`
- Modify: `src/components/AIToolUniverseMap.tsx`

- [ ] Test keyboard focus path through intake, search, categories, map controls, details.
- [ ] Ensure Escape layered exit remains intact.
- [ ] Ensure Enter in search focuses first match.
- [ ] Verify Playwright smoke.

### Task 38: Performance profile refresh

**Files:**
- Modify: `docs/perf.md`

- [ ] Run Lighthouse on production.
- [ ] Record Performance, TBT, LCP, CLS.
- [ ] Compare against budget in `.agent/INSTRUCTIONS.md`.
- [ ] Flag regressions over 10 percent.

### Task 39: Unit test coverage for map state

**Files:**
- Create: `src/lib/universe-state.ts`
- Create: `src/lib/universe-state.test.ts`
- Modify: `src/components/AIToolUniverseMap.tsx`

- [ ] Extract pure selection/search/category state helpers.
- [ ] Add tests for search focus, category clear, relation focus.
- [ ] Keep React component behavior unchanged.
- [ ] Verify unit tests and typecheck.

## Track F — Release, CI, and Ops

### Task 40: Release review automation

**Files:**
- Create: `scripts/release-check.sh`
- Modify: `package.json`
- Modify: `docs/RELEASE_REVIEW.md`

- [x] Add one command for web release gates.
- [x] Print each step before running it.
- [x] Include typecheck, lint, unit, build, size check.
- [x] Verify script locally.

### Task 41: PR template update for dual-platform work

**Files:**
- Modify: `.github/PULL_REQUEST_TEMPLATE.md`

- [ ] Add web checks, iOS checks, visual review, risk notes, screenshots, TestFlight status.
- [ ] Keep template concise.
- [ ] Verify markdown formatting.

### Task 42: GitHub Actions iOS planning issue

**Files:**
- Create: `docs/ios/CI_PLAN.md`
- Modify: `docs/AGENT_STATUS.md`

- [ ] Convert iOS CI constraints into a clear plan.
- [ ] Keep actual workflow changes for a later approved PR.
- [ ] Define expected cost/time tradeoffs.
- [ ] Link from status dashboard.

### Task 43: Dependency migration plan

**Files:**
- Create: `docs/DEPENDENCY_MIGRATION.md`

- [x] Explain why #12/#14 are held.
- [x] Define migration order for ESLint 10, TypeScript 6, Vite/Vitest.
- [x] Define checks and rollback strategy.
- [x] Link from `docs/AGENT_STATUS.md`.

### Task 44: Vercel deployment runbook

**Files:**
- Create: `docs/web/DEPLOYMENT.md`

- [ ] Document production URL, preview URLs, Vercel CLI, rollback, env vars.
- [ ] Include Logo.dev publishable key policy.
- [ ] Include post-deploy smoke.
- [ ] Link from release review.

### Task 45: Agent status refresh cadence

**Files:**
- Modify: `docs/AGENT_STATUS.md`
- Modify: `docs/AGENT_OPERATING_MODEL.md`

- [ ] Add explicit rules for updating status after PR merge.
- [ ] Add owner/status table for current tracks.
- [ ] Mark stale blockers as resolved or current.
- [ ] Verify docs only.

## Track G — Product and Design

### Task 46: Product walkthrough script

**Files:**
- Create: `docs/product/WALKTHROUGH.md`

- [ ] Write a 2-minute founder walkthrough.
- [ ] Cover map, categories, pocket worlds, search, add-tool intake, and review workflow.
- [ ] Keep copy useful for screenshots and App Store prep.
- [ ] Link from CTO doc.

### Task 47: UI/UX specialist audit checklist

**Files:**
- Modify: `docs/design/UI_UX_SPECIALIST.md`
- Modify: `docs/design/README.md`

- [ ] Add screen-by-screen review checklist.
- [ ] Add mobile-specific stop-ship conditions.
- [ ] Add examples of acceptable label density and glass treatment.
- [ ] Verify docs only.

### Task 48: App Store metadata draft

**Files:**
- Create: `docs/ios/APP_STORE_METADATA.md`

- [ ] Draft name, subtitle, short description, keywords, privacy notes, and screenshot captions.
- [ ] Keep claims accurate to current app.
- [ ] Mark any copy that requires legal/privacy review.
- [ ] Link from TestFlight checklist.

### Task 49: Screenshot plan

**Files:**
- Create: `docs/release/SCREENSHOT_PLAN.md`

- [ ] Define required web and iPhone screenshots.
- [ ] Define states to capture: overview, pocket, tool detail, add-tool, search.
- [ ] Define visual QA before screenshot capture.
- [ ] Link from release review.

### Task 50: Night-cycle execution board

**Files:**
- Create: `docs/NIGHT_CYCLE_BOARD.md`
- Modify: `docs/AGENT_STATUS.md`

- [x] Convert this roadmap into a running queue with Now / Next / Later.
- [x] Assign Codex-safe and Claude-safe file ownership for each active task.
- [x] Add latest PR links and verification state.
- [x] Refresh after each merge.

---

## First Execution Packet

Start with these because they reduce coordination risk and do not collide with active iOS visual work:

1. Task 1 — iOS verify commands.
2. Task 2 — iOS runbook.
3. Task 40 — release review automation.
4. Task 43 — dependency migration plan.
5. Task 50 — night-cycle execution board.

## Agent Handoff Prompt

Use this when assigning Claude Code a parallel slice:

```text
You are working in /Users/ilia882/Code/ai-tool-universe-map on My AI Map.
Read .agent/INSTRUCTIONS.md and docs/superpowers/plans/2026-06-11-50-task-master-roadmap.md.
Take exactly one task from the roadmap, create a fresh branch/worktree, do not edit files owned by another active task, run the listed verification, and open a PR.
Do not run long simulator tests unless the task explicitly requires it and the simulator is healthy.
Report changed files, verification, risks, and PR link.
```
