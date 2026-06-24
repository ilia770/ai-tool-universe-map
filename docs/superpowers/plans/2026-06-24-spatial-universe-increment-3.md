# Spatial Universe — Increment 3 (Motion & Feel) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the 3D motion feel physical and expensive — the camera fly-to lands on an expo-out curve, and the selected-tool reveal card springs in with subtle depth. `.spatial3D` only; 2D untouched.

**Architecture:** A pure `CameraEasing` constant feeds the existing RealityKit camera move; the existing `BrandMotion.reveal` spring + `parallaxTilt` modifier drive the Increment-2 reveal card. No new surfaces.

**Tech Stack:** Swift 6, SwiftUI, RealityKit, simd, Swift Testing. Verify via `npm run ios:verify`.

## Global Constraints

- Only `.spatial3D` changes; `renderMode == .graph2D` stays behaviorally + visually identical.
- No data-model changes, no new product features, no new navigation. Do NOT restyle the shared detail sheet (`RootSheet`/`ToolDetailSection`) — motion only.
- Honor `accessibilityReduceMotion` via the existing `BrandMotion.resolved` / `brandAnimation` / `parallaxTilt` reduce-motion paths.
- Simulator id: `EAC2C682-5C38-44DB-8FEC-034E296E8EEA` (or a current booted id).
- Unit run: `npm run ios:verify -- --run-tests --device-id <id>`. Build+smoke: `--full-test`.
- 3D visual check (RealityKit renders black for the first seconds in sim): set `universe.renderMode.v1=spatial3D` in the app-container plist (`xcrun simctl get_app_container <udid> com.ilyatur.myaimap data` → `Library/Preferences/com.ilyatur.myaimap.plist`), `xcrun simctl spawn <udid> killall -9 cfprefsd`, relaunch, wait ~6s, screenshot.
- Conventional commits; commit after each task; do not push.

---

### Task 1: Premium camera fly easing (`CameraEasing`)

The fly-to a sun/tool/detail currently lands on RealityKit `.easeInOut` — mechanical. Replace with the web build's expo-out curve `cubic-bezier(0.16, 1, 0.3, 1)` (the "expensive" decelerate). Keep the 0.15s anticipation pullback as `.easeOut`.

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/CameraEasing.swift`
- Create: `ios-app/Tests/MyAIMapTests/CameraEasingTests.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/CameraRigController.swift` (the landing `camera.move(... timingFunction: .easeInOut)`, ~line 284)

**Interfaces:**
- Produces: `enum CameraEasing { static let flyControlPoint1: SIMD2<Float>; static let flyControlPoint2: SIMD2<Float>; static var fly: AnimationTimingFunction }`

- [ ] **Step 1: Write the failing test**

```swift
// ios-app/Tests/MyAIMapTests/CameraEasingTests.swift
import Testing
import simd
@testable import MyAIMap

