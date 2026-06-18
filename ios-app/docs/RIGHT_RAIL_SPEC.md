# RIGHT_RAIL_SPEC

Owner domain: the right-edge category navigator. File:
`Universe/RightUniverseRail.swift` (and its mount point in
`UniverseOverlayView.swift`). Do NOT edit map rendering, chat, or detail here.

## Prime directive
**Edge-only rail. Not a panel.** It is a thin, right-aligned affordance that
lets the user scrub between categories. It must not become a wide sliding
panel, must not cover the map, and must not fight the map/chat/detail for the
primary layer.

## Behavior
- Inactive: a slim column of dots aligned to the right edge; current category
  highlighted. Minimal width/hit area.
- Active (`isRailActive`): expands just enough to read category labels while
  the user holds + drags. Releases back to inactive.
- On release over a category → request `branchFocus(category)` via the state
  machine. The rail does not write `selection` directly.
- Entering active state should resign the keyboard (no rail + broken keyboard
  coexistence — see forbidden states in `UI_STATE_MACHINE.md`).

## Accessibility
- The hold-then-drag gesture is not VoiceOver-operable, so the rail is
  currently `.accessibilityHidden(true)`; `CategoryRail` provides the
  accessible category control. If the rail is made the primary control, it
  must expose an `accessibilityAdjustableAction` instead.

## State boundary
Rail READS `selectedCategory` from the machine for its highlight; WRITES only
by requesting a `branchFocus` transition on release. `isRailActive` is
transient rail-local gesture state, not a `universeMode`.

## Changed files / QA done / Remaining issues

### Agent 3 — keyboard resign on rail activation (landed)

**Changed files**
- `Universe/RightUniverseRail.swift` — `UniverseRailGestureState.begin(...)`
  now owns the inactive→active transition: it guards against re-entry, sets
  `phase = .active`, and fires an injected `resignKeyboard` closure exactly
  once on the activation edge. Default closure is
  `UniverseRailGestureState.resignFirstResponder()`, which calls
  `UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder)…)`.
  `beginHold()` now calls `begin` inside the existing `withAnimation` block
  (dropping the redundant separate `phase = .active` write). Added `import UIKit`.
- `Tests/MyAIMapTests/UniverseRailGestureStateTests.swift` — new TDD suite
  (4 tests) covering: resign fires once on activation, no double-resign when
  already active, hover/start-index seeding, and reset.

**Why** — UI_STATE_MACHINE.md forbids "rail active while keyboard layout is
broken." Entering the active hold state previously did not resign first
responder; `UniverseMapView.dismissKeyboard()` is private and unreachable. The
fix lives in-file and is unit-testable via the injected closure (no UIKit needed
in tests).

**QA done**
- Swift Testing suite green on iPhone 17 sim: `passedTests = 92`,
  `failedTests = 0` (baseline 88 + 4 new). Watched the test fail (RED, compile
  error: `begin` had no `resignKeyboard` param) before implementing.

**Remaining issues**
- Edge-only/panel-width geometry and the `branchFocus` release path were already
  spec-conformant and were left untouched (out of scope for this bug).
- `isRailActive` is still rail-local gesture state, not modelled in the global
  machine (noted as a State Machine handoff in UI_STATE_MACHINE.md).
- Rail remains `.accessibilityHidden(true)`; no `accessibilityAdjustableAction`
  added (CategoryRail remains the accessible control).
- Simulator visual QA per QA_REGRESSION_CHECKLIST.md not run.

### Agent 3b — inactive rail hit zone narrowed (landed)

**Changed files**
- `Universe/RightUniverseRail.swift` — split the rail geometry into explicit
  `UniverseRailMetrics`: inactive hit zone is now 12pt, active hit zone remains
  32pt, and visible inactive dots remain 8pt. The rail no longer leaves a 32pt
  invisible panel over the map before the hold gesture activates. Also wrapped
  UIKit keyboard resignation in `MainActor.assumeIsolated` to keep Swift 6
  strict-concurrency builds warning-clean.
- `Tests/MyAIMapTests/UniverseRailGestureStateTests.swift` — added a guard test
  that the inactive hit zone stays narrow and remains smaller than the active
  drag zone.

**Why** — `rail-edge-swallows-map-pan` came from the inactive `Color.clear`
hit area occupying 32pt at the right edge. Even when the long press does not
activate, that invisible panel can win SwiftUI gesture arbitration against
ordinary near-edge map drags. The rail should be forgiving enough to hold, but
not broad enough to behave like a hidden side panel.

**QA done**
- `npm run ios:verify` passed outside sandbox after Xcode macro sandboxing
  blocked the same command inside sandbox. Result: `TEST BUILD SUCCEEDED`.
- Swift Testing via XcodeBuildMCP passed on iPhone 17 Pro:
  `passedTests = 131`, `failedTests = 0`.
- UI smoke passed via direct `xcodebuild test-without-building` after the MCP
  wrapper timed out and killed the first run:
  `UniverseUISmokeTests/testCaptureKeyStates`, 1 test, 0 failures.

**Remaining issues**
- Manual device QA is still required for the actual gesture-priority feel:
  drag the map starting near the right edge and separately hold+drag the rail.
  The automated smoke covers the rail path, but cannot prove the subtle
  SwiftUI/RealityKit gesture arbitration on real touch hardware.
