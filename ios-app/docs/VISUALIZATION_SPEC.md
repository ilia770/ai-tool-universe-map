# VISUALIZATION_SPEC

Owner domain: universe visualization renderer selection and 2D/3D map
presentation. Files: `Universe/UniverseMapView.swift`,
`Universe/UniverseGraphView.swift`, `Universe/UniverseRealityView.swift`, and
render-mode state in `State/UniverseViewModel.swift`.

Do not use this spec to edit chat/input, tool detail, Add Tool, or right-rail
business logic.

## Renderer Modes

`UniverseRenderMode` is the user-facing renderer switch:
- `graph2D` — stable readable default.
- `spatial3D` — existing RealityKit renderer, labelled Experimental.

The render mode is stored on `UniverseViewModel.renderMode`, persists through
`UniverseStore`, and defaults to `graph2D`.

## 2D Graph Mode

2D Graph renders the same `PlanetData` and `UniverseMode` as the 3D scene:
- Core/category nodes are larger than tool nodes.
- Category nodes connect to the core node.
- Tool nodes connect to their category node.
- Edges are smooth quadratic organic lines.
- Selection uses the same `UniverseViewModel` intents as the 3D renderer:
  category nodes call `selectCategory`; tool nodes call `focusTool`.
- Added tools appear because graph nodes derive from `model.visibleAllTools`.
- Empty universes still use the existing empty-state onboarding overlay.
- Pan and pinch are local to the graph and do not mutate navigation state.
- Reduce Motion and `-uitestStatic` disable ambient edge animation.
- Ambient edge animation is scoped to the Canvas edge layer only; node buttons
  stay outside `TimelineView(.animation)` so accessibility targets and SwiftUI
  controls are not rebuilt every frame.

The layout is deterministic and collision-resolved in `UniverseGraphLayout`.
Tests assert iPhone-width node separation, selected tool/category marking, and
user-added tool visibility.

## 3D Spatial Mode

The existing RealityKit renderer remains available as `spatial3D`, but it is
not treated as the default. It is labelled Experimental until the known 3D
readability issues are resolved separately.

This pass intentionally does not attempt to fully fix 3D overlap, clipping,
rotation, depth, or artifact issues.

## Settings Behavior

Settings exposes exactly two renderer choices:
- `2D Graph`
- `3D Spatial` with `Experimental` badge

The old A/K/N/O `VisualizationStyle` presets are no longer an enabled
user-facing control. They remain only as internal parameters for the existing
3D renderer.

## Acceptance Criteria

- Switching render mode changes the map.
- 2D Graph is readable and stable.
- Main nodes do not overlap at iPhone width.
- Selected node, bottom card, and category context derive from the same
  `UniverseMode`.
- Added tools appear in the graph.
- 3D is clearly marked Experimental.
- Build and tests pass.

## Changed files / QA done / Remaining issues

### Agent 9 — 2D Graph fallback (landed)

**Changed files**
- `State/UniverseSelection.swift` — added `UniverseRenderMode`.
- `State/UniverseViewModel.swift` — added persisted `renderMode`.
- `State/UniverseStore.swift` — persists render mode with the user's universe.
- `Universe/UniverseGraphView.swift` — new 2D graph renderer and pure layout.
- `Universe/UniverseMapView.swift` — switches between 2D graph and 3D spatial.
- `Universe/UniverseOverlayView.swift` — hides 3D labels in graph mode and shows
  render-mode badge instead of old preset slider.
- `UI/Settings/AccountSettingsSheet.swift` — Settings now switches 2D/3D mode.
- `Tests/MyAIMapTests/UniverseGraphLayoutTests.swift` — graph layout coverage.
- `Tests/MyAIMapTests/UniverseViewModelTests.swift` — render-mode persistence.

**QA done**
- `git diff --check` clean before verification.
- `npm run ios:verify` succeeded, including XcodeGen project generation,
  app build, and build-for-testing.
- Focused `xcodebuild test` on `iPhone 17 Pro` simulator succeeded for
  `UniverseGraphLayoutTests` and render-mode persistence tests.
- `.xcresult`: `result` Passed, `passedTests` 5, `failedTests` 0,
  `skippedTests` 0.

**Remaining issues**
- Manual visual QA should inspect small iPhone, regular iPhone, and iPad widths.
- 3D spatial defects remain out of scope for this pass.

### Codex follow-up - graph animation and UI smoke (2026-06-21)

**Changed files**
- `Universe/UniverseGraphView.swift` - moved `TimelineView(.animation)` inside
  the Canvas edge layer only.
- `MyAIMapApp.swift` - `-uitestSampleUniverse` launch argument loads the sample
  universe for UI smoke without changing the product default.
- `Tests/MyAIMapUITests/UniverseUISmokeTests.swift` - launches with sample data
  and taps graph accessibility labels instead of stale 3D coordinates.

**QA done**
- `git diff --check` clean.
- `npm run ios:test-build` succeeded with `TEST BUILD SUCCEEDED`.
- `xcodebuild ... -only-testing:MyAIMapTests test-without-building` passed on
  iPhone 17 Pro (`/tmp/aimap-codex-unit.xcresult`): `passedTests = 171`,
  `failedTests = 0`, `skippedTests = 0`.

**Remaining issues**
- Full UI smoke with screenshots remains manual/run-on-demand; build-for-testing
  validates the target compiles.

### Codex follow-up - graph viewport background stability (2026-06-21)

**Changed files**
- `Universe/UniverseGraphView.swift` - graph pan/zoom now applies only to the
  node/edge content, not the full-screen background layer.

**Why**
- The graph background is the viewport surface. It must remain fixed to the
  device bounds while the graph content pans/zooms. If the background moves
  with `currentPan`, the root black view can show through at the edges and read
  as a persistent side strip / horizontally shifted app.

**Remaining QA**
- Device QA should pan/zoom the 2D graph on a real iPhone and confirm no black
  strip appears at either edge.
