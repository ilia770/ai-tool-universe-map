# PROJECT_CONTEXT — My AI Map (iOS)

## What it is
"My AI Map" is a premium cosmic AI-tool universe for founders/operators.
A 3D RealityKit scene of category "planets" and tool "satellites", driven by
a SwiftUI glass UI: top chrome, a right-edge category rail, a bottom AI
assistant dock, and presented sheets (detail, account, add-tool).

The product invariant: the map explains what each tool is, its category, why
it matters, and what it connects to. **Readability > 3D wow.**

## Stack
- SwiftUI + RealityKit (+ a SceneKit backdrop file, currently unreferenced).
- Swift 6, `SWIFT_STRICT_CONCURRENCY=complete`, iOS 18 minimum.
- XcodeGen (`project.yml`) generates the gitignored `MyAIMap.xcodeproj`.
- Tests: Swift Testing (`import Testing`, `@Test`/`@Suite`), run via xcodebuild.
- Fully local: no network, no auth, no tracking SDK.

## Key source files (live render path)
- `Universe/UniverseMapView.swift` — top-level screen; owns local view state
  (`mode`, sheet flags, memoized `planets`) and wires gestures → actions.
- `Universe/UniverseMode.swift` — the `UniverseMode` enum: overview /
  branchFocus / toolSelected / detail / chatOpen, plus all derived visibility
  flags (`showsSatellites`, `showsToolAnchor`, `mapOpacity`, etc.).
- `State/UniverseViewModel.swift` — `@Observable` model; owns
  `UniverseSelection` (activeCategory, selectedToolID, hoveredToolID), tool
  data, assistant, custom tools, activity history.
- `State/UniverseSelection.swift` — `struct UniverseSelection` value type.
- `Universe/UniverseSceneController.swift` — RealityKit entity graph
  (planets, satellites, orbits, lights, stars); `rebuildIfNeeded` is
  signature-gated.
- `Universe/UniverseOverlayView.swift` — screen-space labels, tool anchor,
  top chrome, bottom controls, and `rightUniverseRail`.
- `Universe/RightUniverseRail.swift` — right-edge category navigator.
- `UI/Search/SearchDock.swift` — bottom AI assistant dock (input, attachment
  menu, conversation panel, send/add buttons).
- `UI/Sheets/ToolDetailSection.swift`, `RootSheet.swift` — detail + sheets.
- `Universe/PlanetData.swift`, `UniverseSpatialLayout.swift` — layout math.

## Known architecture smell (the reason for the state-machine task)
Navigation state is split across **two owners**:
1. `UniverseMapView.mode` (`@State UniverseMode`) — local to the view.
2. `viewModel.selection` (`UniverseSelection`) — in the model.

Both encode category/tool. They are synced by hand inside
`UniverseMapView.selectCategory` / `focusToolFromMap` and the model's
`selectCategory` / `focusTool`. Manual sync is the source of desync between
map, bottom chips, rail, and the detail card. See `UI_STATE_MACHINE.md`.

## Commands
See `ios-app/AGENTS.md`. Always confirm green via the xcresult `passedTests`
count, not the legacy "Executed 0 tests" line.
