# iOS Viz Overhaul (Overlay-Native Universe) + App-Quality Fixes — TDD Plan

**Part of:** `2026-06-16 product-v2` · **Branch:** `feat/product-v2` · **Workspace:** `/tmp/wt-ios`
**Design:** `docs/superpowers/specs/2026-06-16-ios-viz-overhaul-design.md` (Direction A — Overlay-Native Universe, approved)
**Research:** `docs/superpowers/specs/2026-06-16-ios-viz-research/*.md` (6 lenses + SYNTHESIS)

## Goal

Replace the broken world-space 3D information graph (meter-sized extruded text, world-thickness box
lines, dark untessellated orbs that snap) with a **screen-space SwiftUI/Canvas overlay** drawn over a
RealityKit ambient backdrop. The overlay owns all legibility: glass-pill badges, glowing orb sprites,
anti-aliased connection edges, and an overview→pocket declutter rule. Add a real `VisualizationStyle`
switcher over finalist layouts A/K/N/O, and fix the shipped app-quality bugs (chat scroll, composer
persistence, black cold-launch, dead buttons, missing "+" Add-Tool FAB).

## Architecture

Two cooperating layers (per design §Architecture):

1. **RealityKit backdrop (ambient only):** `StarFieldEntity`, `GalaxyDustEntity`, `SkyboxEntity`, subtle
   parallax/drift. No tool text / lines / orbs in world space. Reuse the existing ambient entities; remove
   the world-space label/link/orb construction from `UniverseView`.
2. **Screen-space overlay (SwiftUI + `Canvas`):** `UniverseProjection` maps each node's 3D layout position
   (`UniverseLayout` math) + camera state → screen point + depth scale + parallax offset. `OrbLayer` draws
   glowing discs, `ConnectionCanvas` draws AA edges, `NodeBadge` draws glass-pill labels. A `DeclutterRule`
   decides which badges show. `UniverseMotion` drives frame-rate-independent easing, gated on Reduce Motion.

The overlay is mounted over the `RealityView` inside `UniverseScreen`, synced to the camera each frame via
`TimelineView`. Camera state is read from `CameraController` (pure `nonisolated` math already exists:
`orbitAdjusted`, `lookRotation`, `clampedDistance`, `dollyDistance`).

## Tech Stack

- Swift 6.0 (`SWIFT_VERSION: "6.0"` in `project.yml`), iOS deployment target 18.0.
- SwiftUI (`Canvas`, `TimelineView`, `ScrollViewReader`, `@Observable`, `@ScaledMetric`), RealityKit (backdrop only), simd.
- Test framework: **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`, `#require`) — NOT XCTest. `@testable import MyAIMap`.
- Existing reusable kit: `BrandMotion`, `BrandColor`, `BrandHaptics`, `PressableButtonStyle`/`BouncyIconButtonStyle`, `liquidGlass(in:tint:strokeStrength:)`, `ShimmerLoader`/`ProgressOrb`, `InteractionTokens`.
- Build via XcodeGen + xcodebuild.

## CRITICAL CONSTRAINTS (state and honor throughout)

- **Swift 6.0 compat (CI uses Xcode 16.4).** Do NOT use isolated-conformance syntax (e.g. `struct X: @MainActor Identifiable`). Keep all data/projection models **plain** value types (`struct`, `Sendable`, `Equatable`) with no actor isolation on the type, so conformances stay nonisolated. Pure math types must be `nonisolated`/free of `@MainActor`.
- **Honor Reduce Motion.** Every animation routes through `BrandMotion.resolved(_:reduceMotion:)` or `View.brandAnimation(_:value:)`; `UniverseMotion` takes an explicit `reduceMotion` flag and collapses to instant. Read `@Environment(\.accessibilityReduceMotion)` in views.
- **60fps.** Overlay redraw via `TimelineView(.animation)`; projection is pure arithmetic over ≤49 nodes + ~150 edges. No per-frame allocation of materials/meshes.
- **Liquid glass** for badges/FAB via existing `liquidGlass` modifier (iOS 26 native + fallback already handled).
- **No web/vite changes.** `src/playground/variants/*.tsx` are read-only reference for layout math only.
- **Plain models, no `ObservableObject`.** State objects stay `@MainActor @Observable final class`; new pure types are framework-free.

## Build & Test Gate (run on every task; `<SIM>` filled at execution)

```
cd /tmp/wt-ios/ios-app && xcodegen generate && \
  xcodebuild build-for-testing -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'id=<SIM>' -derivedDataPath build CODE_SIGNING_ALLOWED=NO
cd /tmp/wt-ios/ios-app && xcodebuild test-without-building -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'id=<SIM>' -derivedDataPath build CODE_SIGNING_ALLOWED=NO
```

New source files go under `Sources/MyAIMap/...`; new test files under `Tests/MyAIMapTests/`. XcodeGen
globs both folders (`project.yml` targets `Sources` and `Tests/MyAIMapTests`), so no manual project edits —
just re-run `xcodegen generate`.

---

# TASKS (ordered: pure units → views → RealityKit→overlay swap → switcher → bug fixes)

---

## Task 1 — `UniverseProjection` (pure projection math)

**Files**
- Create: `Sources/MyAIMap/Universe/Overlay/UniverseProjection.swift`
- Test: `Tests/MyAIMapTests/UniverseProjectionTests.swift`

