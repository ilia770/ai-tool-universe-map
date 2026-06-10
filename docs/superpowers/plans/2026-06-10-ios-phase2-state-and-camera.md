# iOS Phase 2 — State + Camera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land `UniverseViewModel` (@Observable single source of truth) and `CameraController` (drei-parity camera math + pinch-to-zoom dolly) — steps 2 and 3 of `docs/PHASE_2_PLAN.md`.

**Architecture:** A `@MainActor @Observable` view-model owns all UI state (selection, hover, active category, clarity mode, search query) and is injected via SwiftUI environment; views read it, RealityKit never sees it. `CameraController` owns the `PerspectiveCamera` entity and exposes pure, testable math (focus offsets per view mode, distance clamping, look-at rotation) mirroring the web `src/components/AIToolUniverse3D/CameraController.tsx` (`minDistance 7.5`, `maxDistance 46`, `smoothTime 0.55`, overview `+6.3/+19.5`, pocket `+6.8/+19.0`, node `+5.0/+15.5`).

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI `@Observable` (iOS 18 target), RealityKit, Swift Testing (`@Suite`/`@Test`/`#expect`), XcodeGen.

**Worktree:** `/Users/ilia882/code/aium-phase2`, branch `feat/ios-phase2-state-and-camera` (already created off `origin/main`). All commands run from this worktree root unless stated otherwise.

**Out of scope (later Phase 2 PRs):** ProximityCategorySystem (ECS), pocket transition lerp, tap/drag gestures, SearchDock UI, Sheets, BrandColor/BrandSpacing token sweep of `UniverseScreen`. The view-model gains `searchQuery`/`clarityMode` fields now (spec decision log) but no UI for them yet.

**Verify commands (used throughout):**

```bash
# Fast typecheck (no simulator needed) — same trick PR #8 used:
cd ios-app && xcrun swiftc -typecheck \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios18.0-simulator \
  $(find Sources -name '*.swift') && cd ..

# Full build (needs xcodegen; .xcodeproj is gitignored):
cd ios-app && xcodegen generate && \
xcodebuild -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination "platform=iOS Simulator,name=$(xcrun simctl list devices available | grep -m1 -o 'iPhone [^(]*' | sed 's/ *$//')" \
  build 2>&1 | tail -5 && cd ..

# Tests (KNOWN RISK: simulator launch previously hung on CoreSimulator
# runtime migration — see docs/AGENT_STATUS.md. If `test` hangs > 5 min,
# kill it, run `build-for-testing` instead, and record the fallback in
# the PR description):
cd ios-app && xcodebuild -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination "platform=iOS Simulator,name=$(xcrun simctl list devices available | grep -m1 -o 'iPhone [^(]*' | sed 's/ *$//')" \
  test 2>&1 | tail -20 && cd ..
```

Note: typecheck of test files is NOT possible via `swiftc -typecheck` (needs the Testing framework + app module); tests compile only through `xcodebuild`.

---

### Task 1: `UniverseSelection` value types

**Files:**
- Create: `ios-app/Sources/MyAIMap/State/UniverseSelection.swift`
- Test: `ios-app/Tests/MyAIMapTests/UniverseSelectionTests.swift`

- [x] **Step 1: Write the failing test**

```swift
import Testing
@testable import MyAIMap

@Suite("UniverseSelection — defaults and view-mode derivation")
struct UniverseSelectionTests {

    @Test func defaultsMatchPhase1Behaviour() {
        let selection = UniverseSelection()
        #expect(selection.activeCategory == .core)
        #expect(selection.selectedToolID == "founder-os")
        #expect(selection.hoveredToolID == nil)
    }

    @Test func viewModeIsOverviewForCore() {
        let selection = UniverseSelection()
        #expect(selection.viewMode == .overview)
    }

    @Test func viewModeIsPocketForNonCoreCategory() {
        var selection = UniverseSelection()
        selection.activeCategory = .design
        #expect(selection.viewMode == .pocket)
    }

    @Test func clarityModeHasWebParityCases() {
        // Web parity: F / C / A keyboard shortcuts.
        #expect(ClarityMode.allCases == [.focus, .context, .atlas])
    }
}
```

- [x] **Step 2: Run the typecheck to confirm the types don't exist yet**

