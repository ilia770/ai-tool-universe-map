# UNIVERSE_MAP_SPEC

> **Current-baseline warning — 2026-07-16.** The source-verified **Current
> renderer baseline** below is authoritative. Batch records above it are
> historical change evidence; the current 2D renderer and its tests remain
> untracked in this worktree, so they must not be called a landed release
> contract.

**UI architecture links:** `UI_APPLE_NATIVE_SPEC.md` governs map UI changes;
`UI_COMPONENT_IDENTITY.md` defines category/tool identity; and
`UI_TRANSITION_CATALOG.md` owns the map-detail pilot transition.
`UI_COMPONENT_LIFECYCLE.md` and `UI_QA_CHECKLIST.md` define its lifetime and
verification. Read these before changing the renderer, overlay, detail
presentation, or map controls.

Owner domain: the map renderer + screen-space labels/anchors. Files:
`Universe/UniverseSceneController.swift`, `PlanetEntityFactory.swift`,
`PlanetData.swift`, `UniverseSpatialLayout.swift`, `UniverseOverlayView.swift`
(label/anchor layers only), `UniverseRealityView.swift`,
`UniverseConstellationView.swift`, `UniverseConstellationLayout.swift`,
`CameraRigController.swift`.

Do NOT edit chat/input (`SearchDock`) or the rail (`RightUniverseRail`) here.

## Prime directive
**Readability > 3D wow.** A clear, deterministic map beats an impressive but
unreadable pseudo-3D. If 3D legibility cannot be made reliable, a 2D / 2.5D
deterministic layout is the preferred primary renderer.

## Layout contract
- Categories are branch nodes. `core` is the central Founder OS node in
  overview; branch nodes are tappable categories.
- Tools are star nodes around the focused branch. 2D placement is owned by
  `UniverseConstellationLayout`; do not duplicate category/tool positioning in
  the SwiftUI view layer.
- Core is special: founder-os is the central node; its sibling core tools
  (e.g. OpenSwarm) render as tool stars when the core branch is focused.
  `PlanetData.centralCoreToolID` marks the central one so it is not
  double-rendered.
- Legacy RealityKit files still use `UniverseSpatialLayout.satelliteOffset`.
  If that path is re-enabled, the entity, screen-space label, and camera focus
  must keep the same index/count contract.

## Historical requirements / prior map-task pain points
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

### Batch 9 — ChatGPT-like type rhythm + anchored press motion (landed)

**What changed**
- Product typography now uses the default SF system design. Rounded type is
  reserved for the friendly onboarding/chat empty-state invitation; graph,
  chrome, controls, cards, and reading text use calmer default faces.
- Overview and branch names sit outside their nodes at stable widths. The map
  does not use `minimumScaleFactor` to force labels into circles.
- The overview ellipse has enough vertical separation to keep every label,
  neighboring ring, and canvas edge clear on the 393x852 phone contract.
- Dense branches use two deterministic tool columns. Coding's 11 labels stay
  visible without the context-dot row competing for the same space.
- Direct press feedback uses the high-damped `BrandMotion.press`. Interactive
  native Liquid Glass owns its scale response; shared styles add only haptics
  there and keep the scale fallback for older/non-glass controls.
- Overview-to-branch mode changes use the one-shot smooth morph curve rather
  than an overshooting pop.

**QA done**
- Clean app-only generic simulator build succeeded and was installed on
  `AIMapGate` (iPhone 16 Pro, iOS 26.5).
- Focused simulator run passed 17/17 across `BrandTokensTests` and
  `UniverseConstellationLayoutTests`: native-glass double-scale guard,
  reduced-motion policy, overview occupied-area collision checks, and dense
  Coding branch label containment/non-overlap.
- Live overview and dense Coding branch screenshots were reviewed after an
  8-second settle; no My AI Map error/fault log entries were emitted.

**Remaining issues**
- Repeat the motion capture after the separate Mult UI-test job releases
  `AIMapGate`; concurrent XCTest runners can steal foreground ownership even
  when the app process remains alive.
- SE-class and iPad visual passes remain part of DS.0/DS.10.

### Batch 8 — 2D-first Constellation renderer (historical report; current worktree in progress)

**What changed**
- The current worktree mounts `UniverseConstellationView`, a SwiftUI 2D-first
  constellation with normal SwiftUI buttons, neutral circle visuals,
  `PressableButtonStyle`, a smooth `BrandMotion.morph` layout transition, and
  stable accessibility IDs (`ConstellationCategory.*`, `ConstellationStar.*`).
- `UniverseConstellationLayout` owns deterministic screen-space placement and
  keeps the overview branches plus focused branch tools inside the usable map
  band above the dock and below top chrome.
- `UniverseMapView` routes category/tool/empty taps through the existing
  single navigation machine; the RealityKit scene code remains in-tree as
  legacy/future material but is no longer the primary map surface.
- `UniverseOverlayView` disables the old RealityKit projected label layers for
  the 2D renderer, avoiding duplicate labels and stale camera projections.
