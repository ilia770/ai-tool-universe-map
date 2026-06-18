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
_(append per task)_
