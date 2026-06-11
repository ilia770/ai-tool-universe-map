# iOS Phase 2 — PocketShellEntity + PocketTransition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Visualise an open pocket world natively — translucent ellipsoid shell + two slowly counter-rotating torus rings around the active category, pocket tool nodes scaled 1.18×, shell fading in over `BrandMotion.flow` — step 5 of `docs/PHASE_2_PLAN.md`, porting `src/components/AIToolUniverse3D/PocketWorldShell.tsx`.

**Architecture:** `PocketShellGeometry` (pure Foundation+simd, like `UniverseLayout`) holds all web-parity constants and generates the torus mesh data (positions/normals/indices) — RealityKit has no built-in torus, so we build one via `MeshDescriptor`. `PocketShellEntity` (RealityKit) assembles shell + rings into an `Entity`, applies `UnlitMaterial` with transparent blending, a 0→target opacity fade over 0.36 s (`OpacityComponent` + `FromToByAnimation`), and repeating spin animations on the rings; `accessibilityReduceMotion` renders everything static at final values. `UniverseView` adds the shell when a pocket is open and scales pocketed tool nodes by 1.18.

**Tech Stack:** Swift 6 strict concurrency, RealityKit (`MeshDescriptor`, `UnlitMaterial`, `OpacityComponent`, `FromToByAnimation`), SwiftUI environment, Swift Testing, XcodeGen.

**Worktree:** `/Users/ilia882/.config/superpowers/worktrees/ai-tool-universe-map/claude-ios-phase2-proximity`, branch `feat/ios-phase2-pocket-shell` (created off `origin/main` at `99e0b01`).

**Out of scope:** drei `Sparkles` particle field (needs a particle system — Phase 3 polish), the HTML "Pocket world / N tools expanded" readout (lands as SwiftUI overlay with the Sheets slice, step 7), cross-rebuild lerp of *existing* entities (the `.id(selectedCategory)` rebuild makes that impossible without re-architecting the scene container — documented deviation below), tap gestures, SearchDock.

## Web-parity contract

From `PocketWorldShell.tsx` (+ `layout.ts` `POCKET_WORLD_RADIUS = 7`, matching `UniverseLayout.pocketWorldRadius`):

| Element | Web value | iOS mapping |
| --- | --- | --- |
| Shell | sphere r=7, scale (1.18, 0.18, 0.74), color category, target opacity 0.052 | `generateSphere(radius: 7)`, same scale, UnlitMaterial tint, OpacityComponent fade to 0.052 |
| Outer ring | torus R=7, tube 0.018, color category, opacity 0.28, spin +0.035 rad/s about local Z (lying flat: rotated π/2 about X) | procedural torus mesh, same params |
| Inner ring | torus R=7·0.64, tube 0.012, white, opacity 0.12, tilt (π/2.18, 0.24, 0.2), spin −0.055 rad/s | same |
| Pocket nodes | (plan step-5 text) scale 1.18× | `node.scale = SIMD3(repeating: 1.18)` when `pocketed` |
| Fade-in | web lerps opacity per-frame (`+= (target−o)·0.04`) | single 0.36 s (`BrandMotion.flow` duration) ease-out fade per entity spawn |
| Reduced motion | rotations zeroed, opacity snapped | no animations; final opacity set directly |

**Accepted deviations (put in PR description):**
1. Web's shell "breathing" (±1.8 % scale wobble) and group yaw sway are dropped — sub-2 % ambient effects, not worth a per-frame System; rings still spin so the pocket reads alive. Revisit with the Phase 3 polish pass.
2. The web lerps *all* shell properties continuously per frame; iOS uses a one-shot fade on spawn because the scene rebuilds via `.id(selectedCategory)` — there is no persistent entity to lerp across a category change. Same visual outcome (pocket fades in over ~0.4 s).
3. Spin speeds are slow (π in ~90 s / ~57 s) — implemented as repeating `by:`-rotation transform animations.

**Verify gate (runner is UNBLOCKED — full test suite, takes seconds):**

```bash
cd ios-app && xcodegen generate && \
xcodebuild -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,id=01F7938F-C881-43B9-9222-0E78E63D7A51' \
  test 2>&1 | grep -E "Test run|TEST (SUCCEEDED|FAILED)|✘" && cd ..
```

Expected: `Test run with N tests in M suites passed` + `** TEST SUCCEEDED **` (43 tests on main before this slice).

Fast app-sources typecheck (no test files):

```bash
cd ios-app && xcrun swiftc -typecheck \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios18.0-simulator \
  $(find Sources -name '*.swift') && cd ..
```

**Repo wart:** `.github/PULL_REQUEST_TEMPLATE.md` may show as modified/deleted in the working tree (APFS case-collision residue). Never stage it.

---