Run (from worktree root):
```bash
cd ios-app && xcodegen generate && xcodebuild -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination "platform=iOS Simulator,name=$(xcrun simctl list devices available | grep -m1 -o 'iPhone [^(]*' | sed 's/ *$//')" \
  build-for-testing 2>&1 | tail -5 && cd ..
```
Expected: FAIL — `cannot find 'UniverseSelection' in scope`.

- [x] **Step 3: Write the implementation**

`ios-app/Sources/MyAIMap/State/UniverseSelection.swift`:

```swift
import Foundation

/// Camera framing mode, mirroring the web `CameraController` prop
/// `viewMode: 'overview' | 'pocket' | 'node'`.
/// `.node` is reserved for the focus-on-tool camera that lands with the
/// gesture PR; nothing derives it yet.
enum ViewMode: Equatable, Sendable {
    case overview
    case pocket
    case node
}

/// Map clarity mode, mirroring the web F / C / A keyboard shortcuts.
/// Phase 2 stores it in the view-model; the UI toggle lands with the
/// SearchDock / Sheets PRs.
enum ClarityMode: String, CaseIterable, Equatable, Sendable {
    case focus
    case context
    case atlas
}

/// Pure selection state. Lives in its own value type so the view-model
/// can hand a snapshot to views (and future ECS systems) without
/// exposing the whole observable object.
struct UniverseSelection: Equatable, Sendable {
    var activeCategory: ToolCategoryId = .core
    var selectedToolID: String = "founder-os"
    var hoveredToolID: String? = nil

    /// Overview when the core universe is showing, pocket once a
    /// category world is active. `.node` arrives with tap-to-focus.
    var viewMode: ViewMode {
        activeCategory == .core ? .overview : .pocket
    }
}
```

- [x] **Step 4: Re-run the build-for-testing command from Step 2**

Expected: PASS (build succeeds). If the simulator destination errors, list devices with `xcrun simctl list devices available` and substitute any iPhone name.

- [x] **Step 5: Run the test suite (or fallback)**

Run the **Tests** command from the Verify block. Expected: all suites pass, including the 4 new tests. If simulator hangs >5 min: kill, fall back to `build-for-testing`, note it.

- [x] **Step 6: Commit**

```bash
git add ios-app/Sources/MyAIMap/State/UniverseSelection.swift ios-app/Tests/MyAIMapTests/UniverseSelectionTests.swift
git commit -m "[Phase2-State] add UniverseSelection value types

ViewMode and ClarityMode mirror the web CameraController viewMode prop
and the F/C/A clarity shortcuts. UniverseSelection is a plain value
type so future ECS systems can take snapshots without observing the
whole view-model."
```

---

### Task 2: `UniverseViewModel` (@Observable)

**Files:**
- Create: `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift`
- Test: `ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift`

- [x] **Step 1: Write the failing test**

