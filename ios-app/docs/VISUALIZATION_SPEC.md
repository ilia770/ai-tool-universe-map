# VISUALIZATION_SPEC

Owner: Claude (mode architecture + `UniverseMode`/settings wiring) → Codex (2D
renderer + 3D cleanup). Files: `Universe/UniverseSceneController.swift`,
`PlanetEntityFactory.swift`, `UniverseSpatialLayout.swift`, a NEW 2D graph view,
and the visualization setting in `AccountSettingsSheet.swift`. Updates
`UNIVERSE_MAP_SPEC.md` (prime directive there: **Readability > 3D wow**).

## Two modes, user-switchable
A single setting picks the renderer:
```
enum UniverseRenderMode { case spatial3D, graph2D }
```
Stored on `UniverseViewModel` (persisted via `UniverseStore`). The map view
renders one or the other; both read the SAME planets/tools/selection so
selection stays in sync across chips/card/rail regardless of mode.

**Default = `graph2D`** until 3D meets the no-defects bar below. "3D should not
be default if it looks broken."

## 3D Spatial Mode (cleanup, not redesign)
Keep the Solar Walk renderer but fix the defects:
- **No confusing overlap:** category planets must not visually collide in
  overview (tune `UniverseSpatialLayout.categoryPosition` spacing / camera
  framing).
- **Rotation:** drag-orbit must feel stable (no jitter/flip); honor the
  `CameraRigController` clamps; no NaN paths.
- **Artifacts / "weird squares":** audit additive/unlit materials + the galaxy
  dust / link boxes for billboard or depth-sort artifacts; links/dust must not
  render as opaque squares.
- **Clipping:** planets/satellites must not clip the near plane at focus
  distances; clamp focus distance per radius.
- **Labels:** legible, de-overlapped (`LabelPacker`), behind-camera culled
  (already), capped (≤5 planet / ≤4 tool). No labels inside planets.
- **Rail/map gesture conflict:** see `RIGHT_RAIL_SPEC.md` — rail long-press must
  not fight map drag.

## 2D Graph Mode (the reliable fallback)
A clean, animated node graph — the readability-first default:
- **Nodes:** Founder OS core, category nodes, tool nodes. Sized by tier
  (core > category > tool). Selected node emphasized.
- **Edges:** organic / cell-like connecting lines (core→category→tool), gently
  animated (slow flow/curve), low visual noise — same structural graph as the
  3D links, drawn in 2D.
- **Layout:** deterministic force-directed-ish or radial layout reusing
  `UniverseSpatialLayout` math projected to 2D; **no overlap by construction**.
- **Interaction:** tap node = select (same `focusTool`/`selectCategory` paths),
  drag = pan, pinch = zoom; smooth, no 3D camera quirks.
- **Animation:** smooth enter/transition; respects Reduce Motion (static when
  set), and `pausesAmbientMotion` in detail/chat.
- Empty universe → same empty-state onboarding (no nodes, starfield/quiet bg).

## Mode selection rules
- Setting in Profile (`SETTINGS_PROFILE_SPEC.md`): segmented **3D Spatial /
  2D Graph**. Changing it swaps renderer live, preserving selection + camera-ish
  framing where sensible.
- The legacy `VisualizationStyle` presets (atlasOverlay/kineticPockets/force3D/
  orbitalGlass) are folded into this: either map them onto the two modes or
  **retire them** (they "change little" — see settings spec). Do not ship four
  presets that look identical.

## No-defect bar (acceptance) — both modes
- No two primary nodes overlap confusingly in the default view.
- No square/box artifacts; no near-plane clipping at any focus.
- Labels readable, capped, de-overlapped, never inside nodes.
- Selection identical across map/chips/card/rail in either mode.
- Reduce Motion honored; detail/chat dims/pauses correctly.
- Switching modes does not lose the current selection.

## Manual QA
1. Fresh launch → 2D graph by default, readable, animated, no overlap.
2. Switch to 3D in settings → live swap, same selected tool stays selected.
3. In 3D: drag-orbit smooth, no jitter; no square artifacts; planets don't clip; ≤5 labels.
4. In 2D: tap a node → selects + detail; pan/pinch smooth; edges animate subtly.
5. Reduce Motion on → both modes static; detail open → background quiet in both.
