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

### Batch 7 — 2D graph branch focus / tool tap guard (landed)

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
- `Universe/UniverseGraphView.swift` — branch focus rect + focus padding /
  pan-limit clearance.
- `Tests/MyAIMapTests/UniverseGraphLayoutTests.swift` — all-category guard:
  every non-core branch must expose at least one fully tappable focused tool
  between top chrome and bottom dock.
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

## Changed files / QA done / Remaining issues

### Constellation render budget — 2026-07-27

**Changed files**

- `Universe/UniverseConstellationLayout.swift` now paginates a dense branch.
  It retains the 512-tool durable catalog limit, but produces at most eight
  interactive tool nodes and edges at once (four on a constrained small
  canvas). A selected tool always resolves to its own page.
- `Universe/UniverseConstellationView.swift` adds an accessible previous/next
  pager outside the node field, so every tool remains reachable from the map
  without recreating the entire dense branch.
- `Tests/MyAIMapTests/UniverseConstellationLayoutTests.swift` covers page
  coverage, render bounds, unique IDs, safe insets, and off-page selection for
  100-, 500-, and 1,000-tool fixtures.

**QA done**

- Focused simulator test run on AIMapGate: `UniverseConstellationLayoutTests`,
  9 passed, 0 failed (`aimap-map-pagination-final.xcresult`).

**Remaining issues**

- The structural render budget closes the unbounded renderer path. Physical
  device profiling remains the release gate for launch, frame pacing, memory,
  Dynamic Type, VoiceOver, and pager usability on actual supported devices.