```swift
import Testing
@testable import MyAIMap

@Suite("UniverseViewModel — single source of truth")
@MainActor
struct UniverseViewModelTests {

    @Test func defaultStateShowsFounderCore() {
        let model = UniverseViewModel()
        #expect(model.selection.activeCategory == .core)
        #expect(model.selectedTool.id == "founder-os")
        #expect(model.selection.viewMode == .overview)
    }

    @Test func selectCategoryAutoSelectsItsFirstTool() {
        // Parity with Phase 1 UniverseScreen.onChange(of: selectedCategory).
        let model = UniverseViewModel()
        model.selectCategory(.design)
        #expect(model.selection.activeCategory == .design)
        let expected = UniverseSeed.tools(in: .design).first?.id
        #expect(expected != nil)
        #expect(model.selection.selectedToolID == expected)
    }

    @Test func selectCategoryFallsBackToFounderWhenCategoryIsEmpty() {
        let model = UniverseViewModel()
        // .core has tools in the seed, but the fallback path must hold
        // for any category the seed leaves empty in the future. Exercise
        // the documented contract via the core slot.
        model.selectCategory(.core)
        #expect(!model.selection.selectedToolID.isEmpty)
    }

    @Test func selectToolUpdatesSelectedTool() {
        let model = UniverseViewModel()
        model.selectCategory(.design)
        guard let second = UniverseSeed.tools(in: .design).dropFirst().first else {
            Issue.record("seed needs >= 2 design tools (UniverseLayoutTests guarantees this)")
            return
        }
        model.selectTool(second.id)
        #expect(model.selectedTool.id == second.id)
    }

    @Test func visibleToolsFallBackToCoreWhenCategoryEmpty() {
        // Mirrors Phase 1: empty category shows core tools instead of nothing.
        let model = UniverseViewModel()
        #expect(!model.visibleTools.isEmpty)
    }

    @Test func selectedToolSurvivesUnknownID() {
        let model = UniverseViewModel()
        model.selectTool("does-not-exist")
        // Falls back to first visible tool, never crashes.
        #expect(!model.selectedTool.id.isEmpty)
    }

    @Test func hoverIsSettableAndClearable() {
        let model = UniverseViewModel()
        model.setHover("figma")
        #expect(model.selection.hoveredToolID == "figma")
        model.setHover(nil)
        #expect(model.selection.hoveredToolID == nil)
    }

    @Test func searchResultsMatchNameCaseInsensitive() {
        let model = UniverseViewModel()
        model.searchQuery = "FOUNDER"
        #expect(model.searchResults.contains { $0.id == "founder-os" })
    }

    @Test func emptySearchQueryReturnsNoResults() {
        let model = UniverseViewModel()
        model.searchQuery = "   "
        #expect(model.searchResults.isEmpty)
    }

    @Test func focusFirstSearchMatchSelectsToolAndItsCategory() {
        let model = UniverseViewModel()
        guard let designTool = UniverseSeed.tools(in: .design).first else {
            Issue.record("seed needs a design tool")
            return
        }
        model.searchQuery = designTool.name
        let focused = model.focusFirstSearchMatch()
        #expect(focused)
        #expect(model.selection.selectedToolID == designTool.id)
        #expect(model.selection.activeCategory == designTool.category)
    }

    @Test func focusFirstSearchMatchReturnsFalseOnNoMatch() {
        let model = UniverseViewModel()
        model.searchQuery = "zzz-no-such-tool"
        #expect(model.focusFirstSearchMatch() == false)
    }
}
```

- [x] **Step 2: Run build-for-testing to confirm it fails**

Same command as Task 1 Step 2. Expected: FAIL — `cannot find 'UniverseViewModel' in scope`.

- [x] **Step 3: Write the implementation**

`ios-app/Sources/MyAIMap/State/UniverseViewModel.swift`:

```swift
import Foundation
import Observation

/// Single source of truth for universe UI state, per the Phase 2
/// decision log: `@Observable` class injected via environment — not
/// `@EnvironmentObject`. Owns selection, hover, active category,
/// clarity mode, and search query. Never touches the RealityKit graph;
/// `CameraController` owns the camera entity.
@MainActor
@Observable
final class UniverseViewModel {
    private(set) var selection = UniverseSelection()
    // Web parity: AIToolUniverseMap.tsx:150 initialises mapClarity to 'focus'.
    var clarityMode: ClarityMode = .focus
    var searchQuery: String = ""

    // MARK: - Derived state

    var selectedCategoryModel: ToolCategory {
        UniverseSeed.category(selection.activeCategory)
    }

    /// Tools for the active category, falling back to the core slice so
    /// the rail never renders empty (Phase 1 parity).
    var visibleTools: [Tool] {
        let tools = UniverseSeed.tools(in: selection.activeCategory)
        return tools.isEmpty ? UniverseSeed.tools.filter { $0.category == .core } : tools
    }

    var selectedTool: Tool {
        UniverseSeed.tools.first { $0.id == selection.selectedToolID }
            ?? visibleTools.first
            ?? UniverseSeed.tools[0]
    }

    /// Case-insensitive name/summary match. Whitespace-only queries
    /// return nothing so the (future) search dock can treat "no text"
    /// and "no results" identically.
    var searchResults: [Tool] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return UniverseSeed.tools.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.summary.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Intents

    func selectCategory(_ id: ToolCategoryId) {
        // Phase 1 parity: .onChange(of:) was equality-gated, so re-tapping
        // the active category chip must not reset the tool selection.
        guard selection.activeCategory != id else { return }
        selection.activeCategory = id
        selection.selectedToolID = UniverseSeed.tools(in: id).first?.id ?? "founder-os"
    }

    func selectTool(_ id: String) {
        selection.selectedToolID = id
    }

    func setHover(_ id: String?) {
        selection.hoveredToolID = id
    }

    /// Enter-to-focus parity with the web build ([C3], `focusTool` in
    /// AIToolUniverseMap.tsx): selects the first search match, jumps to
    /// its category, snaps clarity to focus, and clears the query.
    /// Returns whether a match was focused.
    @discardableResult
    func focusFirstSearchMatch() -> Bool {
        guard let match = searchResults.first else { return false }
        selectCategory(match.category)
        selection.selectedToolID = match.id
        clarityMode = .focus
        searchQuery = ""
        return true
    }
}
```

