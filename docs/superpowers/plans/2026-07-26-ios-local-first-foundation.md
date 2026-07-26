# iOS Local-First Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** turn the current user-owned 2D constellation candidate into a
verified single-renderer foundation with deterministic navigation evidence,
without modifying or losing the original dirty worktree.

**Architecture:** the 2D SwiftUI constellation is the only release renderer.
`RootShell` remains the owner of root Map/Ask AI routing, while the map keeps
one `UniverseMode` selection owner. This foundation removes dormant RealityKit
runtime allocation and replaces timing-dependent compact-detail presentation
with a typed map route before broader root-sheet unification. It preserves the
existing system-sheet appearance; the separately specified T-05 shared-element
visual pilot remains blocked until its supplied reference asset is available.

**Tech Stack:** Swift 6, SwiftUI, Observation, iOS 18, XcodeGen, Swift
Testing, XCTest/XCUITest.

## Global Constraints

- Work only in an isolated worktree; the original
  `/Users/ilia882/Code/ai-tool-universe-map` worktree is user-owned and dirty.
- Adopt the uncommitted 2D candidate only through a reversible snapshot; never
  stage, reset, clean, or commit the original worktree’s files.
- The current source contract and the documentation pre-read in
  `ios-app/AGENTS.md` are mandatory for every task.
- `UniverseViewModel.universeMode` remains the only stored map-selection value.
- `RootShell.surface` remains separate from map navigation.
- This plan does not implement the T-05 shared-element visual pilot from
  `UI_TRANSITION_CATALOG.md`; it changes route ownership only and retains the
  existing system-sheet visual behavior.
- One task changes one functional domain. Do not combine persistence, hosted
  AI, renderer, and visual-system changes.
- Do not claim a test pass without a fresh `xcresult` summary with
  `failedTests == 0` and a non-zero `passedTests` count.
- Do not remove user data or generated artifacts to free disk without explicit
  confirmation of the exact paths.

---

## File Structure

| Path | Responsibility after this plan |
| --- | --- |
| `ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift` | 2D map composition, map intents, typed compact-detail route binding; no RealityKit controller allocation. |
| `ios-app/Sources/MyAIMap/Universe/MapRendererKind.swift` | The explicit release renderer selection used by tests and map composition. |
| `ios-app/Sources/MyAIMap/Universe/UniverseConstellationView.swift` | The sole mounted renderer; pauses ambient animation when `UniverseMode.pausesAmbientMotion` is true. |
| `ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift` | 2D overlay contract; no camera-projected label dependency in the live path. |
| `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift` | Map-navigation intents and a typed detail request; no view-local selection mirror. |
| `ios-app/Sources/MyAIMap/State/DetailRoute.swift` | `Tool.id` plus exact `UniverseMode` restoration state for compact detail. |
| `ios-app/Sources/MyAIMap/Universe/UniverseMode.swift` | Typed mode/return invariants for map detail and chat. |
| `ios-app/Tests/MyAIMapTests/UniverseModeTests.swift` | Pure mode, return, and motion-pause assertions. |
| `ios-app/Tests/MyAIMapTests/UniverseConstellationLayoutTests.swift` | Deterministic 2D layout tests for supported sizes and large catalogs. |
| `ios-app/Tests/MyAIMapUITests/UniverseUISmokeTests.swift` | Map/detail/relaunch smoke path with stable accessibility identifiers. |
| `ios-app/docs/ARCHITECTURE.md` | Current renderer ownership and legacy-retirement status. |
| `ios-app/docs/STATE_OWNERSHIP.md` | The detail route owner and any remaining presentation boundary. |
| `ios-app/docs/QA_REGRESSION_CHECKLIST.md` | Fresh foundation verification record and device matrix. |

## Task 1: Preserve and characterize the current 2D candidate