**Steps**
1. Write failing test `UniverseProjectionTests.swift`:
   ```swift
   import Testing
   import simd
   @testable import MyAIMap

   @Suite("UniverseProjection")
   struct UniverseProjectionTests {
       // Camera looking down -Z from (0,0,20) at origin, 60° vfov, 390x844 portrait.
       private func cam() -> UniverseProjection.Camera {
           UniverseProjection.Camera(
               eye: SIMD3<Float>(0, 0, 20),
               target: .zero,
               up: SIMD3<Float>(0, 1, 0),
               verticalFOV: .pi / 3,
               viewport: CGSize(width: 390, height: 844)
           )
       }

       @Test func nodeAtTargetProjectsToScreenCenter() {
           let p = UniverseProjection.project(.zero, camera: cam())
           let r = try! #require(p)
           #expect(abs(r.point.x - 195) < 0.5)
           #expect(abs(r.point.y - 422) < 0.5)
           #expect(r.depthScale > 0)
       }

       @Test func nearerNodeHasLargerDepthScale() {
           let near = UniverseProjection.project(SIMD3<Float>(0, 0, 5), camera: cam())!
           let far = UniverseProjection.project(SIMD3<Float>(0, 0, -5), camera: cam())!
           #expect(near.depthScale > far.depthScale)
       }

       @Test func behindCameraReturnsNil() {
           #expect(UniverseProjection.project(SIMD3<Float>(0, 0, 25), camera: cam()) == nil)
       }

       @Test func parallaxOffsetGrowsWithDepth() {
           let p = UniverseProjection.project(SIMD3<Float>(2, 0, -8), camera: cam())!
           #expect(p.parallax.width != 0)
       }
   }
   ```
2. Run the gate → fails to compile (type missing).
3. Minimal impl `UniverseProjection.swift` (plain, `nonisolated`, no RealityKit):
   ```swift
   import CoreGraphics
   import simd

   /// Pure camera→screen projection for the overlay. No RealityKit / SwiftUI.
   enum UniverseProjection {
       struct Camera: Sendable, Equatable {
           var eye: SIMD3<Float>
           var target: SIMD3<Float>
           var up: SIMD3<Float>
           var verticalFOV: Float          // radians
           var viewport: CGSize
       }

       struct Projected: Sendable, Equatable {
           var point: CGPoint              // screen-space px
           var depthScale: Float           // 1.0 at reference depth; >1 closer, <1 farther
           var parallax: CGSize            // additive screen offset from depth
       }

       /// Reference distance at which depthScale == 1 (mid-scene).
       static let referenceDistance: Float = 18

       static func project(_ world: SIMD3<Float>, camera c: Camera) -> Projected? {
           // View basis (right, up, forward) — matches CameraController.lookRotation convention.
           let forward = simd_normalize(c.target - c.eye)
           let right = simd_normalize(simd_cross(forward, c.up))
           let trueUp = simd_cross(right, forward)
           let rel = world - c.eye
           let z = simd_dot(rel, forward)          // depth along view dir
           guard z > 0.001 else { return nil }     // behind / on camera plane
           let x = simd_dot(rel, right)
           let y = simd_dot(rel, trueUp)
           let h = Float(c.viewport.height)
           let w = Float(c.viewport.width)
           let f = (h * 0.5) / tan(c.verticalFOV * 0.5)   // focal length in px
           let sx = w * 0.5 + (x / z) * f
           let sy = h * 0.5 - (y / z) * f
           let depthScale = referenceDistance / z
           // Parallax: lateral world offset scaled by depth, capped.
           let par = CGSize(width: CGFloat(x * (depthScale - 1) * 0.04),
                            height: CGFloat(y * (depthScale - 1) * 0.04))
           return Projected(point: CGPoint(x: CGFloat(sx), y: CGFloat(sy)),
                            depthScale: depthScale, parallax: par)
       }
   }
   ```
4. Run the gate → passes.
5. Commit: `feat(ios-viz): add pure UniverseProjection (world→screen + depth + parallax)`.

---

## Task 2 — `DeclutterRule` (pure visibility/fade rule)

**Files**
- Create: `Sources/MyAIMap/Universe/Overlay/DeclutterRule.swift`
- Test: `Tests/MyAIMapTests/DeclutterRuleTests.swift`

**Steps**
1. Write failing test. Cover: overview shows only category pills + `core` hub + selected tool; opening a
   pocket (`activeCategory != .core`) shows that category's tool badges; non-pocket tools fade by distance;
   distant nodes drop to 0 opacity.
   ```swift
   import Testing
   @testable import MyAIMap

   @Suite("DeclutterRule")
   struct DeclutterRuleTests {
       @Test func overviewShowsCategoriesAndSelectionOnly() {
           let d = DeclutterRule.badgeVisibility(
               kind: .tool(category: .coding),
               activeCategory: .core, selectedToolID: "x", thisID: "y", depthScale: 1.0)
           #expect(d == 0)  // unselected tool hidden in overview
       }
       @Test func categoryPillAlwaysVisibleInOverview() {
           let d = DeclutterRule.badgeVisibility(
               kind: .category(.coding), activeCategory: .core,
               selectedToolID: "x", thisID: "coding", depthScale: 1.0)
           #expect(d > 0.9)
       }
       @Test func pocketRevealsItsTools() {
           let d = DeclutterRule.badgeVisibility(
               kind: .tool(category: .coding), activeCategory: .coding,
               selectedToolID: "x", thisID: "y", depthScale: 1.0)
           #expect(d > 0.5)
       }
       @Test func distanceFadesOutFarNodes() {
           let near = DeclutterRule.badgeVisibility(
               kind: .tool(category: .coding), activeCategory: .coding,
               selectedToolID: "x", thisID: "y", depthScale: 1.2)
           let far = DeclutterRule.badgeVisibility(
               kind: .tool(category: .coding), activeCategory: .coding,
               selectedToolID: "x", thisID: "y", depthScale: 0.4)
           #expect(near > far)
       }
   }
   ```
2. Run the gate → fails.
3. Minimal impl (plain enum; `ToolCategoryId` already exists in `Data/ToolCategory.swift`):
   ```swift
   enum DeclutterRule {
       enum BadgeKind: Sendable, Equatable {
           case category(ToolCategoryId)
           case tool(category: ToolCategoryId)
           case core
       }

       /// 0…1 opacity for a badge given current selection + depth.
       static func badgeVisibility(kind: BadgeKind, activeCategory: ToolCategoryId,
                                   selectedToolID: String, thisID: String,
                                   depthScale: Float) -> Double {
           let depthFade = depthFactor(depthScale)
           switch kind {
           case .core, .category:
               return depthFade                       // hubs/pills always shown
           case .tool(let category):
               if thisID == selectedToolID { return depthFade }
               let inOpenPocket = (activeCategory != .core && activeCategory == category)
               return inOpenPocket ? depthFade * 0.92 : 0
           }
       }

       /// Linear fade: full inside ref depth, gone when far (depthScale ≤ 0.35).
       static func depthFactor(_ depthScale: Float) -> Double {
           let lo: Float = 0.35, hi: Float = 0.9
           if depthScale >= hi { return 1 }
           if depthScale <= lo { return 0 }
           return Double((depthScale - lo) / (hi - lo))
       }
   }
   ```
