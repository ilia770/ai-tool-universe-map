# Phase 2 plan — interactions + camera + ECS

Phase 0 stood up the scaffold. Phase 1 (Codex, PR #6) shipped the
native product shell. Phase 2 is interaction parity with the web
build: tap, hover, drag, scroll, pocket reveal — all native, all
running through the same data layer.

## Scope

What lands in Phase 2:

1. **`CameraController` port** — `CameraComponent` wrapper that
   mirrors the web's `@react-three/drei` `CameraControls` API
   (`minDistance`, `maxDistance`, `smoothTime`, dolly-to-cursor).
2. **`ProximityCategoryWatcher` ECS system** — RealityKit `System`
   that polls the active `CameraComponent.position`, computes
   distance to each category anchor, and dispatches auto-enter /
   auto-exit events with the same hysteresis as the web build
   (`enterDistance = 11`, `exitDistance = 22`).
3. **Pocket-world transition** — `RealityViewProxy` + a
   `MutatingClock` to lerp every off-pocket entity to dimmed
   opacity over `BrandMotion.flow`; pocket entities scale up by
   1.18 ×.
4. **Tap, drag, scroll gestures** — `SpatialTapGesture` on every
   `ToolNode` and `CategoryRing`; `DragGesture` for orbital
   camera; pinch-to-zoom for dolly. All gestures pass through to
   the same view-model state machine, so swapping the camera
   source (e.g. a TabletopKit experience later) doesn't rewrite
   the interaction layer.
5. **Haptics + sound stubs** — call sites only, controlled by
   `BrandHaptics`. Silent by default; the Phase 3 settings screen
   wires the toggles.
6. **Search dock + Enter-to-focus** — `searchable` modifier with a
   custom `searchSuggestions` block; pressing Return on the
   keyboard focuses the first match (parity with the web
   `[C3] search: Enter focuses the first match`).

What is **not** in Phase 2:

- Bloom + Bezier-edge convergence (Phase 3).
- Force-directed layout option (Phase 3).
- App Store metadata (Phase 4).
- Apple Sign-In (deferred until there's a backend to sign into).

## File map (Phase 2 deltas)

```
ios-app/Sources/MyAIMap/
  Universe/
    UniverseView.swift                # add gesture handlers + sheet binding
    Camera/
      CameraController.swift          # NEW — drei-equivalent semantics
      PocketTransition.swift          # NEW — lerp helpers
    ECS/
      ProximityCategorySystem.swift   # NEW — RealityKit System
      UniverseStateComponent.swift    # NEW — shared component for nodes
    Entities/
      CategoryRingEntity.swift        # NEW — proper ring + label
      ToolNodeEntity.swift            # NEW — sphere + aura + hover
      PocketShellEntity.swift         # NEW — translucent shell + torus
  UI/
    Theme/                            # tokens — see DESIGN_TOKENS.md
      BrandColor.swift
      BrandRadius.swift
      BrandSpacing.swift
      BrandMotion.swift
      BrandHaptics.swift
      BrandTypography.swift
    Sheets/
      RootSheet.swift                 # bottom sheet with 3 detents
      ToolDetailSection.swift
      CategoryRail.swift
      ClarityMenu.swift
    Search/
      SearchDock.swift                # top dock + Enter-to-focus
  State/
    UniverseViewModel.swift           # @Observable, single source of truth
    UniverseSelection.swift           # selectedToolID, hoveredToolID, etc.
```

## Decision log for Phase 2

These get resolved before the first line of Phase 2 lands:

- **State container** — `@Observable` class (iOS 17+) injected via
  environment. Not `@EnvironmentObject` (legacy). Single
  view-model owns selection, hover, active category, clarity
  mode, search query.
- **Camera ownership** — the controller owns
  `EntityRef<PerspectiveCamera>`. View-model never touches the
  RealityKit graph directly.
- **Coordinate system** — keep the web build's right-handed
  Y-up world, even though RealityKit defaults are right-handed
  Z-out. `UniverseLayout` already produces SIMD3 in the web
  convention; the camera offset compensates so the visual
  parity holds.
- **Gesture priority** — `SpatialTapGesture` runs first; if a
  tool entity was hit, route to selection; otherwise fall
  through to `DragGesture` for camera rotation.
- **Reduce-motion** — when
  `accessibilityReduceMotion = true`, swap `BrandMotion.flow`
  for `.linear(duration: 0.001)` so transitions snap instantly.

## Order of operations

A safe build order so each step compiles and runs on its own:

1. Land design tokens (`Theme/`). Compile-only; no behaviour
   change.
2. Add `UniverseViewModel`, route every Phase 1 button through
   it. Still no behaviour change.
3. Add `CameraController` with `minDistance` / `maxDistance` and
   pinch-to-zoom. Visible: zoom now feels native.
4. Add `ProximityCategorySystem`. Visible: pocket auto-opens on
   zoom.
5. Add `PocketShellEntity` + `PocketTransition`. Visible: pocket
   shell appears with the same Fibonacci layout as the web
   build.
6. Add `SearchDock`. Visible: ⌘K (iPad) opens dock; Enter
   focuses first match.
7. Add `Sheets/` (root sheet + sections). Visible: bottom sheet
   with three detents.
8. Wire haptics + sound stubs.

Each step is a single PR ≤ 400 lines, stacked under
`feat/ios-phase2-*`.

## Verify chain for Phase 2

```
cd ios-app
xcodegen generate
xcodebuild -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  build test
```

CI gets a follow-up: macOS runner with the iOS 26.5 simulator
runtime pre-installed. That's a Phase 3 ticket because GitHub-
hosted macOS runners are expensive.

## Risk register

| Risk | Mitigation |
| --- | --- |
| `RealityView` API surface drifts between Xcode 16 betas. | Pin Xcode version in CI (Phase 3). Keep `UniverseLayout` framework-free so we can swap renderers if needed. |
| Pocket transition jank on iPhone 14 / 15. | Profile under `RealityKit Trace` in Instruments before merging. Budget: 60 fps on iPhone 14, no perceived stutter. |
| `ProximityCategorySystem` fires on every frame. | Throttle by elapsed time (≥ 160 ms between fires) — same trick as the web `ProximityCategoryWatcher`. |
| Accessibility regression: VoiceOver can't reach 3D nodes. | Phase 2 adds `AccessibilityComponent` to each entity. Each node speaks its name + category. |

## Open questions (for the reviewer)

1. Camera control: stick with pinch + drag, or add a "zoom to
   selected" double-tap?
2. Sound effects on by default, off, or behind a settings
   toggle? (Defaulted: off.)
3. iCloud sync for custom tools — defer to Phase 4 or
   acknowledge as a follow-up issue today?

## Definition of done

Phase 2 ships when:

- Tap a category ring → pocket opens, sheet snaps to mid detent.
- Pinch-zoom past the threshold → same auto-enter behaviour
  fires (parity with web's B1).
- Pull the camera away → pocket auto-closes (parity with B3).
- Search dock with Enter-to-focus.
- VoiceOver reads every interactive element.
- 60 fps on iPhone 14 across all transitions, measured in
  Instruments.
- All Swift tests + Web verify chain still green.