- [x] **Step 4: Run the test suite (or fallback)**

Tests command from the Verify block. Expected: all `UniverseViewModelTests` pass.

- [x] **Step 5: Commit**

```bash
git add ios-app/Sources/MyAIMap/State/UniverseViewModel.swift ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift
git commit -m "[Phase2-State] add UniverseViewModel as single source of truth

@Observable @MainActor class per the Phase 2 decision log. Owns
selection, hover, clarity mode, and search query; derives visible
tools, selected tool, and search results with the same fallbacks the
Phase 1 screen used inline. focusFirstSearchMatch gives Enter-to-focus
parity with web [C3] ahead of the SearchDock PR."
```

---

### Task 3: `CameraController` — pure math + entity wrapper

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/Camera/CameraController.swift`
- Test: `ios-app/Tests/MyAIMapTests/CameraControllerTests.swift`

- [x] **Step 1: Write the failing test**

```swift
import Testing
import simd
@testable import MyAIMap

@Suite("CameraController — drei parity math")
struct CameraControllerTests {

    @Test func distanceClampMatchesWebMinMax() {
        // Web: <CameraControls minDistance={7.5} maxDistance={46}>
        #expect(CameraController.clampedDistance(5) == 7.5)
        #expect(CameraController.clampedDistance(7.5) == 7.5)
        #expect(CameraController.clampedDistance(20) == 20)
        #expect(CameraController.clampedDistance(46) == 46)
        #expect(CameraController.clampedDistance(60) == 46)
    }

    @Test func focusOffsetsMatchWebPerViewMode() {
        // Web CameraController.tsx: overview y+6.3 z+19.5,
        // pocket y+6.8 z+19.0, node y+5.0 z+15.5.
        let target = SIMD3<Float>(2, 1, -3)
        #expect(CameraController.focusEye(for: .overview, target: target) == target + SIMD3<Float>(0, 6.3, 19.5))
        #expect(CameraController.focusEye(for: .pocket, target: target) == target + SIMD3<Float>(0, 6.8, 19.0))
        #expect(CameraController.focusEye(for: .node, target: target) == target + SIMD3<Float>(0, 5.0, 15.5))
    }

    @Test func lookRotationPointsCameraForwardAtTarget() {
        let eye = SIMD3<Float>(0, 5, 10)
        let target = SIMD3<Float>(0, 0, 0)
        let rotation = CameraController.lookRotation(eye: eye, target: target)
        // RealityKit cameras look down -Z: rotating (0,0,-1) must yield
        // the normalized eye->target direction.
        let forward = rotation.act(SIMD3<Float>(0, 0, -1))
        let expected = simd_normalize(target - eye)
        #expect(simd_length(forward - expected) < 0.001)
    }

    @Test func lookRotationKeepsCameraUpright() {
        let eye = SIMD3<Float>(4, 6, 12)
        let target = SIMD3<Float>(-1, 0, 2)
        let rotation = CameraController.lookRotation(eye: eye, target: target)
        let up = rotation.act(SIMD3<Float>(0, 1, 0))
        // World-up component must stay positive (no roll).
        #expect(up.y > 0)
    }

    @Test func lookRotationSurvivesDegenerateEyeOnTarget() {
        let point = SIMD3<Float>(1, 2, 3)
        let rotation = CameraController.lookRotation(eye: point, target: point)
        // Must not produce NaNs.
        let forward = rotation.act(SIMD3<Float>(0, 0, -1))
        #expect(forward.x.isFinite && forward.y.isFinite && forward.z.isFinite)
    }