4. Run the gate → passes.
5. Commit: `feat(ios-viz): add pure DeclutterRule (overview/pocket + distance fade)`.

---

## Task 3 — `UniverseMotion` (frame-rate-independent easing + reduce-motion)

**Files**
- Create: `Sources/MyAIMap/Universe/Overlay/UniverseMotion.swift`
- Test: `Tests/MyAIMapTests/UniverseMotionTests.swift`

**Steps**
1. Write failing test. Cover: ease-out-expo monotonic 0→1; `lerp(current,target,dt)` uses `1 − exp(−k·dt)`
   so it is frame-rate independent (same total approach for one big step vs two half steps within tolerance);
   `reduceMotion` snaps instantly to target.
   ```swift
   import Testing
   @testable import MyAIMap

   @Suite("UniverseMotion")
   struct UniverseMotionTests {
       @Test func easeOutExpoEndpoints() {
           #expect(abs(UniverseMotion.easeOutExpo(0) - 0) < 1e-4)
           #expect(abs(UniverseMotion.easeOutExpo(1) - 1) < 1e-3)
       }
       @Test func easeOutExpoMonotonic() {
           #expect(UniverseMotion.easeOutExpo(0.25) < UniverseMotion.easeOutExpo(0.75))
       }
       @Test func frameRateIndependentApproach() {
           // one 0.2s step vs two 0.1s steps land within tolerance
           let k: Float = 8
           let one = UniverseMotion.approach(0, 1, dt: 0.2, k: k, reduceMotion: false)
           var two: Float = 0
           two = UniverseMotion.approach(two, 1, dt: 0.1, k: k, reduceMotion: false)
           two = UniverseMotion.approach(two, 1, dt: 0.1, k: k, reduceMotion: false)
           #expect(abs(one - two) < 0.03)
       }
       @Test func reduceMotionSnaps() {
           #expect(UniverseMotion.approach(0, 1, dt: 0.016, k: 8, reduceMotion: true) == 1)
       }
   }
   ```
2. Run the gate → fails.
3. Minimal impl (`nonisolated`, Foundation only):
   ```swift
   import Foundation

   enum UniverseMotion {
       /// Web signature cubic-bezier(0.16,1,0.3,1) approximated as ease-out-expo.
       static func easeOutExpo(_ t: Float) -> Float {
           t >= 1 ? 1 : 1 - powf(2, -10 * t)
       }
       /// Frame-rate-independent exponential approach toward `target`.
       static func approach(_ current: Float, _ target: Float, dt: TimeInterval,
                            k: Float, reduceMotion: Bool) -> Float {
           if reduceMotion { return target }
           let a = 1 - expf(-k * Float(dt))
           return current + (target - current) * a
       }
   }
   ```
4. Run the gate → passes.
5. Commit: `feat(ios-viz): add UniverseMotion (ease-out-expo, fps-independent, reduce-motion)`.

---

## Task 4 — `NodeBadge` (SwiftUI glass-pill label)

**Files**
- Create: `Sources/MyAIMap/Universe/Overlay/NodeBadge.swift`
- Test: `Tests/MyAIMapTests/NodeBadgeTests.swift`

**Steps**
1. Write failing test for the pure presentation model (view bodies aren't unit-tested; the layout
   spec is). Test a `NodeBadge.Style` factory that picks font weight + max width by tier, matching the
   design spec (category ≈ caption.bold, tool ≈ caption2.semibold, focused ≈ subheadline.bold; tool max
   width ~116, focus ~232).
   ```swift
   import Testing
   import SwiftUI
   @testable import MyAIMap

   @Suite("NodeBadge.Style")
   struct NodeBadgeTests {
       @Test func toolTierMaxWidth()    { #expect(NodeBadge.Style.tool.maxWidth == 116) }
       @Test func focusTierMaxWidth()   { #expect(NodeBadge.Style.focused.maxWidth == 232) }
       @Test func categoryTierIsBold()  { #expect(NodeBadge.Style.category.weight == .bold) }
   }
   ```
2. Run the gate → fails.
3. Minimal impl. `Style` is a plain value type; the view uses existing tokens (`BrandColor.textPrimary`,
   `liquidGlass`, `PressableButtonStyle`, `BrandHaptics`, `@ScaledMetric`):
   ```swift
   import SwiftUI

   struct NodeBadge: View {
       enum Style: Sendable, Equatable {
           case category, tool, focused
           var weight: Font.Weight {
               switch self { case .category: .bold; case .tool: .semibold; case .focused: .bold }
           }
           var maxWidth: CGFloat {
               switch self { case .category: 200; case .tool: 116; case .focused: 232 }
           }
           var baseSize: CGFloat {
               switch self { case .category: 12; case .tool: 10.5; case .focused: 15 }
           }
       }

       let text: String
       let style: Style
       let categoryColor: Color
       var iconDomain: String? = nil
       let onTap: () -> Void

       @ScaledMetric private var scale: CGFloat = 1
       @Environment(\.accessibilityReduceMotion) private var reduceMotion

       var body: some View {
           Button(action: onTap) {
               HStack(spacing: 6) {
                   if iconDomain != nil {
                       Circle().fill(categoryColor).frame(width: 6, height: 6)  // category-color dot
                   }
                   Text(text)
                       .font(.system(size: style.baseSize * scale, weight: style.weight))
                       .foregroundStyle(BrandColor.textPrimary.opacity(0.96))
                       .lineLimit(1)
                       .minimumScaleFactor(0.85)
                       .shadow(color: .black.opacity(0.55), radius: 0, x: 0, y: 0) // 1px-style outline proxy
               }
               .padding(.horizontal, 10)
               .padding(.vertical, 5)
               .frame(maxWidth: style.maxWidth * scale, alignment: .leading)
               .liquidGlass(in: Capsule(), tint: categoryColor.opacity(0.4), strokeStrength: 0.18)
               .shadow(color: categoryColor.opacity(0.35), radius: 8)  // glow
           }
           .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: .light))
       }
   }
   ```
   (Press 0.96 + light haptic come from `PressableButtonStyle`; outline via shadow stack; glow via colored shadow.)
