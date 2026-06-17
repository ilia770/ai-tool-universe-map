# R-projection — UniverseProjection
**Phase:** R · **Lens:** render

## Goal (1-2 lines)
A pure, RealityKit-free projector that maps a node's 3D layout position + camera state to a 2D screen point, a depth scale, and a parallax offset, so the SwiftUI overlay (badges/edges/orbs) can draw in screen space. This is the keystone of the Overlay-Native Universe.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Universe/Overlay/UniverseProjection.swift` (pure math)
- reuse (no edit) `Sources/MyAIMap/Universe/Camera/CameraController.swift` — `orbitAdjusted`, `clampedOrbitPitch`, `lookRotation`, `focusEye` already give the eye/orbit math.
- reuse `Sources/MyAIMap/Universe/Camera/PocketTransition.swift` — `framing(mode:target:)` eye offsets.
- reuse `Sources/MyAIMap/Universe/UniverseLayout.swift` — supplies the world positions to project.

## Approach (bullet steps)
- Define a `CameraState` value (eye, target, vertical FOV, orbit yaw/pitch) built from `CameraController` + `PocketTransition.framing`; keep it `Sendable`, simd-only.
- Build a look-at view matrix from `eye`/`target` (reuse the basis logic in `CameraController.lookRotation`), then a perspective projection from FOV + viewport aspect.
- `project(world:viewport:)` → transform world point to clip space, divide by w, map NDC to screen points (flip Y), return `nil` when behind the near plane (w ≤ 0) so the overlay can cull.
- `depthScale` = clamp(referenceDistance / distanceToCamera) into a legibility band (e.g. 0.6…1.6) — drives orb size + label/edge opacity falloff so near reads bigger, far recedes.
- `parallaxOffset` = small screen-space shear from orbit yaw/pitch × (1 − depthScale) so far layers drift less than near (depth cue without true 3D).
- Throttle is the caller's job (~30 Hz); this type does no timing.

## Interface / contract
```swift
struct CameraState: Sendable {
    var eye: SIMD3<Float>
    var target: SIMD3<Float>
    var fovYRadians: Float       // PerspectiveCamera fov
    var orbitYaw: Float
    var orbitPitch: Float
}
struct ProjectedNode: Sendable {
    var screen: CGPoint          // points, origin top-left
    var depthScale: CGFloat      // ~0.6…1.6, near→far
    var parallax: CGSize         // screen-space drift
    var isVisible: Bool          // false when behind camera / off-clip
}
enum UniverseProjection {
    static func project(world: SIMD3<Float>, camera: CameraState, viewport: CGSize) -> ProjectedNode
    static func depthScale(distance: Float) -> CGFloat
}
```

## Tests (`Tests/MyAIMapTests`, Swift Testing — `@Suite`/`@Test`/`#expect`, like `ToolLabelFadeTests`)
- create `Tests/MyAIMapTests/UniverseProjectionTests.swift`.
- Point at `target` projects near viewport center for an axis-aligned overview camera.
- A point at `eye`/behind camera returns `isVisible == false` (w ≤ 0).
- `depthScale` is monotonically decreasing in distance and stays clamped to its band (mirror `ToolLabelFadeTests.alwaysUnitClamped`/`fadesMonotonically`).
- Symmetric world points (±x) project to symmetric screen x around center.
- Doubling viewport width keeps a centered point centered (aspect handled).
- Parallax magnitude grows with orbit yaw and shrinks as depthScale→1 (near).

## Done criteria (checklist)
- [ ] Pure Foundation + simd + CoreGraphics; no RealityKit/SwiftUI import.
- [ ] Behind-camera points cullable via `isVisible`.
- [ ] All projection/depth tests pass headless; Swift 6 strict-concurrency clean (`Sendable`).
- [ ] Eye/FOV sourced from `CameraController`/`PocketTransition`, not redefined.

## Dependencies (other tasks)
- Consumes existing `CameraController`, `PocketTransition`, `UniverseLayout` (no new deps).
- Consumed by: R-node-badge, R-connection-canvas, R-orb-layer, R-declutter, R-viz-switcher.