@Suite("CameraEasing — premium fly curve")
struct CameraEasingTests {
    @Test func flyMatchesWebExpoOutCurve() {
        // Web parity: cubic-bezier(0.16, 1, 0.3, 1) — expo-out decelerate.
        #expect(CameraEasing.flyControlPoint1 == SIMD2<Float>(0.16, 1.0))
        #expect(CameraEasing.flyControlPoint2 == SIMD2<Float>(0.30, 1.0))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run ios:verify -- --run-tests --device-id <id>`
Expected: FAIL — "cannot find 'CameraEasing' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// ios-app/Sources/MyAIMap/Universe/CameraEasing.swift
import RealityKit
import simd

/// Premium camera fly-to curve: an expo-out decelerate that reads as physical
/// and expensive instead of the mechanical `.easeInOut`. Mirrors the web
/// build's `cubic-bezier(0.16, 1, 0.3, 1)` (same curve as `BrandMotion.entry`).
enum CameraEasing {
    static let flyControlPoint1 = SIMD2<Float>(0.16, 1.0)
    static let flyControlPoint2 = SIMD2<Float>(0.30, 1.0)

    static var fly: AnimationTimingFunction {
        .cubicBezier(controlPoint1: flyControlPoint1, controlPoint2: flyControlPoint2)
    }
}
```

NOTE: confirm `AnimationTimingFunction.cubicBezier(controlPoint1:controlPoint2:)` compiles. If that exact API is unavailable in this RealityKit version, fall back to `static var fly: AnimationTimingFunction { .easeOut }` (still a decelerate-into-place, better than `.easeInOut`) and keep the two control-point constants + their test so the intent is recorded.

- [ ] **Step 4: Use it for the landing move**

In `CameraRigController.applyCamera(...)`, change the landing move's `timingFunction: .easeInOut` (the second `camera?.move(to: landingTransform, ...)`, ~line 284) to `timingFunction: CameraEasing.fly`. Leave the 0.15s pullback move (`timingFunction: .easeOut`, ~line 276) unchanged.

- [ ] **Step 5: Run tests + build/smoke**

Run: `npm run ios:verify -- --run-tests --device-id <id>` → green incl. new suite.
Run: `npm run ios:verify -- --full-test --device-id <id>` → SUCCEEDED.
Then drive the sim into 3D and tap a sun: the camera should decelerate smoothly into frame (expo-out), not ease symmetrically.

- [ ] **Step 6: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/CameraEasing.swift ios-app/Tests/MyAIMapTests/CameraEasingTests.swift ios-app/Sources/MyAIMap/Universe/CameraRigController.swift
git commit -m "feat(3d): premium expo-out camera fly easing"
```

---

### Task 2: Spring-driven reveal with parallax depth

The Increment-2 reveal card currently appears via a plain transition. Drive it with the existing `BrandMotion.reveal` spring and add the existing `parallaxTilt` depth so the one piece of inline 3D UI feels alive. Visual; verified by build + smoke + screenshot.

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift` (the `SpatialRevealCard` mount in `bottomControls`, ~line 550)

**Interfaces:** none new — applies existing `BrandMotion.reveal`, `brandAnimation(_:value:)`, and `parallaxTilt(maxOffset:)`.

- [ ] **Step 1: Apply spring + parallax to the reveal card**

At the `SpatialRevealCard(...)` mount, keep the existing `.transition(.opacity.combined(with: .move(edge: .bottom)))`, add a subtle parallax tilt, and drive the appearance with the reveal spring keyed on the selected tool. Concretely:

```swift
if SpatialReveal.showsToolCard(renderMode: model.renderMode, mode: mode) {
    SpatialRevealCard(
        toolName: selectedTool.name,
        categoryName: UniverseSeed.category(selectedTool.category).shortName,
        summary: selectedTool.summary,
        tint: selectedPlanet.swiftUIColor,
        onOpen: onDetails
    )
    .parallaxTilt(maxOffset: 6)
    .transition(.opacity.combined(with: .move(edge: .bottom)))
}
```

and add a `brandAnimation` for the reveal spring on the enclosing `bottomControls` content keyed to the selected tool id, alongside any existing `brandAnimation` calls there:

```swift
.brandAnimation(BrandMotion.reveal, value: mode.selectedToolID)
```

(If `bottomControls` already chains `.brandAnimation` modifiers, add this one in the same chain. `mode.selectedToolID` is an existing `String?` accessor on `UniverseMode`.)

- [ ] **Step 2: Build + smoke**

Run: `npm run ios:verify -- --full-test --device-id <id>` → SUCCEEDED (2D smoke unaffected — the card is 3D-gated).

- [ ] **Step 3: 3D screenshot check**

Drive the sim into 3D, tap a tool-planet: the card should spring up (not flat-pop) with a faint parallax tilt; tapping empty / selecting another tool re-animates smoothly. Reduce Motion should collapse it.

- [ ] **Step 4: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift
git commit -m "feat(3d): spring + parallax on the selected-tool reveal card"
```

---

## Self-Review

**Spec coverage:**
- Premium camera motion → Task 1.
- Spring-driven reveal → Task 2.
- Scope (2D untouched, `.spatial3D` only, no shared-sheet restyle) → enforced; Task 1 touches only the camera landing curve, Task 2 only the 3D-gated reveal card.

**Placeholder scan:** Task 1 carries full code + an explicit fallback for the RealityKit API risk. Task 2 is a bounded view-modifier change with the exact snippet.

**Type consistency:** `CameraEasing.fly` / `.flyControlPoint1` / `.flyControlPoint2` defined once, consumed once (the camera move). `parallaxTilt(maxOffset:)`, `brandAnimation(_:value:)`, `BrandMotion.reveal`, `mode.selectedToolID`, `SpatialReveal.showsToolCard`, and the `SpatialRevealCard` init are all existing symbols.

**Risk note:** Task 1's `AnimationTimingFunction.cubicBezier` API is the one uncertainty; the step carries a concrete `.easeOut` fallback that preserves the decelerate intent. Final motion feel is a real-device taste call — recommend device-testing Increments 1–3 before further polish.