4. Run the gate → passes.
5. Commit: `feat(ios-viz): add NodeBadge glass-pill (Dynamic Type, press 0.96 + haptic)`.

---

## Task 5 — `OrbLayer` (glowing disc sprites)

**Files**
- Create: `Sources/MyAIMap/Universe/Overlay/OrbLayer.swift`
- Test: `Tests/MyAIMapTests/OrbLayerTests.swift`

**Steps**
1. Write failing test for the pure size-hierarchy math: `OrbLayer.radius(for:depthScale:)` with the
   three-step ladder core > category > tool, scaled by depth.
   ```swift
   import Testing
   import CoreGraphics
   @testable import MyAIMap

   @Suite("OrbLayer.radius")
   struct OrbLayerTests {
       @Test func coreBiggerThanCategoryBiggerThanTool() {
           let c  = OrbLayer.radius(for: .core, depthScale: 1)
           let cat = OrbLayer.radius(for: .category, depthScale: 1)
           let t  = OrbLayer.radius(for: .tool, depthScale: 1)
           #expect(c > cat && cat > t)
       }
       @Test func depthScalesRadius() {
           #expect(OrbLayer.radius(for: .tool, depthScale: 2) >
                   OrbLayer.radius(for: .tool, depthScale: 1))
       }
   }
   ```
2. Run the gate → fails.
3. Minimal impl. `Tier` plain enum; view draws radial-gradient core + halo via `Canvas` per projected
   point; palette from category color (`ToolCategory.color.swiftUIColor`). The drawing is fed projected
   points + tiers by the host (Task 7); here implement `radius` + a `draw(into:points:)` Canvas helper.
   ```swift
   import SwiftUI

   enum OrbLayer {
       enum Tier: Sendable, Equatable { case core, category, tool }

       static func radius(for tier: Tier, depthScale: Float) -> CGFloat {
           let base: CGFloat = switch tier { case .core: 18; case .category: 12; case .tool: 9 }
           return base * CGFloat(max(0.4, min(depthScale, 2.2)))
       }

       struct Sprite: Identifiable, Equatable {
           let id: String
           let point: CGPoint
           let tier: Tier
           let color: Color
           let depthScale: Float
       }

       /// Draws radial-gradient disc + additive halo for each sprite.
       static func draw(into ctx: inout GraphicsContext, sprites: [Sprite]) {
           // far first for correct overlap
           for s in sprites.sorted(by: { $0.depthScale < $1.depthScale }) {
               let r = radius(for: s.tier, depthScale: s.depthScale)
               let halo = Path(ellipseIn: CGRect(x: s.point.x - r*1.6, y: s.point.y - r*1.6,
                                                 width: r*3.2, height: r*3.2))
               ctx.fill(halo, with: .radialGradient(
                   Gradient(colors: [s.color.opacity(0.28), .clear]),
                   center: s.point, startRadius: 0, endRadius: r*1.6))
               let core = Path(ellipseIn: CGRect(x: s.point.x - r, y: s.point.y - r,
                                                 width: r*2, height: r*2))
               ctx.fill(core, with: .radialGradient(
                   Gradient(colors: [s.color, s.color.opacity(0.2)]),
                   center: s.point, startRadius: 0, endRadius: r))
           }
       }
   }
   ```
4. Run the gate → passes.
5. Commit: `feat(ios-viz): add OrbLayer (radial-gradient discs + halo, size hierarchy)`.

---

## Task 6 — `ConnectionCanvas` (AA edges between projected points)

**Files**
- Create: `Sources/MyAIMap/Universe/Overlay/ConnectionCanvas.swift`
- Test: `Tests/MyAIMapTests/ConnectionCanvasTests.swift`

**Steps**
1. Write failing test for the pure opacity math: `ConnectionCanvas.edgeOpacity(depthScale:confidence:selected:)`
   so opacity rises with depth × confidence, brightens on selection, and the hit-test
   `ConnectionCanvas.hitTest(point:from:to:tolerance:)` detects a tap near an edge.
   ```swift
   import Testing
   import CoreGraphics
   @testable import MyAIMap

   @Suite("ConnectionCanvas")
   struct ConnectionCanvasTests {
       @Test func opacityRisesWithConfidence() {
           #expect(ConnectionCanvas.edgeOpacity(depthScale: 1, confidence: 0.9, selected: false) >
                   ConnectionCanvas.edgeOpacity(depthScale: 1, confidence: 0.2, selected: false))
       }
       @Test func selectionBrightens() {
           #expect(ConnectionCanvas.edgeOpacity(depthScale: 1, confidence: 0.5, selected: true) >
                   ConnectionCanvas.edgeOpacity(depthScale: 1, confidence: 0.5, selected: false))
       }
       @Test func hitTestNearLine() {
           let from = CGPoint(x: 0, y: 0), to = CGPoint(x: 100, y: 0)
           #expect(ConnectionCanvas.hitTest(point: CGPoint(x: 50, y: 3), from: from, to: to, tolerance: 8))
           #expect(!ConnectionCanvas.hitTest(point: CGPoint(x: 50, y: 40), from: from, to: to, tolerance: 8))
       }
   }
   ```