- Bottom map context uses `PlanetInfoCard` again for branch/tool state, which
  matches the UI smoke contract and gives branch focus a readable card before
  a tool is selected.
- `PlanetInfoCard` moved away from raw `.ultraThinMaterial` + saturated
  category stroke/fill into the shared `glassSurface` path, neutral chip fill,
  token spacing, and capped accent highlights.

**Changed files**
- `Universe/UniverseConstellationLayout.swift` — new pure layout for overview,
  branch focus, selected-tool state, context branches, and map edges.
- `Universe/UniverseConstellationView.swift` — new SwiftUI renderer using raw
  `Circle` nodes and `PressableButtonStyle` for tappable nodes. It does not
  currently call `GlassEffectContainer` or `glassSurface` for those nodes.
- `Universe/UniverseMapView.swift` — primary renderer switched from
  `UniverseRealityView` to `UniverseConstellationView`.
- `Universe/UniverseOverlayView.swift` — projected-label gate, tokenized
  bottom spacing, `PlanetInfoCard` bottom card, empty-state button cleanup.
- `Universe/PlanetInfoCard.swift` — neutral glass/token recipe.
- `Tests/MyAIMapTests/UniverseConstellationLayoutTests.swift` — layout
  contract coverage for overview/category buttons, branch tool exposure,
  selected-tool emphasis, and smoke-safe placement.

**QA done**
- `git diff --check` clean.
- `bash scripts/ios-verify.sh --test-build-only` succeeded with
  `** TEST BUILD SUCCEEDED **`.
- Targeted simulator run for `UniverseConstellationLayoutTests` was attempted
  on `AIMapGate` but CoreSimulator interrupted before workers materialized:
  `CoreSimulatorService connection interrupted`, then
  `waiting for workers to materialize`, ending with `** TEST INTERRUPTED **`.

**Remaining issues**
- Re-run `UniverseConstellationLayoutTests` and
  `UniverseUISmokeTests/testCaptureKeyStates` once the simulator runner is
  healthy.
- Human visual pass still needed on iPhone / SE-class / iPad to judge the new
  bounce feel, label density, and whether context-category dots should stay
  visible in focused branches.
- RealityKit code remains as legacy/future renderer code; if the 2D direction
  holds after review, delete or quarantine the unused 3D path in a separate
  cleanup slice.

### Historical Batch 7 — retired graph branch focus / tool tap guard

> The `UniverseGraph*` paths in this historical record are not present in the
> current worktree. They are retained only to explain earlier test/run records;
> use the current constellation baseline below for active paths.

**What changed**
- Branch focus now frames tool nodes first, with a category fallback only when a
  branch has no tools. This prevents dense branches (notably Coding) from being
  centered as a tall category+tool package that leaves the actual tools under
  the top route/render-mode chrome.
- `UniverseGraphViewport.focusPadding` and `panLimit` now reserve enough top
  clearance for the route controls plus graph edge padding, so auto-pan can
  actually move a focused branch into the tappable screen area.
- UI smoke no longer accepts a random core tool after tapping a branch. It maps
  seed tool IDs by focused category, chooses a fully visible focused-branch
  tool, taps it by screen coordinate when XCTest's `isHittable` is too
  conservative, and then verifies the real app state by requiring the selected
  details CTA and tool-detail sheet to appear.
- iOS review follow-up tightened the smoke harness so Chat -> Map must be proven
  before any relaunch reset, the selected details CTA must name the intended
  tool, and the detail sheet title is matched through a stable accessibility ID
  (`ToolDetailSection.Title`) rather than a generic text search.
- `AdaptiveLayout.isCompact(nil)` now matches the sheet-detent fallback and
  treats an unresolved horizontal size class as compact. Hosted SwiftUI roots
  and UI-test entry points can briefly report `nil`; the previous split-view
  default could block detail-sheet presentation.
- The chat composer now sits above the transcript in z-order. This keeps the
  paperclip and its floating attachment menu above starter-prompt scroll
  content when the keyboard compresses the layout.

**Changed files**
- Former UniverseGraphView source — historical branch-focus geometry work;
  that source path is absent in the current tree.
- Former UniverseGraphLayoutTests — historical all-category guard; that test
  path is absent in the current tree.
- `Tests/MyAIMapUITests/UniverseUISmokeTests.swift` — branch-specific tool
  selection, sample-map relaunch reset, coordinate tap fallback, stronger
  route/detail/attachment waits.
- `Tests/MyAIMapUITests/GlassSurfaceRealSurfaceUITests.swift` — 44pt
  hit-target assertion now allows a 0.01pt layout epsilon for simulator float
  rounding.
- `UI/Layout/AdaptiveLayout.swift` — nil horizontal size class falls back to
  compact.
- `UI/Search/ChatScreen.swift` — composer z-order guard above transcript
  content.
- `UI/Sheets/ToolDetailSection.swift` — stable accessibility ID on the detail
  title; removed the section-root ID so it cannot mask descendant IDs in UI
  tests.