### Task 1: `PocketShellGeometry` — constants + procedural torus (TDD)

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/Entities/PocketShellGeometry.swift`
- Test: `ios-app/Tests/MyAIMapTests/PocketShellGeometryTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
import simd
@testable import MyAIMap

@Suite("PocketShellGeometry — web PocketWorldShell parity")
struct PocketShellGeometryTests {

    @Test func constantsMatchWebShell() {
        // PocketWorldShell.tsx: shell scale [1.18, 0.18, 0.74], target
        // opacity 0.052; rings 0.28 / 0.12; tubes 0.018 / 0.012;
        // inner radius factor 0.64; spins 0.035 / -0.055 rad/s.
        #expect(PocketShellGeometry.shellScale == SIMD3<Float>(1.18, 0.18, 0.74))
        #expect(PocketShellGeometry.shellOpacity == 0.052)
        #expect(PocketShellGeometry.outerRingOpacity == 0.28)
        #expect(PocketShellGeometry.innerRingOpacity == 0.12)
        #expect(PocketShellGeometry.outerTube == 0.018)
        #expect(PocketShellGeometry.innerTube == 0.012)
        #expect(PocketShellGeometry.innerRadiusFactor == 0.64)
        #expect(PocketShellGeometry.outerSpinRadPerSec == 0.035)
        #expect(PocketShellGeometry.innerSpinRadPerSec == -0.055)
        #expect(PocketShellGeometry.pocketNodeScale == 1.18)
    }

    @Test func torusVertexAndIndexCounts() {
        // (radial+1) * (tubular+1) vertices; radial * tubular * 2
        // triangles, 3 indices each.
        let torus = PocketShellGeometry.torus(radius: 7, tube: 0.018, radialSegments: 8, tubularSegments: 104)
        #expect(torus.positions.count == 9 * 105)
        #expect(torus.normals.count == torus.positions.count)
        #expect(torus.indices.count == 8 * 104 * 2 * 3)
    }

    @Test func torusVerticesLieOnTorusSurface() {
        let R: Float = 7, t: Float = 0.018
        let torus = PocketShellGeometry.torus(radius: R, tube: t, radialSegments: 8, tubularSegments: 32)
        for p in torus.positions {
            // Torus in XY plane: distance from the ring circle == tube.
            let ringDist = simd_length(SIMD2<Float>(simd_length(SIMD2<Float>(p.x, p.y)) - R, p.z))
            #expect(abs(ringDist - t) < 1e-4)
        }
    }

    @Test func torusNormalsAreUnitLength() {
        let torus = PocketShellGeometry.torus(radius: 4.48, tube: 0.012, radialSegments: 8, tubularSegments: 88)
        for n in torus.normals {
            #expect(abs(simd_length(n) - 1) < 1e-4)
        }
    }

    @Test func torusIndicesAreInBounds() {
        let torus = PocketShellGeometry.torus(radius: 7, tube: 0.018, radialSegments: 8, tubularSegments: 104)
        let vertexCount = UInt32(torus.positions.count)
        #expect(torus.indices.allSatisfy { $0 < vertexCount })
    }
}
```

- [ ] **Step 2: Verify red** — full gate command above; expected compile FAILURE (`cannot find 'PocketShellGeometry'`).

- [ ] **Step 3: Implement**

```swift
import Foundation
import simd

/// Web-parity constants and procedural mesh math for the pocket-world
/// shell (`src/components/AIToolUniverse3D/PocketWorldShell.tsx`).
/// Foundation + simd only — RealityKit has no torus primitive, so
/// `PocketShellEntity` builds one from this generator via MeshDescriptor.
enum PocketShellGeometry {
    // Shell ellipsoid: sphere r = UniverseLayout.pocketWorldRadius
    // scaled by [1.18, 0.18, 0.74]; additive-ish translucency target.
    static let shellScale = SIMD3<Float>(1.18, 0.18, 0.74)
    static let shellOpacity: Float = 0.052
    static let outerRingOpacity: Float = 0.28
    static let innerRingOpacity: Float = 0.12
    static let outerTube: Float = 0.018
    static let innerTube: Float = 0.012
    static let innerRadiusFactor: Float = 0.64
    static let outerSpinRadPerSec: Float = 0.035
    static let innerSpinRadPerSec: Float = -0.055
    /// PHASE_2_PLAN step 5: pocket entities scale up by 1.18×.
    static let pocketNodeScale: Float = 1.18
    /// Inner ring tilt, web: rotation={[Math.PI / 2.18, 0.24, 0.2]}.
    static let innerRingTilt = SIMD3<Float>(.pi / 2.18, 0.24, 0.2)

    struct TorusMesh: Equatable, Sendable {
        let positions: [SIMD3<Float>]
        let normals: [SIMD3<Float>]
        let indices: [UInt32]
    }

