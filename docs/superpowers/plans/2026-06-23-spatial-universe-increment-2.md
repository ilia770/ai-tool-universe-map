# Spatial Universe — Increment 2 (Atmosphere & Material) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the 3D galaxy feel expensive — focus-aware volumetric lighting, a single minimal glass reveal card for the selected tool, deeper space, premium materials. `.spatial3D` only; 2D untouched.

**Architecture:** Continue Increment 1's pattern — pure unit-tested helpers for the rules (light intensity per mode, reveal-card visibility), wired into the existing `UniverseSceneController` / `UniverseOverlayView`; RealityKit material/skybox tuning verified by build + the sim-screenshot method.

**Tech Stack:** Swift 6, SwiftUI, RealityKit, simd, Swift Testing. Verify via `npm run ios:verify`.

## Global Constraints

- Only `.spatial3D` changes; `renderMode == .graph2D` stays behaviorally + visually identical.
- No data-model changes, no new navigation, no new product features. The reveal card routes to the EXISTING detail path (the overlay's `onDetails` closure).
- New shared rules are pure `enum`s, unit-tested with Swift Testing.
- Honor `accessibilityReduceMotion`. Match existing file style.
- Simulator id: `EAC2C682-5C38-44DB-8FEC-034E296E8EEA` (or a current booted id from `xcrun simctl list devices available | grep Booted`).
- Unit run: `npm run ios:verify -- --run-tests --device-id <id>`. Build+smoke: `--full-test`.
- 3D visual check (RealityKit renders black for the first seconds in sim): set `universe.renderMode.v1=spatial3D` in the app-container plist (`xcrun simctl get_app_container <udid> com.ilyatur.myaimap data` → `Library/Preferences/com.ilyatur.myaimap.plist`), `xcrun simctl spawn <udid> killall -9 cfprefsd`, relaunch, wait several seconds, then `xcrun simctl io <udid> screenshot`.
- Conventional commits; commit after each task; do not push.

---

### Task 1: Focus-aware sun light intensity (`SunLightIntensity`)

Sun `PointLight`s currently emit full 5200 in every mode, so dimmed neighbor suns still cast full light and all 8 burn in overview. Scale each sun's light to the mode's focus hierarchy via a pure helper.

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/SunLightIntensity.swift`
- Create: `ios-app/Tests/MyAIMapTests/SunLightIntensityTests.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/PlanetEntityFactory.swift` (`makeSunLight` — add `intensity:` param)
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseSceneController.swift` (the `addChild(makeSunLight(...))` call site, ~line 124)

**Interfaces:**
- Produces: `enum SunLightIntensity { static func intensity(for mode: UniverseMode, isFocused: Bool) -> Float }`
- Changes: `PlanetEntityFactory.makeSunLight(data: PlanetData, intensity: Float) -> Entity`

- [ ] **Step 1: Write the failing test**

```swift
// ios-app/Tests/MyAIMapTests/SunLightIntensityTests.swift
import Testing
@testable import MyAIMap

@Suite("SunLightIntensity — focus-aware sun lighting")
struct SunLightIntensityTests {
    @Test func focusedSunIsBrightestInBranchFocus() {
        let focused = SunLightIntensity.intensity(for: .branchFocus(.coding), isFocused: true)
        let other = SunLightIntensity.intensity(for: .branchFocus(.coding), isFocused: false)
        #expect(focused > other)
    }

    @Test func overviewIsSoftAndUniform() {
        let a = SunLightIntensity.intensity(for: .overview, isFocused: true)
        let b = SunLightIntensity.intensity(for: .overview, isFocused: false)
        #expect(a == b)
        #expect(a < SunLightIntensity.intensity(for: .branchFocus(.coding), isFocused: true))
    }

    @Test func detailRecedesNonFocused() {
        let other = SunLightIntensity.intensity(for: .detail(.coding, "x"), isFocused: false)
        #expect(other < SunLightIntensity.intensity(for: .branchFocus(.coding), isFocused: false))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run ios:verify -- --run-tests --device-id <id>`
Expected: FAIL — "cannot find 'SunLightIntensity' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// ios-app/Sources/MyAIMap/Universe/SunLightIntensity.swift
import Foundation

/// Per-mode brightness for a category sun's PointLight, so lighting follows the
/// same focus hierarchy as mesh opacity: the focused system is lit, the rest
/// recede, and overview glows softly without blowing out (8 suns at once).
enum SunLightIntensity {
    static func intensity(for mode: UniverseMode, isFocused: Bool) -> Float {
        switch mode {
        case .overview:
            return 2200
        case .branchFocus, .toolSelected:
            return isFocused ? 5200 : 1400
        case .detail:
            return isFocused ? 3000 : 500
        case .chatOpen:
            return isFocused ? 2600 : 1000
        }
    }
}
```

- [ ] **Step 4: Thread intensity through the factory + call site**

In `PlanetEntityFactory.makeSunLight`, replace the hard-coded `5200` with an `intensity` parameter:

```swift
static func makeSunLight(data: PlanetData, intensity: Float) -> Entity {
    let light = PointLight()
    light.light.color = data.accentUIColor
    light.light.intensity = intensity
    light.light.attenuationRadius = 9.5
    light.name = "sun-light:\(data.id.rawValue)"
    return light
}
```

In `UniverseSceneController` at the sun-light call site (the `if planet.id != .core { entity.addChild(PlanetEntityFactory.makeSunLight(data: planet)) }`), pass the mode-scaled intensity (the loop already has `let isSelected = mode.isPrimaryPlanet(planet.id)`):

```swift
if planet.id != .core {
    entity.addChild(PlanetEntityFactory.makeSunLight(
        data: planet,
        intensity: SunLightIntensity.intensity(for: mode, isFocused: isSelected)
    ))
}
```

- [ ] **Step 5: Run tests + build/smoke**

Run: `npm run ios:verify -- --run-tests --device-id <id>` → green incl. new suite.
Run: `npm run ios:verify -- --full-test --device-id <id>` → SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/SunLightIntensity.swift ios-app/Tests/MyAIMapTests/SunLightIntensityTests.swift ios-app/Sources/MyAIMap/Universe/PlanetEntityFactory.swift ios-app/Sources/MyAIMap/Universe/UniverseSceneController.swift
git commit -m "feat(3d): focus-aware sun light intensity per mode"
```

---

### Task 2: Selected-tool glass reveal card (`SpatialReveal` + `SpatialRevealCard`)

Principle 4: only the selected planet reveals detail. In 3D, focusing a tool currently shows no inline info. Add one minimal floating glass card for the focused tool, shown only in `.toolSelected` (3D), routing to the existing detail path.

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/SpatialReveal.swift`
- Create: `ios-app/Tests/MyAIMapTests/SpatialRevealTests.swift`
- Create: `ios-app/Sources/MyAIMap/Universe/SpatialRevealCard.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift` (`bottomControls`)

**Interfaces:**
- Produces: `enum SpatialReveal { static func showsToolCard(renderMode: UniverseRenderMode, mode: UniverseMode) -> Bool }`
- Produces: `struct SpatialRevealCard: View` with `init(toolName: String, categoryName: String, summary: String, tint: Color, onOpen: @escaping () -> Void)`.

- [ ] **Step 1: Write the failing test**

```swift
// ios-app/Tests/MyAIMapTests/SpatialRevealTests.swift
import Testing
@testable import MyAIMap

@Suite("SpatialReveal — selected-tool card visibility")
struct SpatialRevealTests {
    @Test func showsOnlyForToolSelectedIn3D() {
        #expect(SpatialReveal.showsToolCard(renderMode: .spatial3D, mode: .toolSelected(.coding, "cursor")) == true)
    }
    @Test func hiddenInOverviewAndSunFocus() {
        #expect(SpatialReveal.showsToolCard(renderMode: .spatial3D, mode: .overview) == false)
        #expect(SpatialReveal.showsToolCard(renderMode: .spatial3D, mode: .branchFocus(.coding)) == false)
    }
    @Test func hiddenIn2D() {
        #expect(SpatialReveal.showsToolCard(renderMode: .graph2D, mode: .toolSelected(.coding, "cursor")) == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run ios:verify -- --run-tests --device-id <id>`
Expected: FAIL — "cannot find 'SpatialReveal' in scope".

- [ ] **Step 3: Write the predicate**

```swift
// ios-app/Sources/MyAIMap/Universe/SpatialReveal.swift
import Foundation

/// The single inline reveal in 3D: a glass card for the focused tool-planet.
/// Shown only when a tool is selected in spatial mode (principle 4 —
/// only the selected planet reveals detail). Overview/sun-focus stay bare.
enum SpatialReveal {
    static func showsToolCard(renderMode: UniverseRenderMode, mode: UniverseMode) -> Bool {
        guard renderMode == .spatial3D else { return false }
        if case .toolSelected = mode { return true }
        return false
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run ios:verify -- --run-tests --device-id <id>`
Expected: PASS.

- [ ] **Step 5: Build the glass card view**

```swift
// ios-app/Sources/MyAIMap/Universe/SpatialRevealCard.swift
import SwiftUI

/// Minimal floating glass reveal for the focused tool-planet (principle:
/// minimal typography, large negative space, glass surface). One primary
/// action routes to the full detail.
struct SpatialRevealCard: View {
    let toolName: String
    let categoryName: String
    let summary: String
    let tint: Color
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                Text(categoryName.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(tint.opacity(0.9))
                Text(toolName)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(summary)
                    .font(.system(.footnote))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text("Open")
                        .font(.system(.subheadline, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), tint: tint.opacity(0.4))
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98, haptic: nil, pressedOpacity: 0.92))
        .frame(maxWidth: 340)
        .accessibilityLabel("Open \(toolName) detail")
    }
}
```

- [ ] **Step 6: Mount the card in the overlay (3D, tool-selected only)**

In `UniverseOverlayView.bottomControls`, ABOVE the `SearchDock`, add the reveal card gated by the predicate. Use the existing `selectedTool` / `selectedPlanet` / `onDetails`, and the tool's summary/category. The summary comes from the tool's knowledge (`ToolKnowledgeBook.knowledge(for: selectedTool).useCase`) or `selectedTool.summary`; category short name from `UniverseSeed.category(selectedTool.category).shortName`.

```swift
if SpatialReveal.showsToolCard(renderMode: model.renderMode, mode: mode) {
    SpatialRevealCard(
        toolName: selectedTool.name,
        categoryName: UniverseSeed.category(selectedTool.category).shortName,
        summary: selectedTool.summary,
        tint: selectedPlanet.swiftUIColor,
        onOpen: onDetails
    )
    .transition(.opacity.combined(with: .move(edge: .bottom)))
}
```

- [ ] **Step 7: Run tests + build/smoke + 3D screenshot**

Run: `npm run ios:verify -- --run-tests --device-id <id>` → green.
Run: `npm run ios:verify -- --full-test --device-id <id>` → SUCCEEDED.
Then drive the sim into 3D (see Global Constraints), tap a tool-planet, screenshot: a glass card with category/name/summary/Open appears; none in overview/sun-focus.

- [ ] **Step 8: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/SpatialReveal.swift ios-app/Tests/MyAIMapTests/SpatialRevealTests.swift ios-app/Sources/MyAIMap/Universe/SpatialRevealCard.swift ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift
git commit -m "feat(3d): minimal glass reveal card for selected tool-planet"
```

---

### Task 3: Deeper space (skybox black + restrained star/dust depth)

Tune the background so the galaxy sits in deep space with subtle parallax, not on a flat panel. Rendering tuning verified by screenshot.

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/Entities/GalaxyDustGeometry.swift` (`opacity` — lower for restraint)
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseSceneController.swift` (star count if a loop count is present; deepen background clear/skybox tint)

**Interfaces:** none new — parameter tuning.

- [ ] **Step 1: Lower dust opacity for restraint**

In `GalaxyDustGeometry.swift`, reduce the static `opacity` by ~30% (e.g. if `0.06`, set `0.04`) so the haze reads as faint depth, not a wash. Read the current value first and apply a single proportional reduction.

- [ ] **Step 2: Deepen the background / reduce star wash**

In `UniverseSceneController`, if stars are added in a `for index in 0..<N` loop, reduce `N` by ~25% for restraint. Ensure the scene/background base is true deep black (the `RealityView` / scene background should not be a bright gradient). Make only these tuning changes; do not restructure.

- [ ] **Step 3: Build + 3D screenshot**

Run: `npm run ios:verify -- --full-test --device-id <id>` → SUCCEEDED.
Drive sim into 3D, screenshot overview: background reads as deep space with subtle star depth; suns/planets pop against it; not a flat gradient, not a busy starfield. If still washed, lower dust opacity / star count further and re-run.

- [ ] **Step 4: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/Entities/GalaxyDustGeometry.swift ios-app/Sources/MyAIMap/Universe/UniverseSceneController.swift
git commit -m "feat(3d): deeper space — restrained star/dust depth on true black"
```

---

### Task 4: Premium planet material

Tune planet/sun PBR so bodies read as glass-and-light. Rendering tuning verified by screenshot.

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/PlanetEntityFactory.swift` (`planetMaterial`)

**Interfaces:** none new — parameter tuning.

- [ ] **Step 1: Tune `planetMaterial`**

In `planetMaterial`, increase glassiness for non-core bodies: raise `clearcoat` for unselected from `0.28` toward `0.45`, lower `clearcoatRoughness` from `0.24` toward `0.14`, and keep emission tasteful (do not exceed the Increment-1 values that were verified as not blown out). Make only these material-parameter edits; do not change geometry or selection logic.

- [ ] **Step 2: Build + 3D screenshot**

Run: `npm run ios:verify -- --full-test --device-id <id>` → SUCCEEDED.
Drive sim into 3D, screenshot a focused system: planets read as premium glass-and-light with soft specular, not flat matte. Adjust within range if needed and re-run.

- [ ] **Step 3: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/PlanetEntityFactory.swift
git commit -m "feat(3d): premium glass-and-light planet material"
```

---

## Self-Review

**Spec coverage:**
- Calm volumetric lighting (fixes Inc1 open items) → Task 1.
- Selected-only glass reveal (principle 4) → Task 2.
- Deeper space → Task 3.
- Premium material → Task 4.
- Scope (2D untouched, `.spatial3D` only, reveal routes to existing detail) → enforced in every task.

**Placeholder scan:** Tasks 1–2 carry full code. Tasks 3–4 are parameter-tuning tasks that direct the implementer to read the current value and apply a bounded proportional change with a screenshot gate — concrete ranges given, no "add appropriate X".

**Type consistency:** `SunLightIntensity.intensity(for:isFocused:)`, `PlanetEntityFactory.makeSunLight(data:intensity:)`, `SpatialReveal.showsToolCard(renderMode:mode:)`, `SpatialRevealCard(toolName:categoryName:summary:tint:onOpen:)` are each defined once and consumed with matching signatures. `selectedTool.summary`, `UniverseSeed.category(_:).shortName`, `selectedPlanet.swiftUIColor`, and `onDetails` are existing symbols used elsewhere in `UniverseOverlayView`.

**Deferral note:** Tasks 3–4 are visual taste passes; the sim renders 3D black for a few seconds, so screenshots need the populated-universe + plist + delay method. Final values are the user's eyeball call on a real device.
