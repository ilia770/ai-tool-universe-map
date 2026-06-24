# Spatial Universe — Increment 1 (Spatial Spine) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing `.spatial3D` scene into a legible "galaxy of solar systems" — category suns, tool planets, selected-only reveal, near-zero chrome, hybrid tap-to-fly + free-orbit + step-up navigation.

**Architecture:** Reskin, not rebuild. Reuse `CameraRigController` (tap-to-fly framing + `pan` free-orbit already exist), `UniverseSceneController` (scene graph), and `UniverseMode` (state). New logic is small and lives in pure, unit-tested helpers wired into existing views. Only the `.spatial3D` path changes; the 2D graph stays default and untouched.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, RealityKit, simd, Swift Testing (`@Suite`/`@Test`/`#expect`). Verify via `npm run ios:verify`.

## Global Constraints

- Only the `.spatial3D` render path changes. `renderMode == .graph2D` stays default and behaviorally unchanged.
- No data-model changes. Suns are the existing `ToolCategory`/`PlanetData`; planets are the existing tools/satellites.
- No new product features. Composition + camera + reveal only. Atmosphere/material *quality* polish (skybox, volumetric light tuning, glass panel) is Increment 2 — out of scope.
- Honor `accessibilityReduceMotion` and the `-uitestStatic` / `prefersInstant` paths already in the codebase.
- All new shared logic goes in pure `@MainActor enum` or `nonisolated` helpers, unit-tested with Swift Testing.
- Simulator id for verify commands: `EAC2C682-5C38-44DB-8FEC-034E296E8EEA` (substitute a current booted id from `xcrun simctl list devices available`).
- Unit suite run: `npm run ios:verify -- --run-tests --device-id <id>` (runs the whole `MyAIMapTests` Swift Testing suite). Build + UI smoke: `npm run ios:verify -- --full-test --device-id <id>`.
- Conventional-commit messages. Commit after each task.

---

### Task 1: Hide map chrome in 3D (`SpatialChrome`)

In 3D the suns are the navigation, so the category rail, planet info card, and bottom category rail are noise. Centralize the show/hide rule as a pure predicate and gate the overlay on it.

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/SpatialChrome.swift`
- Create: `ios-app/Tests/MyAIMapTests/SpatialChromeTests.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift` (`bottomControls` ~line 527, `rightUniverseRail` gate ~line 82)

**Interfaces:**
- Produces: `enum SpatialChrome { static func showsMapChrome(renderMode: UniverseRenderMode, mode: UniverseMode, isUniverseEmpty: Bool) -> Bool }`

- [ ] **Step 1: Write the failing test**

```swift
// ios-app/Tests/MyAIMapTests/SpatialChromeTests.swift
import Testing
import simd
@testable import MyAIMap

@Suite("SpatialChrome — 3D hides map chrome")
struct SpatialChromeTests {
    @Test func chromeShowsInGraph2DOverview() {
        #expect(SpatialChrome.showsMapChrome(renderMode: .graph2D, mode: .overview, isUniverseEmpty: false) == true)
    }

    @Test func chromeHiddenInSpatial3D() {
        #expect(SpatialChrome.showsMapChrome(renderMode: .spatial3D, mode: .overview, isUniverseEmpty: false) == false)
    }

    @Test func chromeHiddenInDetailOrChatEvenIn2D() {
        #expect(SpatialChrome.showsMapChrome(renderMode: .graph2D, mode: .detail(.coding, "x"), isUniverseEmpty: false) == false)
        #expect(SpatialChrome.showsMapChrome(renderMode: .graph2D, mode: .chatOpen(nil, nil), isUniverseEmpty: false) == false)
    }