2. Run the gate → fails.
3. Minimal impl. Edge model carries the existing `InferredEdge` fields (`fromId`, `toId`, `confidence`,
   `reason` from `RelationshipIntelligence`). View draws AA `Path` strokes per projected endpoint pair via
   `Canvas`; tap routes the edge `reason` ("connected because") back to the host.
   ```swift
   import SwiftUI

   enum ConnectionCanvas {
       struct Edge: Identifiable, Equatable {
           let id: String           // "from→to"
           let from: CGPoint
           let to: CGPoint
           let depthScale: Float
           let confidence: Double
           let selected: Bool
           let color: Color
           let reason: String
       }

       static func edgeOpacity(depthScale: Float, confidence: Double, selected: Bool) -> Double {
           if selected { return 0.60 }
           let depth = Double(max(0.2, min(depthScale, 1.3)))
           return min(0.45, 0.06 + confidence * 0.30) * depth
       }

       static func hitTest(point p: CGPoint, from a: CGPoint, to b: CGPoint, tolerance: CGFloat) -> Bool {
           let dx = b.x - a.x, dy = b.y - a.y
           let len2 = dx*dx + dy*dy
           guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) <= tolerance }
           let t = max(0, min(1, ((p.x - a.x)*dx + (p.y - a.y)*dy) / len2))
           let proj = CGPoint(x: a.x + t*dx, y: a.y + t*dy)
           return hypot(p.x - proj.x, p.y - proj.y) <= tolerance
       }

       static func draw(into ctx: inout GraphicsContext, edges: [Edge]) {
           for e in edges {
               var path = Path()
               path.move(to: e.from)
               let mid = CGPoint(x: (e.from.x + e.to.x)/2,
                                 y: (e.from.y + e.to.y)/2 + 14)  // gentle Bézier sag
               path.addQuadCurve(to: e.to, control: mid)
               let op = edgeOpacity(depthScale: e.depthScale, confidence: e.confidence, selected: e.selected)
               ctx.stroke(path, with: .color(e.color.opacity(op)),
                          lineWidth: e.selected ? 2 : 1)
           }
       }
   }
   ```
4. Run the gate → passes.
5. Commit: `feat(ios-viz): add ConnectionCanvas (AA Bézier edges, depth×confidence, hit-test)`.

---

## Task 7 — Reduce RealityKit to ambient backdrop + mount overlay

**Files**
- Modify: `Sources/MyAIMap/Universe/UniverseView.swift` (strip world-space text/lines/orbs; keep ambient)
- Create: `Sources/MyAIMap/Universe/Overlay/UniverseOverlay.swift` (the composited SwiftUI overlay)
- Modify: `Sources/MyAIMap/Universe/UniverseScreen.swift` (mount overlay over `RealityView`, camera sync)
- Test: `Tests/MyAIMapTests/UniverseOverlayModelTests.swift`

**Steps**
1. Write failing test for `UniverseOverlayModel` — a pure builder that turns
   (`tools`, `selection`, `camera`) into `[OrbLayer.Sprite]`, `[ConnectionCanvas.Edge]`, and badge specs,
   using `UniverseLayout.categoryPosition`/`toolPosition`/`pocketToolPosition` + `UniverseProjection` +
   `DeclutterRule`. Verify: in overview only category sprites + selected tool produce visible badges;
   nodes projecting behind camera are dropped; edge endpoints come from live projected node points
   (re-projection after a pocket open changes endpoints — fixes the detach bug).
   ```swift
   import Testing
   import simd
   @testable import MyAIMap

   @Suite("UniverseOverlayModel")
   struct UniverseOverlayModelTests {
       private func camera() -> UniverseProjection.Camera { /* down -Z from (0,6,20) */ ... }

       @Test func overviewHidesUnselectedToolBadges() {
           let m = UniverseOverlayModel.build(
               tools: UniverseSeed.tools, activeCategory: .core,
               selectedToolID: "founder-os", camera: camera())
           #expect(m.badges.allSatisfy { badge in
               badge.style != .tool || badge.id == "founder-os"
           })
       }
       @Test func pocketEndpointsTrackProjectedPositions() {
           let overview = UniverseOverlayModel.build(tools: UniverseSeed.tools,
               activeCategory: .core, selectedToolID: "founder-os", camera: camera())
           let pocket = UniverseOverlayModel.build(tools: UniverseSeed.tools,
               activeCategory: .coding, selectedToolID: "founder-os", camera: camera())
           // edges exist and their endpoints differ between layouts (no detach / live re-project)
           #expect(overview.edges != pocket.edges)
       }
   }
   ```
2. Run the gate → fails.
3. Minimal impl:
   - `UniverseOverlayModel.build(...)`: pure struct producing `(sprites, edges, badges)`. For each tool,
     compute world pos via `UniverseLayout` (category anchor + `toolPosition`/`pocketToolPosition` per the
     active layout), project via `UniverseProjection.project`, drop `nil`, compute `OrbLayer.Tier`
     (`core`/`category`/`tool` from `Tool.orbit`/category), badge opacity via `DeclutterRule.badgeVisibility`,
     edges from `viewModel.edgeCache` / `RelationshipIntelligence` with projected endpoints.
   - `UniverseOverlay` view: `TimelineView(.animation)` → `Canvas` calling `ConnectionCanvas.draw` then
     `OrbLayer.draw`, then a `ZStack` of `NodeBadge`s positioned at `badge.point`; tap on edge →
     `onEdgeTap(reason)`. Reads `camera` from a `@Binding`/closure synced from `CameraController`.
   - `UniverseView.swift`: delete/disable `makeCategoryLabel`, `makeToolLabel`, `refreshToolLabels`,
     `makeLink`/`linkMesh`, `makeToolNode` orb construction and `styleToolNode`/`applyLayout` material work
     and the `SpatialTapGesture` orb taps (selection now comes from overlay badge taps). KEEP `StarFieldEntity.make()`,
     `GalaxyDustEntity.make()`, `SkyboxEntity.make()`, founder halo, `ShellBreathingSystem`, and the
     orbit/dolly gestures (`DragGesture`→`orbitChanged`, `MagnifyGesture`→`pinchChanged`). Remove
     `ToolLabelFadeSystem`/`ToolLabelComponent` registration (labels now live in overlay). Expose current
     camera state (eye/target/up/fov/viewport) to `UniverseScreen` via a binding/callback so the overlay
     can project. Remove now-orphaned imports/symbols created by these deletions only.
   - `UniverseScreen.swift`: wrap `UniverseView` and the new `UniverseOverlay` in a `ZStack` (overlay on
     top, `.allowsHitTesting(true)`), pass camera state down, route badge tap → `focusToolFromMap(toolId)`
     and edge tap → existing "connected because" presentation. Keep the existing HUD `VStack`.
