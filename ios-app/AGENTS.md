# iOS App — Agent Routing

Scope: the native SwiftUI/RealityKit app under `ios-app/`. This file routes
domain-specific work. It does NOT replace the repo-root `AGENTS.md`
(symlinked to `.agent/INSTRUCTIONS.md`) — that one still governs coordination,
build commands, and git etiquette. Read both.

## Every agent must read before making changes
- `ios-app/docs/PROJECT_CONTEXT.md`
- `ios-app/docs/UI_STATE_MACHINE.md`
- `ios-app/docs/QA_REGRESSION_CHECKLIST.md`

## Domain routing

**Editing Universe Map**
- read `ios-app/docs/UNIVERSE_MAP_SPEC.md`
- do not edit chat/input or the rail unless explicitly asked

**Editing Right Rail**
- read `ios-app/docs/RIGHT_RAIL_SPEC.md`
- do not edit universe map rendering unless explicitly asked

**Editing Chat / Input**
- read `ios-app/docs/INPUT_CHAT_SPEC.md`
- do not edit universe map rendering or the rail unless explicitly asked

**Editing Detail**
- read `ios-app/docs/DETAIL_SCREEN_SPEC.md`
- do not edit chat/input/rail unless explicitly asked

## Rules
- Do not make broad redesigns in bugfix tasks.
- Do not change more than one functional area per task.
- The single source of truth for navigation state is defined in
  `UI_STATE_MACHINE.md`. Do not add a second copy of `selectedCategory`,
  `selectedTool`, or the map mode.
- Update the relevant `.md` after every change.
- End every task with a `## Changed files / QA done / Remaining issues`
  section in the relevant spec.
- If a fix requires changing another domain, STOP and ask for a separate task.

## Verify before declaring done (per repo root AGENTS.md)
```
cd ios-app && xcodegen generate
xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/aimap-dd -resultBundlePath /tmp/aimap.xcresult
xcrun xcresulttool get test-results summary --path /tmp/aimap.xcresult \
  | grep -E '"(passedTests|failedTests|result)"'
```
"Executed 0 tests" from the legacy XCTest reporter is expected — tests use
Swift Testing; trust the xcresult `passedTests` count.