    /// Torus centred at origin in the XY plane (web torusGeometry
    /// convention — callers tip it flat with an X-rotation), standard
    /// parametrisation: ring angle u (tubular), tube angle v (radial).
    static func torus(radius: Float, tube: Float, radialSegments: Int, tubularSegments: Int) -> TorusMesh {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        positions.reserveCapacity((radialSegments + 1) * (tubularSegments + 1))
        normals.reserveCapacity(positions.capacity)

        for j in 0...radialSegments {
            let v = Float(j) / Float(radialSegments) * 2 * .pi
            for i in 0...tubularSegments {
                let u = Float(i) / Float(tubularSegments) * 2 * .pi
                let centre = SIMD3<Float>(radius * cos(u), radius * sin(u), 0)
                let position = SIMD3<Float>(
                    (radius + tube * cos(v)) * cos(u),
                    (radius + tube * cos(v)) * sin(u),
                    tube * sin(v)
                )
                positions.append(position)
                normals.append(simd_normalize(position - centre))
            }
        }

        var indices: [UInt32] = []
        indices.reserveCapacity(radialSegments * tubularSegments * 6)
        let stride = tubularSegments + 1
        for j in 1...radialSegments {
            for i in 1...tubularSegments {
                let a = UInt32(stride * j + i)
                let b = UInt32(stride * (j - 1) + i)
                let c = UInt32(stride * (j - 1) + i - 1)
                let d = UInt32(stride * j + i - 1)
                indices.append(contentsOf: [a, b, d, b, c, d])
            }
        }
        return TorusMesh(positions: positions, normals: normals, indices: indices)
    }
}
```

- [ ] **Step 4: Verify green** — full gate; expected `** TEST SUCCEEDED **`, test count grows by 5.

- [ ] **Step 5: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/Entities/PocketShellGeometry.swift \
        ios-app/Tests/MyAIMapTests/PocketShellGeometryTests.swift
git commit -m "feat(ios): PocketShellGeometry — web-parity constants + procedural torus"
```

---

### Task 2: `PocketShellEntity` (RealityKit assembly)

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/Entities/PocketShellEntity.swift`

No unit tests (RealityKit-bound; mesh math covered by Task 1). Gate: typecheck + full build.

- [ ] **Step 1: Implement**

```swift
import Foundation
import RealityKit
import UIKit

/// Translucent shell + two counter-rotating torus rings marking an open
/// pocket world — native port of the web `PocketWorldShell` (drei
/// Sparkles + HTML readout intentionally omitted; see the slice plan).
/// Fades in over `BrandMotion.flow`'s 0.36 s; with reduce-motion the
/// shell renders static at final opacity with no spins.
@MainActor
enum PocketShellEntity {

    /// Duration mirrors BrandMotion.flow (.smooth(duration: 0.36)) —
    /// Animation values aren't introspectable, so the literal lives here.
    static let fadeDuration: TimeInterval = 0.36

    static func make(category: ToolCategory, position: SIMD3<Float>, reduceMotion: Bool) -> Entity {
        let root = Entity()
        root.position = position

        let color = category.color.uiColor

        let shell = ModelEntity(
            mesh: .generateSphere(radius: UniverseLayout.pocketWorldRadius),
            materials: [material(color, opacity: PocketShellGeometry.shellOpacity)]
        )
        shell.scale = PocketShellGeometry.shellScale
        root.addChild(shell)

        let outer = ringEntity(
            radius: UniverseLayout.pocketWorldRadius,
            tube: PocketShellGeometry.outerTube,
            tubularSegments: 104,
            color: color,
            opacity: PocketShellGeometry.outerRingOpacity
        )
        // Web: rotation={[Math.PI / 2, 0, 0]} — lay the XY torus flat.
        outer.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        root.addChild(outer)

        let inner = ringEntity(
            radius: UniverseLayout.pocketWorldRadius * PocketShellGeometry.innerRadiusFactor,
            tube: PocketShellGeometry.innerTube,
            tubularSegments: 88,
            color: .white,
            opacity: PocketShellGeometry.innerRingOpacity
        )
        inner.orientation = tiltRotation(PocketShellGeometry.innerRingTilt)
        root.addChild(inner)

        if !reduceMotion {
            fadeIn(root)
            spin(outer, radPerSec: PocketShellGeometry.outerSpinRadPerSec)
            spin(inner, radPerSec: PocketShellGeometry.innerSpinRadPerSec)
        }
        return root
    }

    // MARK: - Pieces

