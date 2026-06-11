# Product Improvement Sprint - My AI Map

Date: 2026-06-10
Owner: Codex
Partner: Claude Code
Source of truth: `.agent/INSTRUCTIONS.md`, `docs/PRODUCT_CTO.md`, `docs/AGENT_OPERATING_MODEL.md`

## Mission

Move My AI Map from "impressive prototype" to a stable personal product:

- Web: clearer 3D focus, smoother hover, better classification, better logos, fewer confusing controls.
- iOS: reliable simulator/device preview, a practical TestFlight path, and no hidden signing/build blockers.
- Agents: Codex and Claude Code work in the same repo without editing the same files at the same time.

## Current Dirty Work

Do not revert these files. They are active work in progress.

| File | Owner | Purpose |
| --- | --- | --- |
| `ios-app/project.yml` | Codex | Xcode 26.5 launch stability / scene manifest fix |
| `ios-app/Sources/MyAIMap/MyAIMapApp.swift` | Codex | Stable SwiftUI app entry |
| `ios-app/Sources/MyAIMap/Universe/UniverseView.swift` | Codex | Reliable iOS preview universe |
| `src/components/AIToolUniverse3D/ToolNode.tsx` | Codex subagent | Smoother hover/focus and label fade |
| `src/lib/classify-ai-tool.ts` | Codex subagent | Better rule-based classification |
| `src/lib/classify-ai-tool.test.ts` | Codex subagent | Classification coverage |
| `src/lib/tool-logos.ts` | Codex subagent | Better logo domain coverage |
| `src/lib/tool-logos.test.ts` | Codex subagent | Logo coverage |

## Parallel Task Board

### Lane A - Codex Integration

- [x] Launch bounded web 3D polish subagent.
- [x] Launch bounded data/logo/classification subagent.
- [x] Launch bounded iOS release-docs subagent.
- [x] Review subagent diffs for conflicts.
- [x] Run sequential verification after agents finish.
- [ ] Split final commits by concern if the diff stays large.

### Lane B - Web Experience

Owner: Codex unless explicitly handed to Claude.

- [x] Make hover/selection less abrupt in `ToolNode`.
- [x] Keep label/logo overlays mounted long enough to fade out.
- [x] Browser-review selected-node clarity on desktop fast smoke.
- [ ] Check that camera drag still works after selection.
- [ ] If overlap remains bad, add a smaller follow-up for label collision and label budget.

### Lane C - Data, Logos, and Classification

Owner: Codex subagent, then Codex integration.

- [x] Expand category signals for pasted names and URLs.
- [x] Add domain-specific rules for common AI tools.
- [x] Improve logo-domain coverage without committing API keys.
- [x] Add targeted unit tests.
- [ ] Review ambiguous rules such as `render` and generic GitHub URLs.

### Lane D - iOS Personal TestFlight

Owner: Codex for current launch fixes. Claude may help only in docs unless explicitly assigned.

- [x] Confirm Xcode 26.5 exists on the machine.
- [x] Generate and launch the simulator preview during the previous session.
- [x] Replace the fragile preview path with a reliable SwiftUI universe preview.
- [x] Update TestFlight checklist for Xcode 26.5 and `ENABLE_DEBUG_DYLIB=NO` simulator launch.
- [x] Clarify Apple Developer/team ID, App Store Connect, screenshots, and signing blockers.
- [x] Run iOS build sequentially after the Mac is idle.
- [ ] Debug iOS XCTest run hang after bundle build.
- [ ] Prepare signing steps for `com.iliaturilia.myaimap`.

### Lane E - Release and QA

Owner: Codex final gate.

- [x] `npm run typecheck`
- [x] `npm run lint`
- [x] `npm test`
- [x] `npm run build`
- [x] `npm run size:check`
- [x] iOS build
- [ ] iOS tests, if the local project remains generated and stable
- [x] Optional browser smoke only after CPU load is low: `npm run smoke:visual:fast`

## Verification Results

- `git diff --check` -> passed.
- `npm run typecheck` -> passed.
- `npm run lint` -> passed.
- `npm test` -> 5 files / 33 tests passed.
- `npm run build` -> passed.
- `npm run size:check` -> all chunks within budget.
- `npm run smoke:visual:fast` -> 7 passed, 1 skipped in desktop-only mode.
- `xcodebuild ... ENABLE_DEBUG_DYLIB=NO build` -> passed on iPhone 16 Pro simulator.
- `xcodebuild ... ENABLE_DEBUG_DYLIB=NO test` -> build/test bundle compiled, then the test runner hung silently and was stopped. Needs a separate XCTest harness investigation.

## Claude Code Safe Task Pool

Claude should pick one lane at a time and work on a separate branch/worktree.

1. Visual QA lane: `tests/visual-smoke.spec.ts`, `screenshots/**`, `docs/design/**`
   - Add or update visual checks for hover clarity, mobile details, and selected service panel.
   - Do not edit `src/components/AIToolUniverse3D/**` while Codex is integrating `ToolNode`.

2. App Store metadata lane: `docs/IOS_STRATEGY.md`, `ios-app/README.md`, `ios-app/TESTFLIGHT_CHECKLIST.md`, `docs/RELEASE_REVIEW.md`
   - Write concise App Store Connect metadata draft, privacy notes, screenshot list, and signing blockers.
   - Do not edit Swift source or `ios-app/project.yml`.

3. Product copy lane: `docs/PRODUCT_CTO.md`, `docs/design/UI_UX_SPECIALIST.md`
   - Refine product language and UX principles for premium cosmic navigation.
   - Do not edit app code unless a separate implementation task is opened.

4. Data QA lane: `src/data/**`, `src/lib/tool-logos.ts`, `src/lib/classify-ai-tool.ts`
   - Only start this after Codex commits or explicitly hands off the current dirty data/classification patch.

## Stop Rules

- Do not run Xcode, Simulator, Playwright, and Vite stress tests in parallel on this Mac.
- Do not commit secrets. Logo.dev publishable/server keys must stay out of the repo.
- Do not deploy until the full web verification chain passes.
- Do not call the iOS app TestFlight-ready until signing/team ID is configured and an archive uploads.

## Handoff Template

```markdown
## Agent Handoff

Owner:
Branch:
Scope:

### Done
- 

### Changed Files
- 

### Validation
- 

### Risks
- 

### Next Action
- 
```