**Files:**
- Create: a snapshot branch/worktree containing the exact current candidate.
- Test: `ios-app/Tests/MyAIMapTests/UniverseConstellationLayoutTests.swift`
- Test: `ios-app/Tests/MyAIMapUITests/UniverseUISmokeTests.swift`
- Modify: `ios-app/docs/PROJECT_CONTEXT.md`

**Interfaces:**
- Consumes: the dirty source worktree’s `UniverseConstellationView.swift`,
  `UniverseConstellationLayout.swift`, and `UniverseConstellationLayoutTests.swift`.
- Produces: a named snapshot reference, a clean implementation worktree, and
  baseline evidence identifying the mounted renderer.

- [ ] **Step 1: Capture the exact candidate boundary before copying anything**

Run from the user-owned worktree:

```bash
git status --short --branch
git diff --name-status HEAD -- ios-app/Sources/MyAIMap/Universe ios-app/Tests/MyAIMapTests ios-app/docs
git ls-files --others --exclude-standard -- ios-app/Sources/MyAIMap/Universe ios-app/Tests/MyAIMapTests ios-app/docs
```

Expected: the untracked constellation renderer, layout, and layout test are
explicitly named; no original file is staged, reset, cleaned, deleted, or
committed.


- [ ] **Step 2: Create a reversible snapshot outside the user worktree**

Run the following commands verbatim. They write an archival patch and tar file
under `/private/tmp`, create a new worktree, and never stage or modify the
user-owned worktree:

```bash
candidate_root=/Users/ilia882/Code/ai-tool-universe-map
snapshot_root=/Users/ilia882/.config/superpowers/worktrees/ai-tool-universe-map/codex-ios-localfirst-candidate
archive_root=$(mktemp -d /private/tmp/aimap-2d-candidate.XXXXXX)
git -C "$candidate_root" diff --binary HEAD -- ios-app > "$archive_root/tracked.patch"
tar -C "$candidate_root" -cf "$archive_root/untracked.tar" \
  ios-app/Sources/MyAIMap/Universe/UniverseConstellationView.swift \
  ios-app/Sources/MyAIMap/Universe/UniverseConstellationLayout.swift \
  ios-app/Tests/MyAIMapTests/UniverseConstellationLayoutTests.swift
git -C "$candidate_root" worktree add "$snapshot_root" -b codex/ios-localfirst-candidate HEAD
git -C "$snapshot_root" apply "$archive_root/tracked.patch"
tar -C "$snapshot_root" -xf "$archive_root/untracked.tar"
git -C "$candidate_root" status --short
git -C "$snapshot_root" status --short
git -C "$snapshot_root" diff --check
```

Expected: the original status is byte-for-byte unchanged; only the snapshot
branch may contain the candidate files. If this cannot be demonstrated, stop
and do not reconstruct the renderer from audit notes.

- [ ] **Step 3: Write failing large-catalog layout assertions**

Add deterministic fixtures that use `UniverseConstellationLayout.make` with
100, 500, and 1,000 generated tools across `CGSize(width: 320, height: 667)`,
`CGSize(width: 393, height: 852)`, and `CGSize(width: 1024, height: 768)`.
Each fixture asserts unique category/tool IDs and that every point lies inside
the size after the documented safe insets. The assertion helper must print the
duplicate ID or out-of-bounds point on failure.

```swift
private func assertAllPointsAreInside(
    _ layout: UniverseConstellationLayout.Layout,
    size: CGSize
) {
    for node in layout.categoryNodes + layout.toolNodes {
        #expect(node.point.x >= 0 && node.point.x <= size.width, "\(node.id)")
        #expect(node.point.y >= 0 && node.point.y <= size.height, "\(node.id)")
    }
}
```

- [ ] **Step 4: Run the narrow tests and establish a reproducible baseline**

Run:

```bash
cd ios-app
xcodegen generate
xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MyAIMapTests/UniverseConstellationLayoutTests \
  -derivedDataPath /tmp/aimap-foundation-dd \
  -resultBundlePath /tmp/aimap-foundation-layout.xcresult
xcrun xcresulttool get test-results summary --path /tmp/aimap-foundation-layout.xcresult
```

