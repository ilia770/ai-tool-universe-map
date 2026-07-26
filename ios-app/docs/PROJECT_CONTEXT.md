# PROJECT_CONTEXT — My AI Map (iOS)

> **Current-baseline status — 2026-07-16.** The source-verified addendum in
> this document is the current contract. Earlier versions of this file
> described a RealityKit-first target state and are retained only as historical
> context; do not use them to infer live behavior.

## What it is
"My AI Map" is a SwiftUI iPhone/iPad app for exploring and extending a
personal catalog of AI tools as category branches and tool stars. The mounted
map is a 2D SwiftUI constellation with top chrome, a bottom assistant dock,
and account/add-tool/detail presentations. The right rail exists in source but
is currently unmounted. RealityKit remains retained legacy/future material,
not the primary app surface.

The product invariant: the map explains what each tool is, its category, why
it matters, and what it connects to. **Readability > 3D wow.**

## Stack
- SwiftUI primary UI + retained legacy RealityKit renderer files; no SceneKit
  implementation was found.
- Swift 6, `SWIFT_STRICT_CONCURRENCY=complete`, iOS 18 minimum.
- XcodeGen (`project.yml`) generates the gitignored `MyAIMap.xcodeproj`.
- Tests: Swift Testing (`import Testing`, `@Test`/`@Suite`), run via xcodebuild.
- User data is local. There is no auth, sync, or analytics SDK; optional
  DeepSeek access is DEBUG-gated, and tool actions can intentionally open
  Safari/DuckDuckGo URLs.

## Key source files (live render path)
- Source-path shorthand in this document is rooted at `Sources/MyAIMap/` unless
  a path starts with `Tests/`, `Resources/`, or the repository root.
- `Universe/UniverseMapView.swift` — top-level map composition; owns local
  sheet flags and mounts the 2D constellation.
- `Universe/UniverseMode.swift` — `UniverseMode`: overview /
  branchFocus / toolSelected / detail / chatOpen, plus all derived visibility
  flags (`showsSatellites`, `showsToolAnchor`, `mapOpacity`, etc.).
- `State/UniverseViewModel.swift` — `@Observable` model; owns the stored
  `universeMode`, tool data, assistant, custom tools, and activity history.
  Its `UniverseSelection` is a computed projection of that mode.
- `State/UniverseSelection.swift` — projection/value types including
  `UniverseSelection` and assistant message data.
- `Universe/UniverseConstellationView.swift` — primary 2D-first SwiftUI map
  renderer (category branches, tool stars, bounce motion, accessibility IDs).
- `Universe/UniverseConstellationLayout.swift` — pure deterministic layout for
  overview / branch focus / selected-tool states.
- `Universe/UniverseSceneController.swift` — legacy RealityKit entity graph
  kept in-tree while the 2D direction is reviewed.
- `Universe/UniverseOverlayView.swift` — screen-space labels, tool anchor,
  top chrome, bottom controls, and `rightUniverseRail`.
- `Universe/RightUniverseRail.swift` — right-edge category navigator.
- `UI/Search/SearchDock.swift` — bottom AI assistant dock (input, attachment
  menu, conversation panel, send/add buttons).
- `UI/Sheets/ToolDetailSection.swift`, `RootSheet.swift` — detail + sheets.
- `Universe/PlanetData.swift`, `UniverseSpatialLayout.swift` — layout math.

## Current architecture boundary

`UniverseViewModel.universeMode` is the single stored map-navigation value.
The corresponding `selection` is computed. `UniverseMapView` still owns local
presentation mirrors for compact detail, account, and add-tool sheets; that is
a documented synchronization risk, not a second selection owner. See
`STATE_OWNERSHIP.md` and the current-baseline section of
`UI_STATE_MACHINE.md`.

For permanent UI implementation policy, use `UI_APPLE_NATIVE_SPEC.md` and the
authority map in `SPEC_INDEX.md`. This document remains a factual current-source
baseline; it does not override current product requirements or the permanent
UI architecture when deciding a future implementation.

## Commands
See `ios-app/AGENTS.md`. Always confirm green via the xcresult `passedTests`
count, not the legacy "Executed 0 tests" line.

---

## Current-source-of-truth addendum — reconstructed 2026-07-16

This addendum is a factual snapshot of the current working tree. It takes
precedence over older historical or target-state language elsewhere in this
file. Claims are marked so future work does not turn an assumption into a
requirement.

### Detected project

**CONFIRMED — My AI Map (iOS)**, an iPhone/iPad SwiftUI app for building and
exploring a personal catalog of AI tools as a universe of category branches.
Evidence: `project.yml` names the `MyAIMap` application target; the display
name is `My AI Map`; `MyAIMapApp.swift` is the `@main` entry point; and the
bundled catalog is `Resources/ai-tool-universe.seed.json`.

### Platform and implementation stage

