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
_(append per task)_