4. Run the gate → passes. (Pre-existing tests referencing removed world-space label/link symbols —
   `ToolLabelFadeTests`, `LinkGeometryTests`, world-text assertions — are updated/removed in this task as
   their own minimal edits, since the symbols they cover are intentionally retired; `LinkGeometry` math may
   be retained if still imported, otherwise its test is removed.)
5. Commit: `feat(ios-viz): RealityKit→ambient backdrop + mount SwiftUI/Canvas overlay (camera-synced)`.

---

## Task 8 — Visualization switcher (real `VisualizationStyle` over layout strategies A/K/N/O)

**Files**
- Modify: `Sources/MyAIMap/State/VisualizationStyle.swift` (cases A/K/N/O + galaxy fallback; `available`)
- Create: `Sources/MyAIMap/Universe/Overlay/LayoutStrategy.swift` (pure per-style layout math)
- Modify: `Sources/MyAIMap/Universe/Overlay/UniverseOverlay.swift` (select strategy from `AppSettings.visualizationStyle`)
- Modify: `Sources/MyAIMap/UI/Settings/SettingsSheet.swift` (picker already iterates `allCases`; flip `available`)
- Modify: `Tests/MyAIMapTests/VisualizationStyleTests.swift`
- Create: `Tests/MyAIMapTests/LayoutStrategyTests.swift`

**Steps**
1. Write failing tests:
   - `VisualizationStyleTests`: assert cases now include `.connectedMind` (A, default), `.bloom` (K),
     `.force3D` (N), `.neural` (O), `.galaxy` (legacy fallback); `available == true` for A/K/N/O and galaxy;
     `AppSettings` round-trips a non-default style (persistence via existing `Key.visualization`).
   - `LayoutStrategyTests`: for each style, `LayoutStrategy.position(for:tool:activeCategory:)` returns a
     finite `SIMD3<Float>`; connected-mind (A) places linked tools nearer than unlinked (port of BrainGraph
     `relax()` rest length 13 / spring 0.045 / repulsion 380 / Z-damp 0.82 from
     `src/playground/variants/BrainGraph.tsx:212-264`); force3D (N) keeps non-zero Z spread; galaxy matches
     existing `UniverseLayout` ring output.
   ```swift
   @Suite("LayoutStrategy")
   struct LayoutStrategyTests {
       @Test func everyStyleProducesFinitePositions() {
           for style in VisualizationStyle.allCases {
               for t in UniverseSeed.tools {
                   let p = LayoutStrategy.position(for: style, tool: t, activeCategory: .core)
                   #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite)
               }
           }
       }
       @Test func galaxyMatchesRingLayout() {
           let t = UniverseSeed.tools.first(where: { $0.category == .coding })!
           let p = LayoutStrategy.position(for: .galaxy, tool: t, activeCategory: .core)
           // equals existing UniverseLayout composition for that tool
           #expect(p == LayoutStrategy.galaxyReference(for: t))
       }
       @Test func force3DHasDepthSpread() {
           let zs = UniverseSeed.tools.map {
               LayoutStrategy.position(for: .force3D, tool: $0, activeCategory: .core).z
           }
           #expect((zs.max()! - zs.min()!) > 1)
       }
   }
   ```
2. Run the gate → fails.
3. Minimal impl:
   - `VisualizationStyle.swift`: keep `enum VisualizationStyle: String, CaseIterable, Identifiable, Sendable`.
     Cases: `connectedMind`, `bloom`, `force3D`, `neural`, `galaxy`. `static var defaultStyle: .connectedMind`.
     `var available: Bool { true }` (all four finalists + galaxy now ship). Add EN/RU `title(_:)` strings
     and a new `L10n` entry if needed (Connected Mind / Связанный разум, Bloom / Цветение, etc.).
     Update `AppSettings` default from `.galaxy` to `.connectedMind` (still reads persisted value first).
   - `LayoutStrategy.swift`: pure `enum LayoutStrategy` with
     `static func position(for:tool:activeCategory:) -> SIMD3<Float>` switching on style. `galaxy` composes
     the existing `UniverseLayout.categoryPosition + toolPosition/pocketToolPosition`. `connectedMind`
     ports BrainGraph `relax()` (deterministic, seeded, fixed iterations — no RNG). `bloom` = radial
     progressive rings around the active hub. `force3D` = `connectedMind` without the Z-damp so depth
     spreads. `neural` = `connectedMind` + slight clustered jitter. All deterministic and pure.
   - `UniverseOverlay`/`UniverseOverlayModel.build`: take `style: VisualizationStyle` (from
     `@Environment(AppSettings.self).visualizationStyle`) and call `LayoutStrategy.position` instead of
     hard-coding `UniverseLayout`.
   - `SettingsSheet.visualizationSection`: no structural change — it already `ForEach(VisualizationStyle.allCases)`
     and guards on `style.available`; switching now persists live (existing `didSet`) and the overlay
     re-renders because it reads `AppSettings` from the environment. Verify the "soon" branch no longer
     triggers.
4. Run the gate → passes (live switch + persistence covered by `AppSettings` round-trip test).
5. Commit: `feat(ios-viz): real VisualizationStyle switcher over layouts A/K/N/O (+galaxy fallback)`.

---

## Task 9a — ChatDock auto-scroll-to-bottom on send/answer

**Files**
- Modify: `Sources/MyAIMap/UI/Chat/ChatDock.swift`
- Test: `Tests/MyAIMapTests/ChatThreadStoreTests.swift` (extend)