    @Test func chromeHiddenWhenEmpty() {
        #expect(SpatialChrome.showsMapChrome(renderMode: .graph2D, mode: .overview, isUniverseEmpty: true) == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run ios:verify -- --run-tests --device-id <id>`
Expected: FAIL — "cannot find 'SpatialChrome' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// ios-app/Sources/MyAIMap/Universe/SpatialChrome.swift
import Foundation

/// Chrome that only belongs to the 2D graph. In 3D the suns ARE the
/// navigation, so the category rail, planet info card, and bottom category
/// rail are hidden (principle 6: near-zero noise).
enum SpatialChrome {
    static func showsMapChrome(
        renderMode: UniverseRenderMode,
        mode: UniverseMode,
        isUniverseEmpty: Bool
    ) -> Bool {
        guard renderMode == .graph2D else { return false }
        return !mode.isDetailOpen && !mode.isChatOpen && !isUniverseEmpty
    }
}
```

- [ ] **Step 4: Wire the overlay onto the predicate**

In `UniverseOverlayView.swift`, replace the `bottomControls` guards that read `!mode.isDetailOpen && !mode.isChatOpen && !model.isUniverseEmpty` for the `PlanetInfoCard` and the bottom `CategoryRail`, and the `rightUniverseRail` condition, with `SpatialChrome.showsMapChrome(renderMode: model.renderMode, mode: mode, isUniverseEmpty: model.isUniverseEmpty)`. Keep the existing extra `!cameraRig.isTransitioning` on the right rail.

```swift
// bottomControls — info card + bottom category rail:
if SpatialChrome.showsMapChrome(renderMode: model.renderMode, mode: mode, isUniverseEmpty: model.isUniverseEmpty) {
    PlanetInfoCard(/* unchanged args */)
}
// ... SearchDock stays gated only on !mode.isDetailOpen ...
if SpatialChrome.showsMapChrome(renderMode: model.renderMode, mode: mode, isUniverseEmpty: model.isUniverseEmpty) {
    HStack(alignment: .center, spacing: 6) { CategoryRail { id in onCategorySelect(id) } }
}

// right rail (keep the transitioning guard):
if SpatialChrome.showsMapChrome(renderMode: model.renderMode, mode: mode, isUniverseEmpty: model.isUniverseEmpty) && !cameraRig.isTransitioning {
    rightUniverseRail
}
```

- [ ] **Step 5: Run tests + build to verify**

Run: `npm run ios:verify -- --run-tests --device-id <id>` → all green incl. new suite.
Run: `npm run ios:verify -- --full-test --device-id <id>` → build + UI smoke SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/SpatialChrome.swift ios-app/Tests/MyAIMapTests/SpatialChromeTests.swift ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift
git commit -m "feat(3d): hide map rail + info card in spatial mode"
```

---

### Task 2: Step-up back navigation (`UniverseMode.steppedBack`)

Tapping empty space in 3D should step up one level (tool → sun → overview), never jump straight to overview from a tool, and never trap. Add a pure parent-mode accessor and use it in the empty-tap handler.

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseMode.swift` (add extension at end)
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift` (`handleEmptySpaceTap` ~line 273)
- Create: `ios-app/Tests/MyAIMapTests/UniverseModeSteppedBackTests.swift`

**Interfaces:**
- Produces: `var UniverseMode.steppedBack: UniverseMode`

- [ ] **Step 1: Write the failing test**

```swift
// ios-app/Tests/MyAIMapTests/UniverseModeSteppedBackTests.swift
import Testing
@testable import MyAIMap

@Suite("UniverseMode.steppedBack — 3D step-up navigation")
struct UniverseModeSteppedBackTests {
    @Test func toolStepsToItsSun() {
        #expect(UniverseMode.toolSelected(.coding, "cursor").steppedBack == .branchFocus(.coding))
    }
    @Test func sunStepsToOverview() {
        #expect(UniverseMode.branchFocus(.coding).steppedBack == .overview)
    }
    @Test func overviewStaysOverview() {
        #expect(UniverseMode.overview.steppedBack == .overview)
    }
    @Test func detailStepsToToolSelected() {
        #expect(UniverseMode.detail(.design, "figma").steppedBack == .toolSelected(.design, "figma"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run ios:verify -- --run-tests --device-id <id>`
Expected: FAIL — "value of type 'UniverseMode' has no member 'steppedBack'".

- [ ] **Step 3: Write minimal implementation**

```swift
// Append to ios-app/Sources/MyAIMap/Universe/UniverseMode.swift
extension UniverseMode {
    /// Parent navigation state for tap-on-empty in 3D: tool → its sun →
    /// overview. Detail/chat dismissal is handled by their own paths; this
    /// covers the spatial step-up walk.
    var steppedBack: UniverseMode {
        switch self {
        case .overview, .branchFocus:
            return .overview
        case .toolSelected(let category, _):
            return .branchFocus(category)
        case .detail(let category, let toolID):
            return .toolSelected(category, toolID)
        case .chatOpen:
            return .overview
        }
    }
}
```

- [ ] **Step 4: Wire empty-tap to step up in 3D only**

In `UniverseMapView.handleEmptySpaceTap`, when in 3D and not in chat/detail, set the mode to `mode.steppedBack` instead of jumping to overview. Keep 2D behavior (`resetToOverview`) unchanged.

```swift
private func handleEmptySpaceTap() {
    dismissKeyboard()
    if mode.isChatOpen {
        restoreNavigationMode(animated: true)
    } else if mode.isDetailOpen {
        return
    } else if model.renderMode == .spatial3D, mode != .overview {
        BrandHaptics.fire(.light)
        withAnimation(BrandMotion.flow) { model.universeMode = mode.steppedBack }
    } else {
        resetToOverview()
    }
}
```

- [ ] **Step 5: Run tests + build**

Run: `npm run ios:verify -- --run-tests --device-id <id>` → green.
Run: `npm run ios:verify -- --full-test --device-id <id>` → SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/UniverseMode.swift ios-app/Tests/MyAIMapTests/UniverseModeSteppedBackTests.swift ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift
git commit -m "feat(3d): tap empty space steps up one level, never traps"
```

---

### Task 3: Overview reveal — only the centered sun speaks (`OverviewLabelFocus`)

In overview, every category label currently competes (up to 5 packed). The design wants silence: only the sun nearest screen centre shows a label.

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/OverviewLabelFocus.swift`
- Create: `ios-app/Tests/MyAIMapTests/OverviewLabelFocusTests.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift` (`overviewLabelPlacements` ~line 309)

**Interfaces:**
- Produces: `enum OverviewLabelFocus { static func centeredSunID(_ candidates: [(id: ToolCategoryId, point: CGPoint)], screenCenter: CGPoint) -> ToolCategoryId? }`

- [ ] **Step 1: Write the failing test**

```swift
// ios-app/Tests/MyAIMapTests/OverviewLabelFocusTests.swift
import Testing
import CoreGraphics
@testable import MyAIMap

@Suite("OverviewLabelFocus — only centered sun speaks")
struct OverviewLabelFocusTests {
    @Test func picksNearestToCenter() {
        let center = CGPoint(x: 200, y: 200)
        let candidates: [(id: ToolCategoryId, point: CGPoint)] = [
            (.coding, CGPoint(x: 210, y: 205)),
            (.design, CGPoint(x: 380, y: 90)),
        ]
        #expect(OverviewLabelFocus.centeredSunID(candidates, screenCenter: center) == .coding)
    }
    @Test func emptyReturnsNil() {
        #expect(OverviewLabelFocus.centeredSunID([], screenCenter: .zero) == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run ios:verify -- --run-tests --device-id <id>`
Expected: FAIL — "cannot find 'OverviewLabelFocus' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// ios-app/Sources/MyAIMap/Universe/OverviewLabelFocus.swift
import CoreGraphics

/// In overview only one sun speaks: the one nearest the screen centre
/// (locked design default). Everything else stays silent (principle 6).
enum OverviewLabelFocus {
    static func centeredSunID(
        _ candidates: [(id: ToolCategoryId, point: CGPoint)],
        screenCenter: CGPoint
    ) -> ToolCategoryId? {
        candidates.min(by: {
            hypot($0.point.x - screenCenter.x, $0.point.y - screenCenter.y)
                < hypot($1.point.x - screenCenter.x, $1.point.y - screenCenter.y)
        })?.id
    }
}
```

- [ ] **Step 4: Filter overview placements to the centered sun**

In `overviewLabelPlacements(in:)`, after building `packed`, compute the centered sun and return only its placement. Screen centre matches the existing label framing centre `CGPoint(x: size.width * 0.5, y: size.height * 0.40)`.

```swift
let center = CGPoint(x: size.width * 0.5, y: size.height * 0.40)
let centeredID = OverviewLabelFocus.centeredSunID(
    packed.compactMap { p in
        ToolCategoryId(rawValue: p.id).map { (id: $0, point: p.position) }
    },
    screenCenter: center
)
return packed.compactMap { placement -> PlanetLabelPlacement? in
    guard let id = ToolCategoryId(rawValue: placement.id),
          id == centeredID,
          var resolved = byID[id] else { return nil }
    resolved.position = placement.position
    return resolved
}
```

- [ ] **Step 5: Run tests + build**

Run: `npm run ios:verify -- --run-tests --device-id <id>` → green.
Run: `npm run ios:verify -- --full-test --device-id <id>` → SUCCEEDED. Inspect the `00…`/overview screenshot attachment in the `.xcresult` to confirm a single overview label.

- [ ] **Step 6: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/OverviewLabelFocus.swift ios-app/Tests/MyAIMapTests/OverviewLabelFocusTests.swift ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift
git commit -m "feat(3d): overview reveals only the centered sun label"
```

---

### Task 4: Category bodies become suns (emissive + scene light)

Make each category planet read as a sun: stronger emission and a real point/spot light per category so tool-planets are lit by their sun (principle: soft volumetric lighting; sets up Increment 2). This is a rendering change verified by build + smoke, not a unit test.

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/PlanetEntityFactory.swift` (`planetMaterial` ~line 229; add `makeSunLight`)
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseSceneController.swift` (attach a sun light per non-core planet where planets are built)

**Interfaces:**
- Consumes: existing `makePlanet(data:isSelected:visualizationStyle:reduceMotion:)`.
- Produces: `static func PlanetEntityFactory.makeSunLight(data: PlanetData) -> Entity`.

- [ ] **Step 1: Add the sun light factory**

```swift
// In PlanetEntityFactory (RealityKit). A soft point light tinted to the
// category, parented at the sun so its tool-planets are lit from their star.
static func makeSunLight(data: PlanetData) -> Entity {
    let light = PointLight()
    light.light.color = data.accentUIColor
    light.light.intensity = data.id == .core ? 9000 : 5200
    light.light.attenuationRadius = 9.5
    light.name = "sun-light:\(data.id.rawValue)"
    return light
}
```

- [ ] **Step 2: Strengthen sun emission**

In `planetMaterial`, raise non-core emissive intensity so suns glow as stars (keep core as-is). Change the non-core branch of `emissiveIntensity`:

```swift
material.emissiveIntensity = (data.id == .core ? 1.15 : isSelected ? 1.05 : 0.58) * visualizationStyle.glowBoost
```

- [ ] **Step 3: Attach a sun light to each non-core planet**

In `UniverseSceneController` where each planet entity is created and added to `planetRoot`, also add the light as a child of that planet entity (so it moves with the sun). Add only for non-core planets (core already has the founder halo + key/rim lights).

```swift
if planet.id != .core {
    entity.addChild(PlanetEntityFactory.makeSunLight(data: planet))
}
```

- [ ] **Step 4: Build + smoke**

Run: `npm run ios:verify -- --full-test --device-id <id>` → SUCCEEDED.
Inspect `.xcresult` screenshots: suns visibly glow and cast light on nearby planets; scene is not blown out. If over-bright, halve `intensity` values and re-run.

- [ ] **Step 5: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/PlanetEntityFactory.swift ios-app/Sources/MyAIMap/Universe/UniverseSceneController.swift
git commit -m "feat(3d): category planets become emissive suns that light their tools"
```

---

### Task 5: Obvious selected-body highlight

The focused sun or tool-planet must be unmistakably selected. The factory already scales/emphasizes when `isSelected`; tighten so the contrast between selected and silent is clear, and confirm the focused body is the only lit one (Task 3 covers labels; this covers the body).

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/PlanetEntityFactory.swift` (`makePlanet` selected scale ~line 26, `makeSatellite` selected emissive ~line 83)

**Interfaces:** none new (parameter tuning of existing factories).

- [ ] **Step 1: Increase selected emphasis on suns**

In `makePlanet`, widen the selected/unselected radius gap for non-core so a focused sun reads bigger:

```swift
radius = data.radius * visualizationStyle.categoryScale * (isSelected ? 1.28 : 0.80)
```

- [ ] **Step 2: Increase selected emphasis on tool-planets**

In `makeSatellite`, raise the selected emissive and halo so a selected planet pops against silent siblings:

```swift
material.emissiveIntensity = (isSelected ? 1.6 : 0.30) * visualizationStyle.glowBoost
// and the halo opacity line:
materials: [unlitGlow(color: category.glow.uiColor, opacity: isSelected ? 0.22 : 0.04)]
```

- [ ] **Step 3: Build + smoke**

Run: `npm run ios:verify -- --full-test --device-id <id>` → SUCCEEDED.
Inspect screenshots for `02-…`/`03-…` selected states: the selected body is clearly larger/brighter; unselected siblings are dim and silent.

- [ ] **Step 4: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/PlanetEntityFactory.swift
git commit -m "feat(3d): clearer selected-body emphasis vs silent siblings"
```

---

### Task 6: Soft-snap to neighbor sun while orbiting (`NeighborSnap`)

Highest-risk, last so it can be deferred without blocking the increment. While free-orbiting (panning) in sun focus, when the camera yaw rotates near a neighbor sun's bearing, snap focus to it. Pure bearing math, unit-tested; wired into the pan-end path.

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/NeighborSnap.swift`
- Create: `ios-app/Tests/MyAIMapTests/NeighborSnapTests.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift` (after a pan gesture ends in `branchFocus`)

**Interfaces:**
- Produces:
```swift
enum NeighborSnap {
    struct Sun { let id: ToolCategoryId; let position: SIMD3<Float> }
    static func snapTarget(currentFocus: ToolCategoryId, yaw: Float, suns: [Sun], thresholdRadians: Float) -> ToolCategoryId?
}
```

- [ ] **Step 1: Write the failing test**

```swift
// ios-app/Tests/MyAIMapTests/NeighborSnapTests.swift
import Testing
import simd
@testable import MyAIMap

@Suite("NeighborSnap — drift toward neighbor sun")
struct NeighborSnapTests {
    private let suns: [NeighborSnap.Sun] = [
        .init(id: .coding, position: SIMD3<Float>(0, 0, 6)),     // bearing ~ atan2(0,6)+0.24
        .init(id: .design, position: SIMD3<Float>(6, 0, 0)),     // bearing ~ atan2(6,0)+0.24
    ]

    @Test func snapsWhenYawNearNeighborBearing() {
        let designBearing = atan2(Float(6), Float(0.001)) + 0.24
        let result = NeighborSnap.snapTarget(currentFocus: .coding, yaw: designBearing, suns: suns, thresholdRadians: 0.3)
        #expect(result == .design)
    }

    @Test func noSnapWhenFarFromAnyNeighbor() {
        let result = NeighborSnap.snapTarget(currentFocus: .coding, yaw: 3.14, suns: suns, thresholdRadians: 0.3)
        #expect(result == nil)
    }

    @Test func neverSnapsToCurrentFocus() {
        let codingBearing = atan2(Float(0), Float(6) + 0.001) + 0.24
        let result = NeighborSnap.snapTarget(currentFocus: .coding, yaw: codingBearing, suns: suns, thresholdRadians: 0.3)
        #expect(result == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run ios:verify -- --run-tests --device-id <id>`
Expected: FAIL — "cannot find 'NeighborSnap' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// ios-app/Sources/MyAIMap/Universe/NeighborSnap.swift
import simd

/// While free-orbiting a focused sun, the rig's yaw rotates around the galaxy.
/// `focus(on:)` sets yaw to a sun's bearing `atan2(x, z+0.001) + 0.24`, so when
/// yaw drifts within `thresholdRadians` of a *different* sun's bearing, that
/// neighbor takes focus (soft snap). Pure: returns the sun to snap to, or nil.
enum NeighborSnap {
    struct Sun: Equatable {
        let id: ToolCategoryId
        let position: SIMD3<Float>
    }

    static func snapTarget(
        currentFocus: ToolCategoryId,
        yaw: Float,
        suns: [Sun],
        thresholdRadians: Float
    ) -> ToolCategoryId? {
        func bearing(_ p: SIMD3<Float>) -> Float { atan2(p.x, p.z + 0.001) + 0.24 }
        func angleDelta(_ a: Float, _ b: Float) -> Float {
            let twoPi = Float.pi * 2
            let d = abs(a - b).truncatingRemainder(dividingBy: twoPi)
            return min(d, twoPi - d)
        }
        var best: (id: ToolCategoryId, delta: Float)?
        for sun in suns where sun.id != currentFocus {
            let delta = angleDelta(yaw, bearing(sun.position))
            if delta < thresholdRadians, delta < (best?.delta ?? .greatestFiniteMagnitude) {
                best = (sun.id, delta)
            }
        }
        return best?.id
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run ios:verify -- --run-tests --device-id <id>`
Expected: PASS (new suite green).

- [ ] **Step 5: Wire snap into the pan-end path (3D, sun focus only)**

In `UniverseMapView`, where the 3D pan/drag gesture ends and the rig settles (the same place `cameraRig.finishPan` is invoked from the reality view's gesture wiring), after settling check for a snap and, if found, focus that sun:

```swift
private func maybeSnapToNeighborSun() {
    guard model.renderMode == .spatial3D, case .branchFocus(let current) = mode else { return }
    let suns = planets.filter { $0.id != .core }.map {
        NeighborSnap.Sun(id: $0.id, position: $0.position3D)
    }
    if let snapped = NeighborSnap.snapTarget(currentFocus: current, yaw: cameraRig.yaw, suns: suns, thresholdRadians: 0.28),
       snapped != current {
        BrandHaptics.fire(.light)
        selectCategory(snapped)
    }
}
```

Call `maybeSnapToNeighborSun()` from the reality view's drag `.onEnded` handler (pass it down as an `onOrbitSettled` closure to `UniverseRealityView`, mirroring the existing `onEmptyTap` wiring).

- [ ] **Step 6: Build + smoke**

Run: `npm run ios:verify -- --full-test --device-id <id>` → SUCCEEDED. Manually confirm on the booted sim: focus a sun, drag to orbit toward a neighbor — focus hands off with a light haptic; small drags do not snap.

- [ ] **Step 7: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/NeighborSnap.swift ios-app/Tests/MyAIMapTests/NeighborSnapTests.swift ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift ios-app/Sources/MyAIMap/Universe/UniverseRealityView.swift
git commit -m "feat(3d): soft-snap focus to neighbor sun while orbiting"
```

---

## Self-Review

**Spec coverage:**
- Object model (suns + tool-planets) → Tasks 4, 5. Overview hides tool-planets → already true (`mode.showsSatellites == false` in `.overview`); no task needed, noted here.
- Hybrid nav: tap-to-fly → existing `CameraRigController.focus`; free-orbit → existing `pan`; step-up → Task 2; soft-snap → Task 6.
- Reveal & chrome cut → Task 1 (chrome) + Task 3 (overview label).
- Selection highlight → Task 5.
- Scope (2D untouched, `.spatial3D` only) → enforced in Tasks 1, 2; Tasks 4–6 are 3D-scene only.
- Success criteria map to Tasks 1–6 + existing tap-to-fly.

**Placeholder scan:** none — every step has concrete code/commands.

**Type consistency:** `SpatialChrome.showsMapChrome`, `UniverseMode.steppedBack`, `OverviewLabelFocus.centeredSunID`, `NeighborSnap.Sun`/`snapTarget`, `PlanetEntityFactory.makeSunLight` are each defined once and consumed with matching signatures. `ToolCategoryId` raw-value round-trip matches existing overlay usage. `cameraRig.yaw` is an existing `private(set)` readable property.

**Deferral note:** Task 6 (soft-snap) is isolated and last; if it feels unphysical on-device it can be dropped from Increment 1 without affecting Tasks 1–5.
