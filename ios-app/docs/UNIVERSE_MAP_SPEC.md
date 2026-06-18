# UNIVERSE_MAP_SPEC

Owner domain: the 3D scene + screen-space labels/anchors. Files:
`Universe/UniverseSceneController.swift`, `PlanetEntityFactory.swift`,
`PlanetData.swift`, `UniverseSpatialLayout.swift`, `UniverseOverlayView.swift`
(label/anchor layers only), `UniverseRealityView.swift`, `CameraRigController.swift`.

Do NOT edit chat/input (`SearchDock`) or the rail (`RightUniverseRail`) here.

## Prime directive
**Readability > 3D wow.** A clear, deterministic map beats an impressive but
unreadable pseudo-3D. If 3D legibility cannot be made reliable, a 2D / 2.5D
deterministic layout is an acceptable and preferred fallback.

## Layout contract
- Categories are planets. `core` is the central planet (Founder OS at origin).
- Tools are satellites positioned by `UniverseSpatialLayout.satelliteOffset(
  index:count:orbit:)`. The 3D entity, the screen-space label, and the camera
  focus MUST all use the same index/count or they desync.
- Core is special: founder-os is the central planet; its sibling core tools
  (e.g. OpenSwarm) render as satellites. `PlanetData.centralCoreToolID` marks
  the central one so it is not double-rendered.

## Requirements (current pain points to fix in the map task)
- No overlapping / clipped labels; cull or offset on collision.
- No "bubble soup": labels appear around focus, not all at once (already gated
  by `UniverseMode.showsToolLabels` / `showsPlanetLabels`).
- Selected object is visually unambiguous (one highlighted node).
- Label re-projection must not run every gesture frame on low-end devices
  (known perf item — needs a drag-active gate on `CameraRigController`).

## State boundary
The map READS navigation state from the machine (`UI_STATE_MACHINE.md`):
`universeMode`, `selectedCategory`, `selectedTool`. It must not keep its own
copy of selection. Tapping a planet/satellite REQUESTS a transition; it does
not mutate selection in two places.

## Changed files / QA done / Remaining issues

### Agent 4 — Layout / readability (landed)

**What changed (readability):**
- **Label de-overlap is now pure + unit-tested.** Extracted the screen-space
  collision/packing decision out of `UniverseOverlayView` into
  `LabelPacker` (in `UniverseSpatialLayout.swift`). It sorts candidates
  (pinned first, then ascending `priority`, then `id` for determinism), tries a
  fixed offset ladder to dodge collisions, clamps every position into a safe
  area, and **culls** anything that can't find a free slot — killing the
  "bubble soup". Both the overview planet-label layer and the tool-label layer
  now build `LabelPacker.Candidate`s and delegate to `LabelPacker.pack`.
- **Selected object is unambiguous.** The selected planet/tool is passed to the
  packer as `pinned`, so it is always placed (never culled, never offset off
  its slot by a lower-priority neighbour) and keeps its brighter/larger/zIndex
  highlight in `PlanetFloatingLabel` / `ToolFloatingLabel`. In branch/tool
  modes exactly one planet label renders (the focused one).
- **No clipping.** `LabelPacker.clamp` keeps each label's full rect inside the
  safe insets (mirrors the prior `clamped*LabelPoint` bounds). Unit test asserts
  every placed label stays within safe bounds even for anchors pushed far
  off-screen.
- **Perf: no per-frame label re-projection during gestures.** Added an
  `isInteracting` flag to `CameraRigController` (re-entrant
  `beginInteraction()`/`endInteraction()` counter so an overlapping drag+pinch
  both have to end before it clears). `UniverseGestureController` raises it on
  drag/pinch begin and lowers it on end/cancel. The overlay's three projected
  label layers gate on `labelsQuiescent` (`!isTransitioning && !isInteracting`),
  so labels freeze during a drag/pinch and re-settle once it ends. The
  RealityKit scene's own ambient animation path is untouched.
- **Deterministic base positions (goal 5).** No spacing change was needed —
  `satelliteOffset` was already deterministic and evenly spaced. Added
  characterization tests (determinism, per-ring angular separation, no-coincide
  in 3D) to guard it against regressions. `OpenSwarm` core-satellite behaviour
  (`PlanetData.centralCoreToolID`) is unchanged.

**Changed files**
- `Universe/UniverseSpatialLayout.swift` — new `LabelPacker` enum (pure
  de-overlap / clamp / cull). Satellite math unchanged.
- `Universe/CameraRigController.swift` — `isInteracting` +
  `beginInteraction()`/`endInteraction()` (re-entrant counter).
- `Universe/UniverseGestureController.swift` — raise/lower interaction on
  drag/pinch begin/end/cancel; `cancelDrag(camera:)` now takes the rig.
- `Universe/UniverseRealityView.swift` — updated `cancelDrag` call site.
- `Universe/UniverseOverlayView.swift` (label layers only) — both label
  placement functions now use `LabelPacker`; added `labelsQuiescent` gate;
  removed the now-orphaned `clampedOverviewLabelPoint`. Rail / top chrome /
  bottom controls untouched.
- `Tests/MyAIMapTests/LabelPackerTests.swift` — new (9 cases).
- `Tests/MyAIMapTests/CameraControllerTests.swift` — added
  `CameraRigInteractingTests` (5 cases).
- `Tests/MyAIMapTests/UniverseLayoutTests.swift` — added 3 satellite
  determinism/spacing cases.

**QA done**
- `xcodegen generate` clean.
- `xcodebuild test` (iPhone 17 sim): BUILD SUCCEEDED, no MyAIMap
  errors/warnings. xcresult `passedTests` 99 → 107, `failedTests` 0.
- New pure-logic tests followed red→green (APIs missing → implemented → pass).

**Remaining issues**
- Visual/simulator QA per `QA_REGRESSION_CHECKLIST.md` (device matrix: iPhone
  17 / SE-class / iPad, Dynamic Type, dark mode) not run here — needs a human
  desktop+mobile review per PROJECT_CONTEXT product invariants. Specifically
  confirm: no overlap/clipping at small sizes, labels visibly re-settle (not
  smear) after a drag/pinch, and the selected node reads as the single
  highlight.
- Label layers are *suppressed* (not frozen-in-place) during a gesture, so
  labels briefly disappear mid-drag and reappear on release. This is the cheap,
  correct perf fix; a future enhancement could keep the last frame's placements
  pinned during the drag if the flicker reads poorly on device.
- No 2.5D redesign proposed: the existing RealityKit map is legible with these
  fixes, and a redesign is explicitly out of scope (requires human visual
  review). Not recommending it at this time.