Expected: non-zero passed tests and zero failures. If disk space prevents the
command, record the exact failure and stop before changing renderer behavior.

- [ ] **Step 5: Update factual baseline documentation and commit only snapshot-owned files**

Record the snapshot reference, 2D mounted renderer, and missing fresh runtime
evidence in `PROJECT_CONTEXT.md`. Commit only the snapshot branch’s candidate
files and documentation:

```bash
git add ios-app/Sources/MyAIMap/Universe/UniverseConstellationView.swift \
  ios-app/Sources/MyAIMap/Universe/UniverseConstellationLayout.swift \
  ios-app/Tests/MyAIMapTests/UniverseConstellationLayoutTests.swift \
  ios-app/docs/PROJECT_CONTEXT.md
git commit -m "feat(ios): snapshot 2d constellation baseline"
```

## Task 2: Retire dormant RealityKit allocation from the 2D runtime

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift`
- Modify: `ios-app/Tests/MyAIMapTests/UniverseModeTests.swift`
- Modify: `ios-app/docs/ARCHITECTURE.md`
- Modify: `ios-app/docs/STATE_OWNERSHIP.md`

**Interfaces:**
- Consumes: `UniverseMode`, `UniverseConstellationView`, and semantic
  accessibility identifiers `ConstellationCategory.<id>` / `ConstellationStar.<id>`.
- Produces: `UniverseMapView` with no `UniverseSceneController`,
  `CameraRigController`, or `UniverseGestureController` state; an overlay that
  relies only on the 2D renderer’s layout/selection inputs.

- [ ] **Step 1: Add a failing source-boundary test**

Create `Tests/MyAIMapTests/RendererBoundaryTests.swift` and assert the runtime
boundary through a new pure `MapRendererKind.release` value equal to
`.constellation2D`.

```swift
@Test func releaseRendererIsConstellation2D() {
    #expect(MapRendererKind.release == .constellation2D)
}
```

The test must not instantiate RealityKit or rely on implementation string
matching when a typed release renderer value is available.

- [ ] **Step 2: Implement the narrow renderer boundary**

Introduce the smallest typed declaration that makes the release choice
explicit:

```swift
enum MapRendererKind: Sendable, Equatable {
    case constellation2D
    static let release: Self = .constellation2D
}
```

Delete `sceneController`, `cameraRig`, `gestureController`, `focusCamera`, and
`maybeSnapToNeighborSun` from `UniverseMapView`. Remove the `cameraRig`
parameter and projected-label calculations from the live `UniverseOverlayView`
path. Do not delete legacy RealityKit source files in this task; retaining them
in history avoids coupling a renderer-retirement decision to a file purge.

- [ ] **Step 3: Make ambient work obey backdrop state**

Change the constellation’s breathing condition from:

```swift
guard !staticMotion else { return }
```

to:

```swift
guard !staticMotion, !mode.pausesAmbientMotion else { return }
```

and reset `breath = false` when mode enters a paused state. Add a pure
`UniverseModeTests` assertion covering overview, branch, selected tool, detail,
and chat.

- [ ] **Step 4: Run focused checks**

Run:

```bash
cd ios-app
xcodegen generate
xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MyAIMapTests/RendererBoundaryTests \
  -only-testing:MyAIMapTests/UniverseModeTests \
  -derivedDataPath /tmp/aimap-foundation-dd \
  -resultBundlePath /tmp/aimap-foundation-renderer.xcresult
xcrun xcresulttool get test-results summary --path /tmp/aimap-foundation-renderer.xcresult
```

- [ ] **Step 5: Document and commit the isolation**

Update `ARCHITECTURE.md` and `STATE_OWNERSHIP.md` to state that RealityKit is
not constructed by the release map. Commit:

```bash
git add ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift \
  ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift \
  ios-app/Sources/MyAIMap/Universe/MapRendererKind.swift \
  ios-app/Sources/MyAIMap/Universe/UniverseConstellationView.swift \
  ios-app/Tests/MyAIMapTests/RendererBoundaryTests.swift \
  ios-app/Tests/MyAIMapTests/UniverseModeTests.swift \
  ios-app/docs/ARCHITECTURE.md ios-app/docs/STATE_OWNERSHIP.md