    private static func material(_ color: UIColor, opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

    private static func ringEntity(radius: Float, tube: Float, tubularSegments: Int, color: UIColor, opacity: Float) -> ModelEntity {
        let torus = PocketShellGeometry.torus(radius: radius, tube: tube, radialSegments: 8, tubularSegments: tubularSegments)
        var descriptor = MeshDescriptor(name: "pocket-ring")
        descriptor.positions = MeshBuffer(torus.positions)
        descriptor.normals = MeshBuffer(torus.normals)
        descriptor.primitives = .triangles(torus.indices)
        let mesh = (try? MeshResource.generate(from: [descriptor]))
            ?? .generateSphere(radius: tube) // unreachable fallback; generation of a valid descriptor cannot throw in practice
        return ModelEntity(mesh: mesh, materials: [material(color, opacity: opacity)])
    }

    /// Web parity: rotation order in three.js is XYZ Euler.
    private static func tiltRotation(_ euler: SIMD3<Float>) -> simd_quatf {
        let x = simd_quatf(angle: euler.x, axis: SIMD3<Float>(1, 0, 0))
        let y = simd_quatf(angle: euler.y, axis: SIMD3<Float>(0, 1, 0))
        let z = simd_quatf(angle: euler.z, axis: SIMD3<Float>(0, 0, 1))
        return x * y * z
    }

    private static func fadeIn(_ entity: Entity) {
        entity.components.set(OpacityComponent(opacity: 0))
        let fade = FromToByAnimation<Float>(
            from: 0,
            to: 1,
            duration: fadeDuration,
            timing: .easeOut,
            bindTarget: .opacity
        )
        if let resource = try? AnimationResource.generate(with: fade) {
            entity.playAnimation(resource)
        } else {
            entity.components.set(OpacityComponent(opacity: 1))
        }
    }

    /// Continuous spin about the ring's local Z (its symmetry axis):
    /// repeating relative π rotations sidestep quaternion shortest-arc.
    private static func spin(_ entity: Entity, radPerSec: Float) {
        let halfTurn = simd_quatf(angle: .pi * (radPerSec < 0 ? -1 : 1), axis: SIMD3<Float>(0, 0, 1))
        let spin = FromToByAnimation<Transform>(
            by: Transform(rotation: halfTurn),
            duration: TimeInterval(Float.pi / abs(radPerSec)),
            timing: .linear,
            bindTarget: .transform,
            repeatMode: .repeat
        )
        if let resource = try? AnimationResource.generate(with: spin) {
            entity.playAnimation(resource)
        }
    }
}
```

**API contingencies (resolve with the compiler, report what was needed):** `OpacityComponent` + `.opacity` bind target are iOS 18 SDK APIs; if `FromToByAnimation<Transform>(by:)` rejects relative transform rotation under `repeatMode: .repeat`, fall back to an explicit two-keyframe `SampledAnimation` of `Transform`, or as last resort drop the spins (static rings) and report DONE_WITH_CONCERNS. If `UnlitMaterial.blending` lacks `.transparent(opacity:)`, use `UnlitMaterial(color: color.withAlphaComponent(CGFloat(opacity)))`.

- [ ] **Step 2: Typecheck** (fast command) → exit 0.
- [ ] **Step 3: Full gate** → `** TEST SUCCEEDED **` (no new tests, count unchanged).
- [ ] **Step 4: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/Entities/PocketShellEntity.swift
git commit -m "feat(ios): PocketShellEntity — translucent shell + counter-rotating rings"
```

---

### Task 3: Wire into `UniverseView` (+ 1.18× pocket nodes)

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseView.swift`

- [ ] **Step 1: Edits**

(a) Add the environment value after the `@State private var cameraController` line:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

(b) In the make closure, inside the category loop, right after `universe.addChild(Self.makeCategoryAnchor(...))`, add the shell for the open pocket:

```swift
                if category.id == selectedCategory {
                    universe.addChild(PocketShellEntity.make(category: category, position: center, reduceMotion: reduceMotion))
                }
```

(c) In `makeToolNode`, scale pocketed nodes — after `node.position = position`, add:

```swift
        if pocketed {
            // PHASE_2_PLAN step 5: pocket entities scale up by 1.18×.
            node.scale = SIMD3<Float>(repeating: PocketShellGeometry.pocketNodeScale)
        }
```

No other lines change.

- [ ] **Step 2: Typecheck** → exit 0. **Full gate** → `** TEST SUCCEEDED **`.
- [ ] **Step 3: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/UniverseView.swift
git commit -m "feat(ios): show pocket shell + 1.18x pocket nodes when a category is open"
```

---

### Task 4: Final review + PR

- [ ] **Step 1:** Full gate on HEAD; `git log --oneline origin/main..HEAD` → 3 commits (+1 for this plan doc).
- [ ] **Step 2:** Commit this plan file; push `feat/ios-phase2-pocket-shell`; `gh pr create` titled `feat(ios): Phase 2 — PocketShellEntity + pocket transition (step 5)`, body covering: web-parity table, the three accepted deviations above, test delta, runner status. End body with the standard Claude Code attribution.