| Topic | Current evidence |
| --- | --- |
| Target platform | iOS; `TARGETED_DEVICE_FAMILY: "1,2"` in `project.yml` (iPhone and iPad). |
| Deployment target | **CONFIRMED:** iOS 18.0 in `project.yml`. |
| Language/UI | Swift 6, SwiftUI, Observation; strict concurrency is enabled. |
| Rendering | **CONFIRMED:** `UniverseMapView` currently mounts the SwiftUI `UniverseConstellationView`. RealityKit code remains in-tree but has no current call site from the map. |
| Current stage | **INFERRED:** active transition/QA work. The 2D constellation source and its tests are uncommitted in the current worktree while historical docs still describe an earlier RealityKit-first direction. |
| Targets/scheme | **CONFIRMED:** `MyAIMap`, `MyAIMapTests`, and `MyAIMapUITests`, all under the `MyAIMap` scheme. |

### Current user journeys

1. First launch opens the map and shows a one-screen onboarding overlay.
2. A user may add a first tool, ask the local assistant, explore the empty map,
   or load the bundled sample universe.
3. With tools present, the user taps a category then a tool in the constellation;
   repeating a selected tool opens compact-width detail presentation.
4. The user can switch at the root level between Map and Ask AI, ask a catalog-
   grounded question, open a recommended tool, or start the add-tool flow.
5. The user can add a tool manually or through a suggestion, create a custom
   branch, hide/restore eligible tools, and reset the local universe in Settings.

### Source-of-truth hierarchy

For UI decisions, the authority order in `UI_APPLE_NATIVE_SPEC.md` applies:
explicit product requirements, current project specification, permanent UI
architecture, then runtime-verified implementation. Within this factual
baseline, use the following evidence order:

1. Current Swift implementation and `project.yml`.
2. Current automated tests and the bundled seed resource.
3. This factual addendum and the baseline documents added alongside it.
4. Feature-specific specifications where they name current source files.
5. Historical plans, reports, and changelog entries — useful evidence, but not
   current behavior authority without a source cross-check.

### Known limitations and release-risk areas

- **CONFIRMED:** the current primary 2D map and the retained RealityKit system
  coexist in source. `UniverseMapView` still constructs legacy controllers,
  so the renderer boundary is high risk.
- **CONFIRMED:** `UniverseRailView` and `CategoryRail` exist but are not mounted
  by the current live map composition; a right rail must not be claimed as a
  working user path without runtime verification.
- **CONFIRMED:** assistant transcript/history, search query, app language, and
  visualization-style values are not all persisted; see `DATA_AND_PERSISTENCE.md`.
- **CONFIRMED:** DeepSeek/RelationAI support is present in source but normal
  user assistant behavior is local-first; the relation-AI path is not wired to
  the current renderer.
- **REQUIRES RUNTIME VERIFICATION:** first-launch, sheet transitions, keyboard,
  and current 2D map behavior on compact and regular-width devices.

### Current project priorities inferred from code

- Preserve a readable, deterministic, 2D-first map while the older 3D path is
  retained for future evaluation.
- Keep the user-built universe local, explicit, and safe to reset.
- Keep assistant suggestions grounded in the current visible catalog rather
  than inventing tool facts.
- Maintain Liquid Glass as floating chrome, not a replacement for map/content
  hierarchy.

### Task 1 2D candidate snapshot — 2026-07-26

- **Snapshot reference:** the isolated branch
  `codex/ios-localfirst-architecture` preserves the candidate through its
  `feat(ios): snapshot 2d constellation baseline` commit. The archival patch
  and untracked-file tar were created outside the user worktree under
  `/private/tmp/aimap-2d-candidate.*`.
- **Mounted renderer:** `UniverseMapView` mounts
  `UniverseConstellationView`; its deterministic screen-space placement lives
  in `UniverseConstellationLayout`. The RealityKit path remains retained
  source, not the mounted renderer.
- **Baseline evidence:** layout coverage includes deterministic 100-, 500-,
  and 1,000-tool fixtures at compact phone, standard phone, and iPad canvas
  sizes. Fresh simulator/runtime evidence is still required: this snapshot was
  not run through XcodeGen or xcodebuild because available disk space was only
  2.4 GiB, below the safe verification threshold.

### Terminology

| Term | Meaning in this app | Avoid calling it |
| --- | --- | --- |
| Universe | The user's visible AI-tool catalog and its visual map. | A remote social graph. |
| Seed universe | Bundled sample categories/tools that a user loads on demand. | The default persisted user data. |
| Branch/category | A `ToolCategory` grouping tools on the map. | A navigation tab. |
| Core / Founder OS | The special central category/tool identity used by layout and deletion guards. | An ordinary removable branch. |
| Tool | A `Tool` model entry with category, stage, URL and relations. | A live integration. |
| Constellation | The current SwiftUI 2D renderer and its deterministic layout. | The dormant RealityKit scene. |
| Surface | The root-level Map or Ask AI route owned by `RootShell`. | A `UniverseMode` map state. |
| Universe mode | Map-level selection/presentation state owned by `UniverseViewModel`. | The root app route. |

### What this project is not

- It is not a generic chat app, SaaS dashboard, or a remote AI-tool marketplace.
- It is not currently a full 3D-only universe experience; that claim would
  contradict the current `UniverseMapView` composition.
- It is not an authenticated, synced, multi-user catalog: the implemented
  universe is local to the device's app storage.
- It is not a billing product: the subscription counter is explicitly a local
  placeholder, not StoreKit or server-enforced entitlement logic.