git commit -m "refactor(ios): isolate 2d map renderer"
```

## Task 3: Replace compact-detail timing mirrors with a typed route

**Files:**
- Create: `ios-app/Sources/MyAIMap/State/DetailRoute.swift`
- Modify: `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseMode.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift`
- Modify: `ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift`
- Modify: `ios-app/Tests/MyAIMapTests/UniverseModeTests.swift`
- Modify: `ios-app/Tests/MyAIMapUITests/UniverseUISmokeTests.swift`
- Modify: `ios-app/docs/STATE_OWNERSHIP.md`
- Modify: `ios-app/docs/UI_TRANSITION_CATALOG.md`

**Interfaces:**
- Consumes: valid visible `Tool.id` and `UniverseMode.toolSelected(category, id)`.
- Produces: `DetailRoute` value owned by the model and a single
  `Binding<DetailRoute?>` at the compact map host.

- [ ] **Step 1: Write route-state tests before refactoring the sheet**

Add a value type with exact restoration state:

```swift
struct DetailRoute: Identifiable, Equatable {
    let toolID: String
    let returnMode: UniverseMode
    var id: String { toolID }
}
```

Write tests that prove: opening a visible selected tool creates a route;
opening a missing/hidden tool creates no route; cancelling preserves the route;
dismissing clears it and restores exactly `returnMode`; related-tool selection
replaces the visible tool without introducing a second Boolean state.

- [ ] **Step 2: Implement model-owned detail intents**

Add `private(set) var detailRoute: DetailRoute?` and these model intents:

```swift
func requestDetail(for toolID: String)
func dismissDetail()
func replaceDetailTool(with toolID: String)
```

`requestDetail` validates `visibleAllTools`, records `.toolSelected` as the
return mode when applicable, and sets `universeMode = .detail`. `dismissDetail`
restores the route’s exact `returnMode` before setting `detailRoute = nil`.
No view computes a fallback route from projected selection.

- [ ] **Step 3: Bind the compact sheet to the optional route**

Replace `detailPresented` and `modeBeforeDetail` with `.sheet(item:)` driven
by `Binding<DetailRoute?>` that calls `model.dismissDetail()` from both the
sheet dismissal callback and the visible close action. Preserve the current
system-sheet presentation detents, drag indicator, corner radius, and visual
appearance; do not add `matchedTransitionSource`, a hero host, or custom drag
progress in this task. Keep the regular-width inspector derived from explicit
selected-tool state. Remove
`DispatchQueue.main.asyncAfter` detail-to-Account/Add sequencing; dismiss the
detail route first, then schedule the next typed app-sheet intent through the
single presentation owner introduced by the next plan.

- [ ] **Step 4: Exercise interruption paths in UI smoke**

Extend `UniverseUISmokeTests` with compact-width checks that open detail from a
map tool, partially drag then cancel, completely dismiss, rapidly reopen, and
open a related tool. Assert the return node identifier
`ConstellationStar.<toolID>` is present and hittable after dismissal.

- [ ] **Step 5: Run focused test evidence and commit**

Run:

```bash
cd ios-app
xcodegen generate
xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:MyAIMapTests/UniverseViewModelTests \
  -only-testing:MyAIMapTests/UniverseModeTests \
  -only-testing:MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates \
  -derivedDataPath /tmp/aimap-foundation-dd \
  -resultBundlePath /tmp/aimap-foundation-route.xcresult