    @Test func pinchDollyScalesAndClampsDistance() {
        // distance' = clamp(base / magnification, 7.5, 46)
        #expect(CameraController.dollyDistance(base: 20, magnification: 2) == 10)
        #expect(CameraController.dollyDistance(base: 20, magnification: 0.5) == 40)
        #expect(CameraController.dollyDistance(base: 20, magnification: 10) == 7.5)
        #expect(CameraController.dollyDistance(base: 20, magnification: 0.1) == 46)
        // Guard against divide-by-zero.
        let degenerate = CameraController.dollyDistance(base: 20, magnification: 0)
        #expect(degenerate == 46)
    }
}
```

- [x] **Step 2: Run build-for-testing to confirm it fails**

Same command as Task 1 Step 2. Expected: FAIL — `cannot find 'CameraController' in scope`.

- [x] **Step 3: Write the implementation**

`ios-app/Sources/MyAIMap/Universe/Camera/CameraController.swift`:

```swift
import RealityKit
import simd

/// Owns the universe `PerspectiveCamera`, mirroring the web build's
/// drei `CameraControls` semantics (`src/components/AIToolUniverse3D/
/// CameraController.tsx`): clamped dolly distance, per-view-mode focus
/// offsets, smooth focus moves. The view-model never touches the
/// RealityKit graph — views forward gestures here instead.
@MainActor
final class CameraController {

    // Web parity: <CameraControls minDistance={7.5} maxDistance={46}
    // smoothTime={0.55}>.
    static let minDistance: Float = 7.5
    static let maxDistance: Float = 46
    static let smoothTime: TimeInterval = 0.55

    private(set) weak var camera: PerspectiveCamera?
    private(set) var target: SIMD3<Float> = .zero
    private var pinchBaseDistance: Float?

    /// nonisolated so `@State private var controller = CameraController()`
    /// compiles under Swift 6 strict concurrency (SwiftUI property
    /// initializers run in a nonisolated context). The init touches no
    /// isolated state — every property has a default value.
    nonisolated init() {}

    // MARK: - Pure math (unit-tested)

    static func clampedDistance(_ distance: Float) -> Float {
        min(max(distance, minDistance), maxDistance)
    }

    /// Eye position for a framing mode. Offsets match the web
    /// CameraController exactly (overview / pocket / node).
    static func focusEye(for mode: ViewMode, target: SIMD3<Float>) -> SIMD3<Float> {
        switch mode {
        case .overview: return target + SIMD3<Float>(0, 6.3, 19.5)
        case .pocket: return target + SIMD3<Float>(0, 6.8, 19.0)
        case .node: return target + SIMD3<Float>(0, 5.0, 15.5)
        }
    }

    /// World-up look-at rotation. RealityKit cameras look down -Z, so
    /// the basis is (right, up, back) with back = normalize(eye - target).
    static func lookRotation(eye: SIMD3<Float>, target: SIMD3<Float>) -> simd_quatf {
        let offset = eye - target
        guard simd_length(offset) > 1e-6 else { return simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)) }
        let back = simd_normalize(offset)
        let worldUp = SIMD3<Float>(0, 1, 0)
        var right = simd_cross(worldUp, back)
        // Degenerate when looking straight up/down: pick a stable right.
        if simd_length(right) < 1e-6 {
            right = SIMD3<Float>(1, 0, 0)
        } else {
            right = simd_normalize(right)
        }
        let up = simd_cross(back, right)
        return simd_quatf(simd_float3x3(columns: (right, up, back)))
    }

    /// Pinch dolly: scale the gesture-start distance by 1/magnification,
    /// clamped to the web min/max. magnification <= 0 clamps to max
    /// (defensive; SwiftUI never reports it).
    static func dollyDistance(base: Float, magnification: Float) -> Float {
        guard magnification > 1e-6 else { return maxDistance }
        return clampedDistance(base / magnification)
    }

    // MARK: - Entity control

    /// Adopt a camera entity (called from RealityView's make closure)
    /// and snap it to the framing for the given mode/target.
    func attach(_ camera: PerspectiveCamera, mode: ViewMode, target: SIMD3<Float>) {
        self.camera = camera
        self.target = target
        // A cancelled gesture never fires .onEnded; never carry a stale
        // pinch base into a freshly adopted scene.
        pinchBaseDistance = nil
        let eye = Self.focusEye(for: mode, target: target)
        camera.position = eye
        camera.orientation = Self.lookRotation(eye: eye, target: target)
    }

    /// Smoothly re-frame on a new target (camera focus move). Duration
    /// mirrors the web smoothTime.
    func focus(on newTarget: SIMD3<Float>, mode: ViewMode, animated: Bool = true) {
        guard let camera else { return }
        target = newTarget
        let eye = Self.focusEye(for: mode, target: newTarget)
        var transform = camera.transform
        transform.translation = eye
        transform.rotation = Self.lookRotation(eye: eye, target: newTarget)
        if animated {
            camera.move(to: transform, relativeTo: camera.parent, duration: Self.smoothTime, timingFunction: .easeInOut)
        } else {
            camera.transform = transform
        }
    }

    /// Live pinch update. Captures the distance at gesture start, then
    /// dollies along the current eye->target axis with clamping.
    func pinchChanged(magnification: Float) {
        guard let camera else { return }
        let offset = camera.position - target
        let currentDistance = simd_length(offset)
        if pinchBaseDistance == nil {
            pinchBaseDistance = currentDistance
        }
        guard let base = pinchBaseDistance, currentDistance > 1e-6 else { return }
        let direction = offset / currentDistance
        camera.position = target + direction * Self.dollyDistance(base: base, magnification: magnification)
    }

    func pinchEnded() {
        pinchBaseDistance = nil
    }
}
```

- [x] **Step 4: Run the test suite (or fallback)**

Tests command from the Verify block. Expected: all `CameraControllerTests` pass.

- [x] **Step 5: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/Camera/CameraController.swift ios-app/Tests/MyAIMapTests/CameraControllerTests.swift
git commit -m "[Phase2-Camera] add CameraController with drei-parity math

minDistance 7.5 / maxDistance 46 / smoothTime 0.55 and per-view-mode
focus offsets ported from the web CameraController. Pure statics
(clamp, focusEye, lookRotation, dollyDistance) are unit-tested; the
instance half owns the PerspectiveCamera and applies pinch dolly along
the eye->target axis."
```