- `Tests/MyAIMapTests/AdaptiveLayoutTests.swift` — compact / regular / nil
  layout-contract coverage.

**QA done**
- `bash scripts/ios-verify.sh --run-tests --device-id 4F5273F7-8E4A-4CDD-8938-DF478A20193B`
  on QA265 / iPhone 16 Pro / iOS 26.5 simulator passed earlier in the batch:
  341 passed, 0 failed.
- Full `MyAIMapUITests` target on the same simulator passed earlier in the
  batch: 5 passed, 0 failed. Covered glass morph clusters, account section,
  AddTool branch mode, onboarding hit targets, Coding branch -> Lovable tool
  tap, detail sheet, rail drag, chat route, account sheet, input focus,
  attachment menu dismissal/reopen, and Files attachment tap.
- Focused unit rerun passed 25/25 across `AdaptiveLayoutTests`,
  `UniverseGraphLayoutTests`, `ToolPricingPresenterTests`, and
  `ChromeSnapshotTests/toolDetailSectionRenders`.
- Full unit rerun passed 344/344 (`Test run with 344 tests in 46 suites passed
  after 10.321 seconds`).
- After the final `ToolDetailSection` / `ChatScreen` follow-up fixes,
  `bash scripts/ios-verify.sh --test-build-only` succeeded (`** TEST BUILD
  SUCCEEDED **`) for app, unit bundle, and UI bundle.
- A full unit rerun after the branch-focus patch reached 340/341 with the lone
  failure being a runner `signal kill` in
  `UniverseViewModelTests/duplicateAddRestoresHiddenToolInsteadOfCreatingCopy`;
  rerunning `UniverseViewModelTests` alone passed 51/51, including that test.
- Final UI/unit execution reruns after the last two fixes were blocked before a
  product assertion: one temp simulator hit `CoreSimulatorService connection
  interrupted` / invalid device state, and a fresh simulator plus QA265 then
  failed to launch/materialize XCTest workers (`SBMainWorkspace Busy`,
  preflight/runner launch failure, or `waiting for workers to materialize`).
  Treat those interrupted reruns as simulator-runner infrastructure noise, not
  app-code verdicts.

**Remaining issues**
- Physical-device QA still has to judge the things the simulator cannot: actual
  Liquid Glass feel, RealityKit rendering/glare, haptics, and system
  Photos/Files picker behavior.
- Re-run targeted `UniverseUISmokeTests/testCaptureKeyStates` once XCTest runner
  launch is healthy to confirm the stricter detail-title assertion, attachment
  retry path, and composer z-order fix end-to-end.

### Historical Agent 4 — retained spatial layout / readability record

> The active map no longer mounts this spatial label/camera path. Any
> now-absent path below is explicitly historical, not an active source path.

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
- Former CameraControllerTests — historical `CameraRigInteractingTests`
  reference; that test path is absent in the current tree.
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

---

## Current renderer baseline — 2026-07-16

**CONFIRMED in the current working tree:** `UniverseMapView` now mounts
`UniverseConstellationView`, a deterministic SwiftUI 2D renderer backed by
`UniverseConstellationLayout`; it does not construct or mount
`UniverseRealityView`. `UniverseMapView` still allocates its scene, camera, and
gesture controllers and invokes camera-focus hooks, but those spatial effects
are visually dormant under the 2D renderer. The two 2D files and their layout
tests are currently untracked, so this is an
**IN-PROGRESS / VERSION-CONTROL RISK** rather than a committed release contract.

### Current map behavior

- Overview renders a core visual plus category nodes on an ellipse with radial
  edges. The core is non-interactive in overview.
- Branch focus centers the selected category, puts tool nodes in alternating
  columns, and suppresses context branches for dense tool sets.
- Tool/category node Buttons provide 44-point hit areas and stable accessibility
  identifiers. Empty map space steps back through `UniverseMode` only while
  the current mode allows map gestures (not detail or in-map chat).
- `UniverseOverlayView` is still mounted for chrome, empty state, and the
  assistant dock, but it receives `showsProjectedMapLabels: false`; legacy
  camera-projected label/anchor code is disabled.
- No active pan, pinch, rotation, fly-to, camera target, collision system, or
  RealityKit interaction exists in the mounted 2D renderer.

### Legacy spatial system

`UniverseRealityView`, `UniverseSceneController`, camera/entity/gesture code,
label projection, and spatial relation support remain in source but have no
current primary-map call site. Mark them **LEGACY/EXPERIMENTAL**. Do not claim
2D/3D switching, active 3D safety, camera behavior, or nearest-label behavior
without a separate reactivation task and runtime evidence.

### Invalid/currently unsupported states

- A current user cannot select a right rail: the rail is unmounted.
- A current user cannot pan/pinch the primary 2D map.
- The empty map derives no `PlanetData`; the historic requirement for a visible
  Founder OS behind the empty card is not supported by current source.
- There is no map selection/camera restoration after app relaunch.