xcrun xcresulttool get test-results summary --path /tmp/aimap-foundation-route.xcresult
git add ios-app/Sources/MyAIMap/State/UniverseViewModel.swift \
  ios-app/Sources/MyAIMap/State/DetailRoute.swift \
  ios-app/Sources/MyAIMap/Universe/UniverseMode.swift \
  ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift \
  ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift \
  ios-app/Tests/MyAIMapTests/UniverseModeTests.swift \
  ios-app/Tests/MyAIMapUITests/UniverseUISmokeTests.swift \
  ios-app/docs/STATE_OWNERSHIP.md ios-app/docs/UI_TRANSITION_CATALOG.md
git commit -m "refactor(ios): make compact detail route typed"
```

In `UI_TRANSITION_CATALOG.md`, record this as a route-ownership improvement
only. Keep the T-05 shared-element pilot explicitly blocked until its required
visual reference is supplied and reviewed.

## Task 4: Record release-quality foundation evidence

**Files:**
- Modify: `ios-app/docs/QA_REGRESSION_CHECKLIST.md`
- Modify: `ios-app/docs/ARCHITECTURE.md`
- Modify: `ios-app/docs/TECHNICAL_DEBT.md`
- Modify: `docs/superpowers/specs/2026-07-26-ios-local-first-platform-design.md`

**Interfaces:**
- Consumes: the fresh renderer and route `xcresult` bundles.
- Produces: evidence/remaining-risk record that gates the catalog and release
  plans.

- [ ] **Step 1: Add a run-specific evidence section**

Record date, git commit, Xcode version, simulator runtime, `passedTests`, and
the exact `xcresult` paths. A historical test count cannot be copied as fresh
evidence.

- [ ] **Step 2: Run the non-automated device matrix**

On compact iPhone, current iPhone, and iPad verify: cold/warm launch; map
category/tool/empty taps; root Map ↔ Ask AI; keyboard and attachment cancel;
detail cancel/finish/reopen; Dynamic Type; VoiceOver; and Reduce Motion.
Record each result as pass, fail, or not-run with a reason.

- [ ] **Step 3: Measure before claiming performance improvement**

Use Instruments SwiftUI and Time Profiler on a physical supported low-end
iPhone and a current iPhone. Record cold/warm launch-to-interactive, first map
interaction, branch selection, chat open, typing, CPU, memory, and frame
pacing. Do not claim that removing dormant controllers improved a metric unless
the before/after trace names the same device and build.

- [ ] **Step 4: Commit evidence only after all required artifacts exist**

```bash
git add ios-app/docs/QA_REGRESSION_CHECKLIST.md \
  ios-app/docs/ARCHITECTURE.md ios-app/docs/TECHNICAL_DEBT.md \
  docs/superpowers/specs/2026-07-26-ios-local-first-platform-design.md
git commit -m "docs(ios): record local-first foundation evidence"
```

## Next independently shippable plans

1. **Catalog durability:** versioned Application Support document, atomic
   migration from `UniverseStore` v1, recovery, backup, export/import, and
   Delete All Local Data contract.
2. **State/service split:** `AppShell` sheet router, `CatalogRepository`,
   `AssistantSession`, and a thin `UniverseViewModel` façade without observable
   behavior changes.
3. **Release security and App Store:** Release-only local assistant, privacy
   manifest/policy/labels, provenance, pinned CI, archive and TestFlight gates.
4. **Optional cloud ADR:** only after the preceding release is stable; includes
   auth, sync conflicts, tenant isolation, AI gateway, deletion, load, cost,
   and SLO design.

## Self-review

- **Spec coverage:** tasks cover candidate preservation, renderer isolation,
  ambient work, compact-detail ownership, automated evidence, manual device
  evidence, and rollback boundaries. Catalog migration, cloud, and hosted AI
  are intentionally separate release projects so they cannot be hidden inside
  a renderer refactor.
- **Placeholder scan:** no task delegates a behavior decision to an unnamed
  future change; every implementation task names files, interfaces, command,
  and acceptance evidence.
- **Type consistency:** `DetailRoute`, `requestDetail(for:)`,
  `dismissDetail()`, `replaceDetailTool(with:)`, and
  `MapRendererKind.release` use the same spellings throughout this plan.