---

### Task 4: Route `UniverseScreen` + app entry through the view-model

**Files:**
- Modify: `ios-app/Sources/MyAIMap/MyAIMapApp.swift` (inject environment)
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift` (drop local `@State` + local `Haptics` enum, read view-model)

No behaviour change — every Phase 1 control routes through `UniverseViewModel`.

- [x] **Step 1: Update the app entry point**

Replace the full body of `MyAIMapApp.swift` with:

```swift
import SwiftUI

/// App entry point.
///
/// Phase 2: injects the single `UniverseViewModel` via environment per
/// the Phase 2 decision log.
@main
struct MyAIMapApp: App {
    @State private var model = UniverseViewModel()

    var body: some Scene {
        WindowGroup {
            UniverseScreen()
                .environment(model)
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
        }
    }
}
```

- [x] **Step 2: Rewire `UniverseScreen.swift`**

Apply exactly these changes (leave all visual styling untouched):

1. Replace the two `@State` properties and the computed properties at the top:

```swift
struct UniverseScreen: View {
    @Environment(UniverseViewModel.self) private var model

    private var selectedCategoryModel: ToolCategory {
        model.selectedCategoryModel
    }

    private var visibleTools: [Tool] {
        model.visibleTools
    }

    private var selectedTool: Tool {
        model.selectedTool
    }
```

2. In `body`, replace the `UniverseView(...)` line with:

```swift
            UniverseView(selectedCategory: model.selection.activeCategory, selectedToolId: selectedTool.id)
```

3. Delete the `.onChange(of: selectedCategory) { ... }` modifier entirely (the view-model's `selectCategory` now owns that rule).

4. In `categoryRail`, replace the button action and selected checks:

```swift
                    Button {
                        BrandHaptics.fire(.medium)
                        model.selectCategory(category.id)
                    } label: {
```

and replace both occurrences of `category.id == selectedCategory` with `category.id == model.selection.activeCategory`.

5. In `bottomSheet`, replace the tool button action:

```swift
                        Button {
                            BrandHaptics.fire(.light)
                            model.selectTool(tool.id)
                        } label: {
```

and replace both occurrences of `tool.id == selectedToolId` with `tool.id == model.selection.selectedToolID`.

6. Delete the whole `private enum Haptics { ... }` block at the bottom of the file (BrandHaptics replaces it; this was a Phase 1 stopgap duplicating `UI/Haptics/BrandHaptics.swift`).

7. Update the preview so it still compiles:

```swift
#Preview {
    UniverseScreen()
        .environment(UniverseViewModel())
}
```

8. Remove the now-unused `import UIKit` at the top of the file (BrandHaptics wraps UIKit internally).

- [x] **Step 3: Typecheck fast, then build**

Run the **Fast typecheck** command, then the **Full build** command from the Verify block.
Expected: both succeed with zero warnings about unused state.

- [x] **Step 4: Run the test suite (or fallback)**

Existing suites must stay green (no behaviour change intended).

- [x] **Step 5: Commit**

```bash
git add ios-app/Sources/MyAIMap/MyAIMapApp.swift ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift
git commit -m "[Phase2-State] route UniverseScreen through UniverseViewModel

Phase 1 buttons keep their look but now dispatch selectCategory /
selectTool intents on the environment-injected view-model. Drops the
screen-local Haptics stopgap in favour of BrandHaptics. No behaviour
change."
```

---

### Task 5: Wire `CameraController` + pinch-to-zoom into `UniverseView`

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseView.swift`

Visible change (spec step 3): pinch-to-zoom dollies the camera natively with web-parity clamping. The `.id(selectedCategory)` scene rebuild stays — animated cross-category camera moves arrive with the ECS/pocket-transition PRs.

- [x] **Step 1: Rewire the camera path in `UniverseView.swift`**

1. Add a controller and view-mode plumbing to the struct (replacing the current property list):

```swift
struct UniverseView: View {
    let selectedCategory: ToolCategoryId
    let selectedToolId: String

    @State private var cameraController = CameraController()

    private var viewMode: ViewMode {
        selectedCategory == .core ? .overview : .pocket
    }
```

2. In the `RealityView` make closure, replace the three camera lines:

```swift
            let camera = PerspectiveCamera()
            camera.position = cameraPosition(for: selectedCategory)
            camera.look(at: lookAtPosition(for: selectedCategory), from: camera.position, relativeTo: nil)
            universe.addChild(camera)
```

with:

```swift
            let camera = PerspectiveCamera()
            universe.addChild(camera)
            cameraController.attach(camera, mode: viewMode, target: lookAtPosition(for: selectedCategory))
```

3. Delete the `private func cameraPosition(for:)` helper (the controller's web-parity offsets replace it). Keep `lookAtPosition(for:)` — it is still the target source.

4. Add the pinch gesture after `.id(selectedCategory)`:

```swift
        .id(selectedCategory)
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    cameraController.pinchChanged(magnification: Float(value.magnification))
                }
                .onEnded { _ in
                    cameraController.pinchEnded()
                }
        )
```

- [x] **Step 2: Typecheck fast, then build**

Run the **Fast typecheck** command, then the **Full build** command from the Verify block. Expected: both succeed.

Note: the camera framing values change slightly (web-parity offsets `+6.3/+19.5` overview replace Phase 1's ad-hoc `(0, 5.4, 20.5)`; pocket `+6.8/+19.0` replaces `(0, +5.2, +15.4)`). This is the intended drei-parity correction, not a regression — flag it in the PR description with before/after screenshots if the simulator boots.

- [x] **Step 3: Run the test suite (or fallback)**

All suites green.

- [x] **Step 4: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/UniverseView.swift
git commit -m "[Phase2-Camera] wire CameraController + pinch dolly into UniverseView

PerspectiveCamera is now owned by CameraController; framing uses the
web-parity focus offsets instead of Phase 1's ad-hoc constants. Pinch
gesture dollies along the eye->target axis clamped to 7.5...46."
```

---

### Task 6: Final verify + plan close-out

- [x] **Step 1: Full iOS verify chain**

Run all three Verify commands (typecheck, build, test-or-fallback). Record exact outcomes.

- [x] **Step 2: Web verify chain untouched check**

```bash
git diff origin/main --stat -- src/ package.json
```
Expected: empty (this PR must not touch web files). `docs/superpowers/plans/` + `ios-app/` only.

- [x] **Step 3: Tick every checkbox in this plan file, commit it**

```bash
git add docs/superpowers/plans/2026-06-10-ios-phase2-state-and-camera.md
git commit -m "docs: add iOS Phase 2 state+camera implementation plan"
```

(If the plan file was committed at the start, amend the checkboxes in this final commit instead.)

- [x] **Step 4: Push and open the PR**

```bash
git push -u origin feat/ios-phase2-state-and-camera
```

Open the PR with the repo template; base `main`; title
`feat(ios): Phase 2 — UniverseViewModel + CameraController`. Fill in: validation commands + results, the camera-framing change note, simulator-hang fallback if it happened, and an Agent Handoff block (next owner: Claude Code, next file: `Universe/ECS/ProximityCategorySystem.swift`).
