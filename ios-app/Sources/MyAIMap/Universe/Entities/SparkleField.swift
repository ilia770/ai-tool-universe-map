import Foundation
import RealityKit
import UIKit
import simd

/// Pure (Foundation + simd) sparkle-field math — the bright particle field
/// that fills an open pocket world, mirroring the web drei `<Sparkles>` in
/// `PocketWorldShell.tsx`:
///
///     <Sparkles count={54}
///       scale={[POCKET_WORLD_RADIUS*2.18, 2.8, POCKET_WORLD_RADIUS*1.36]}
///       size={1.65} speed={0.16} color={category.color} />
///
/// drei's `scale` is the FULL box size and particles are scattered uniformly
/// across `±scale/2`, so with `POCKET_WORLD_RADIUS = 7` the box half-extents
/// are (x ≈ 7.63, y = 1.4, z ≈ 4.76). This is a BOX volume, not a sphere —
/// the field is wide and flat, matching the flattened pocket shell ellipsoid.
///
/// Placement is a seeded LCG over each axis independently (the StarField LCG
/// pattern), so the same seed always yields the same array — tests assert
/// exact equality, in-box bounds, and octant spread. Kept RealityKit-free so
/// `SparkleFieldGeometryTests` can exercise it in the `MyAIMapTests` target.
enum SparkleFieldGeometry {
    /// Web: count={54}.
    static let sparkleCount = 54

    /// Box HALF-extents derived from the web `scale` (full size / 2) with
    /// POCKET_WORLD_RADIUS = UniverseLayout.pocketWorldRadius = 7:
    ///   x = 7 * 2.18 / 2 = 7.63
    ///   y = 2.8 / 2      = 1.40
    ///   z = 7 * 1.36 / 2 = 4.76
    static let halfExtents = SIMD3<Float>(
        UniverseLayout.pocketWorldRadius * 2.18 / 2,
        2.8 / 2,
        UniverseLayout.pocketWorldRadius * 1.36 / 2
    )

    /// Per-particle sphere radius (world units). Small bright specks — there
    /// is no point primitive in RealityKit, so each sparkle is a tiny sphere.
    static let particleRadius: Float = 0.08

    /// Bright, near-additive translucency (web sparkles read hot against the
    /// dim shell).
    static let opacity: Float = 0.8

    /// Default seed for the production sparkle field.
    static let defaultSeed: UInt64 = 0x5_A12_5EED

    /// Deterministic points filling the BOX volume `±halfExtents`.
    ///
    /// Each axis is drawn independently from a seeded LCG in `[-half, +half]`,
    /// so the cloud fills the box (not a sphere) and the same seed always
    /// reproduces the same array for tests. Different seeds shift the cloud.
    static func positions(
        count: Int = sparkleCount,
        halfExtents: SIMD3<Float> = halfExtents,
        seed: UInt64 = defaultSeed
    ) -> [SIMD3<Float>] {
        guard count > 0 else { return [] }

        var rng = LCG(seed: seed)
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(count)

        for _ in 0..<count {
            // Each component ∈ [-1, 1) scaled by the matching half-extent so
            // the point lands anywhere inside the box.
            let x = (rng.nextUnitFloat() * 2 - 1) * halfExtents.x
            let y = (rng.nextUnitFloat() * 2 - 1) * halfExtents.y
            let z = (rng.nextUnitFloat() * 2 - 1) * halfExtents.z
            points.append(SIMD3<Float>(x, y, z))
        }

        return points
    }

    /// Minimal deterministic 64-bit LCG (Numerical Recipes constants),
    /// matching `StarFieldGeometry` — reproducible scatter, not cryptography.
    private struct LCG {
        private var state: UInt64
        init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }

        /// A float in [0, 1).
        mutating func nextUnitFloat() -> Float {
            Float(next() >> 40) / Float(1 << 24)
        }
    }
}

/// Bright sparkle particle field that lives inside an open pocket world —
/// native port of the deferred drei `<Sparkles>` from `PocketWorldShell`.
///
/// Like `StarFieldEntity`, one MeshResource and one UnlitMaterial (in the
/// category colour) are built ONCE and shared across all 54 sparkles; only
/// the lightweight Entity wrappers and their transforms differ. Sparkles
/// carry no InputTargetComponent or collision, so they never steal a tap.
///
/// The returned root is added as a child of the pocket shell root in
/// `PocketShellEntity.make`, so positions are local to the shell (already
/// centred on the category position) and the field appears/disappears with
/// the pocket via the shell's existing add/remove lifecycle.
///
/// v1 is STATIC: no per-particle drift or twinkle. The web `speed={0.16}` is
/// a slow drift/twinkle, but a faithful animation would need a per-particle
/// driver every frame; a static bright field already reads as the pocket
/// "filling" with sparkles. A single shared twinkle is tracked as follow-up.
@MainActor
enum SparkleFieldEntity {

    static func make(color: UIColor, reduceMotion: Bool) -> Entity {
        let root = Entity()
        root.name = "sparkles"

        // One shared mesh + material for all 54 sparkles (see type doc).
        let mesh = MeshResource.generateSphere(radius: SparkleFieldGeometry.particleRadius)
        let material = sparkleMaterial(color: color)

        for position in SparkleFieldGeometry.positions() {
            let sparkle = ModelEntity(mesh: mesh, materials: [material])
            sparkle.position = position
            root.addChild(sparkle)
        }

        // v1 static regardless of reduceMotion; the flag is threaded so a
        // future twinkle can honour it without a signature change.
        _ = reduceMotion
        return root
    }

    /// Unlit + transparent so sparkles glow at a fixed brightness in the
    /// category colour, independent of the scene lighting rig.
    private static func sparkleMaterial(color: UIColor) -> UnlitMaterial {
        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: .init(floatLiteral: SparkleFieldGeometry.opacity))
        return material
    }
}