**Steps**
1. Write failing test capturing the trigger condition the scroll must observe. The root cause
   (`ChatDock.swift:76-81`) is `onChange(of: thread.turns.map(\.id))` firing only on count change, and the
   answer/cards growing the row after `scrollTo`. Add a pure helper `ChatDock.scrollAnchorKey(turns:)`
   returning a value that changes on both new turns AND last-turn content growth, and test it:
   ```swift
   @Test func scrollKeyChangesOnContentGrowth() {
       let a: [ChatTurn] = [ChatTurn(id: 1, q: "hi", answer: "", matchIds: [])]
       let b: [ChatTurn] = [ChatTurn(id: 1, q: "hi", answer: "full answer", matchIds: ["x"])]
       #expect(ChatDock.scrollAnchorKey(turns: a) != ChatDock.scrollAnchorKey(turns: b))
   }
   @Test func scrollKeyChangesOnNewTurn() {
       let a: [ChatTurn] = [ChatTurn(id: 1, q: "hi", answer: "x", matchIds: [])]
       let b = a + [ChatTurn(id: 2, q: "again", answer: "y", matchIds: [])]
       #expect(ChatDock.scrollAnchorKey(turns: a) != ChatDock.scrollAnchorKey(turns: b))
   }
   ```
2. Run the gate → fails.
3. Minimal impl in `ChatDock.swift`:
   - Add `static func scrollAnchorKey(turns: [ChatTurn]) -> String` = `"\(turns.count):\(turns.last?.answer.count ?? 0):\(turns.last?.matchIds.count ?? 0)"`.
   - Add a dedicated bottom anchor view `Color.clear.frame(height: 1).id("bottom")` at the end of the thread.
   - Replace the `.onChange(of: thread.turns.map(\.id))` with `.onChange(of: Self.scrollAnchorKey(turns: thread.turns))`
     and scroll **post-layout**: `Task { @MainActor in withAnimation(BrandMotion.resolved(BrandMotion.flow, reduceMotion: reduceMotion)) { scroller.scrollTo("bottom", anchor: .bottom) } }`.
   - Also scroll on first appear (`.onAppear`) so the 0→1 mount race resolves.
4. Run the gate → passes.
5. Commit: `fix(ios-chat): auto-scroll ChatDock to newest turn on send + answer growth`.

---

## Task 9b — Chat composer persistence when a tool sheet opens

**Files**
- Modify: `Sources/MyAIMap/Universe/UniverseScreen.swift` (decouple ChatDock from sheet detent)
- Modify: `Sources/MyAIMap/UI/Chat/ChatDock.swift` (lift composer draft out of local `@State`)
- Test: `Tests/MyAIMapTests/ChatThreadStoreTests.swift` (extend — draft persistence)

**Steps**
1. Write failing test. The bug: `isPanelActive = sheetDetent != .height(118)` removes `ChatDock` from the
   tree (`UniverseScreen.swift:17-19,122`), dropping the `@State private var text` draft. Move draft to
   `ChatThreadStore` so it survives unmount: add `var composerDraft: String = ""` (persisted, capped),
   test it persists across store instances over the same defaults.
   ```swift
   @Test func composerDraftPersists() {
       let d = freshDefaults()
       let s1 = ChatThreadStore(defaults: d, liveToolIds: [])
       s1.composerDraft = "half typed"
       let s2 = ChatThreadStore(defaults: d, liveToolIds: [])
       #expect(s2.composerDraft == "half typed")
   }
   ```
2. Run the gate → fails.
3. Minimal impl:
   - `ChatThreadStore`: add `var composerDraft: String = "" { didSet { persistDraft() }}` with a new
     `"chatdock.draft.v1"` defaults key (capped at `maxQueryChars`), loaded in `init`.
   - `ChatDock`: bind the `TextField` to `thread.composerDraft` instead of the local `@State var text`;
     clear `thread.composerDraft` in `submit()`.
   - `UniverseScreen`: keep `ChatDock` mounted regardless of detent (gate only its *visual* collapse, not
     its presence). Change the `if !isPanelActive { ChatDock() }` to always mount, collapsing via the
     existing ChatDock `collapsed` mechanism / opacity instead of removal, so draft + scroll survive.
4. Run the gate → passes.
5. Commit: `fix(ios-chat): persist composer draft + keep ChatDock mounted when sheet opens`.

---

## Task 9c — Branded loading state (kill black cold-launch frame)

**Files**
- Modify: `Sources/MyAIMap/Universe/UniverseScreen.swift` (gate scene on a `ready` flag; show branded loader)
- Test: `Tests/MyAIMapTests/UniverseScreenLoadingTests.swift`

**Steps**
1. Write failing test for a pure `UniverseBootState` (so the loading gate is unit-testable headless):
   ```swift
   @Suite("UniverseBootState")
   struct UniverseScreenLoadingTests {
       @Test func startsLoading()       { #expect(UniverseBootState().phase == .loading) }
       @Test func readyAfterSceneReady() {
           var s = UniverseBootState(); s.markSceneReady()
           #expect(s.phase == .ready)
       }
   }
   ```
2. Run the gate → fails.
3. Minimal impl:
   - `UniverseBootState` (plain struct, `Sendable`): `enum Phase { case loading, ready }`, `markSceneReady()`.
   - `UniverseScreen`: hold `@State private var boot = UniverseBootState()`. Overlay a branded loader
     (`BrandColor.void` background + `ProgressOrb()` + `.shimmer()` from `ShimmerLoader.swift`) above the
     `ZStack` while `boot.phase == .loading`. Flip to `.ready` from the `RealityView` make-closure completion
     / first overlay frame (`Task { @MainActor in boot.markSceneReady() }`). Defer IBL + inferred-edge
     inference off the critical path (already async-capable) so first paint is the branded state, not black.
4. Run the gate → passes.
5. Commit: `fix(ios-launch): branded loading state replaces black cold-launch frame`.

---

## Task 9d — Dead buttons (Settings→History tab, double-tap, tap-target audit)

**Files**
- Create: `Sources/MyAIMap/UI/Settings/HistorySheet.swift` (real History list reusing `HistoryChipModel`)
- Modify: `Sources/MyAIMap/UI/Settings/SettingsSheet.swift` (wire `historySection` to present `HistorySheet`)
- Modify: `Sources/MyAIMap/Universe/UniverseView.swift` (double-tap distinct from single-tap)
- Test: `Tests/MyAIMapTests/HistorySheetModelTests.swift`

**Steps**
1. Write failing test for the History list model — reuse `HistoryChipModel` (from `HistoryStrip.swift`) over
   `viewModel.history.events` newest-first (via `ToolHistory.recents`), and assert double-tap maps to a
   distinct action from single-tap (a pure `UniverseTapIntent` resolver):
   ```swift
   @Suite("HistorySheet + tap intents")
   struct HistorySheetModelTests {
       @Test func historyRowsFromEvents() {
           var h = ToolHistory()
           h.record(toolID: "founder-os", kind: .added)
           let rows = HistorySheet.rows(for: h)
           #expect(rows.first?.title == "Founder OS" || rows.first?.id != nil)
       }
       @Test func doubleTapResetsToOverview() {
           #expect(UniverseTapIntent.resolve(taps: 1) == .select)
           #expect(UniverseTapIntent.resolve(taps: 2) == .resetToOverview)
       }
   }
   ```
2. Run the gate → fails.
3. Minimal impl:
   - `HistorySheet`: SwiftUI list of `HistoryChipModel` built from `viewModel.history.events` (use
     `ToolHistory.recents(limit:)` or full list reversed); tap a row → `viewModel.focusTool(id)` + dismiss.
   - `SettingsSheet.historySection`: replace the feedback-only `Button { BrandHaptics.fire(.light) }` with a
     `Button` that sets `@State private var historyPresented = true` and `.sheet(isPresented:)` →
     `HistorySheet`. Keep the chevron (now real navigation).
   - `UniverseView`: add pure `enum UniverseTapIntent { case select, resetToOverview; static func resolve(taps:Int)->Self }`.
     Wire the existing `SpatialTapGesture(count: 2)` `handleDoubleTap` to `resetToOverview`
     (`selectCategory(.core)` / camera reframe to overview) — distinct from single-tap select. (Single-tap
     orb selection was retired in Task 7; double-tap on empty space / backdrop now resets — bind to the
     `RealityView`'s background tap.)
   - Tap-target audit: ensure overlay `NodeBadge` and FAB use ≥44pt hit area (`contentShape` / min frame).
4. Run the gate → passes.
5. Commit: `fix(ios-ui): wire Settings→History sheet + distinct double-tap reset + tap-target audit`.

---

## Task 9e — "+" Add-Tool FAB → AddToolSheet

**Files**
- Create: `Sources/MyAIMap/UI/Sheets/AddToolSheet.swift` (intake UI driving existing classification)
- Modify: `Sources/MyAIMap/Universe/UniverseScreen.swift` (liquid-glass circular FAB → present sheet)
- Modify: `Sources/MyAIMap/State/UniverseViewModel.swift` (add `addTool(_:)` that records + selects)
- Test: `Tests/MyAIMapTests/AddToolFlowTests.swift`

**Steps**
1. Write failing test for the intake flow using existing intelligence: a URL/name in →
   `RelationshipIntelligence.infer` + (optional) `KnowledgeStore.knowledge(for:)` → a `Tool` candidate
   recorded via the view model. Assert `addTool` records added history and selects it:
   ```swift
   @MainActor @Suite("Add-Tool flow")
   struct AddToolFlowTests {
       @Test func addToolRecordsAndSelects() {
           let vm = UniverseViewModel(historyStore: nil)
           let tool = UniverseSeed.tools.first(where: { $0.id == "founder-os" })!
           vm.addTool(tool)
           #expect(vm.selection.selectedToolID == tool.id)
           #expect(vm.recentHistory.contains { $0.toolID == tool.id })
       }
   }
   ```
2. Run the gate → fails.
3. Minimal impl:
   - `UniverseViewModel`: add `func addTool(_ tool: Tool) { recordAdded(tool.id); selectTool(tool.id) }`
     (reuses existing `recordAdded` at line 163 + `selectTool`).
   - `AddToolSheet`: SwiftUI form — name/URL `TextField`, a "Classify" button that runs the existing
     intake intelligence (`QueryEngine`/`RelationshipIntelligence.infer` + `KnowledgeStore`) to build a
     candidate `Tool`, shows inferred category/confidence + "connected because" reasons
     (`RelationshipReason.connectedBecause`), and a Confirm button → `viewModel.addTool` + `success` haptic
     (`BrandHaptics.fire(.success)`). Use `liquidGlass` + `PressableButtonStyle`.
   - `UniverseScreen`: add a circular liquid-glass FAB (`Image(systemName: "plus")`, `liquidGlass(in: Circle())`,
     `BouncyIconButtonStyle`) bottom-trailing in the HUD; tap → `@State addToolPresented = true` →
     `.sheet` `AddToolSheet`. Fire `BrandHaptics.fire(.medium)` on present.
4. Run the gate → passes.
5. Commit: `feat(ios-ui): add liquid-glass "+" FAB + AddToolSheet intake flow`.

---

## Done criteria

- All new pure types unit-tested headless (Tasks 1–6, 8) and green under `test-without-building`.
- RealityKit renders only the ambient backdrop; orbs/edges/labels are screen-space; pocket open re-projects
  edge endpoints live (no detach) (Task 7).
- Settings → Visualization switches A/K/N/O/galaxy live and persists across launches (Task 8).
- Chat scrolls to newest turn; composer draft survives a tool sheet; no black cold-launch; Settings→History
  navigates; double-tap resets to overview; "+" FAB opens AddToolSheet (Tasks 9a–9e).
- Swift 6.0 builds clean on Xcode 16.4 (no isolated-conformance syntax); Reduce Motion honored; 60fps overlay.
- No `src/playground` / vite changes.
