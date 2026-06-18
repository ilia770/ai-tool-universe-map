import Foundation
import simd

/// Pure (Foundation + simd) galaxy-dust math — a sparse ambient haze layer
/// that sits BETWEEN the near node cloud and the far star shell, adding a
/// sense of cosmic depth. Mirrors the web `GalaxyDust.tsx` in spirit: far
/// fewer, far larger, far softer blobs than the star field, at very low
/// opacity, drifting at mid-distance. (The web layer's slow drift is a later
/// polish — this slice places the dust statically.)
///
/// Distribution reuses StarFieldGeometry's recipe (do NOT refactor that
/// type — the pattern is intentionally replicated here): a deterministic
/// Fibonacci sphere for even placement, plus a seeded-LCG radius jitter so
/// the layer reads as a loose cloud rather than a perfect shell. The jitter
/// here is LARGER than the stars' — dust is a diffuse cloud, not a crisp
/// surface. Same seed → identical array, so tests can assert exact equality
/// and a bounded radius band.
///
/// Kept RealityKit-free so `GalaxyDustGeometryTests` can exercise it in the
/// `MyAIMapTests` target.
enum GalaxyDustGeometry {
    /// Sparse — far fewer than the ~220 stars. A handful of big soft blobs
    /// is enough to read as depth haze without crowding the scene.
    static let dustCount = 22

    /// Mid shell radius — closer than the stars (StarFieldGeometry.shellRadius
    /// 120) but outside the node cloud and the camera's maxDistance (46), so
    /// the dust reads as foreground haze hanging at the scene's edge, not as
    /// more background stars.
    static let shellRadius: Float = 36

    /// Fraction of the radius the LCG jitter may push a blob in or out.
    /// Larger than the stars' 0.12 — dust is a loose volumetric cloud, so it
    /// spreads across a wide band rather than hugging a surface.
    static let radiusJitter: Float = 0.3

    /// Per-blob sphere radius (world units). LARGE — these are soft haze
    /// blobs, not points. (See GalaxyDustEntity for the hard-sphere caveat.)
    static let spriteRadius: Float = 4.0

    /// VERY low opacity so overlapping blobs accumulate into a faint depth
    /// wash rather than reading as solid balls.
    static let opacity: Float = 0.07

    /// Default seed for the production dust layer.
    static let defaultSeed: UInt64 = 0xD057_C105

    private static let goldenAngle: Float = .pi * (3 - sqrt(5))

    /// Deterministic blob centres in (or near) the mid shell.
    ///
    /// Placement uses the golden-angle Fibonacci spiral — even coverage with
    /// no RNG. Each centre's radius is jittered within `±radiusJitter *
    /// shellRadius` by a seeded LCG, so the same seed always yields the same
    /// array (reproducible for tests) while different seeds reshape the cloud.
    static func positions(count: Int = dustCount, shellRadius: Float = shellRadius, seed: UInt64 = defaultSeed) -> [SIMD3<Float>] {
        guard count > 0 else { return [] }

        var rng = LCG(seed: seed)
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(count)

        for index in 0..<count {
            // Fibonacci sphere: y sweeps -1…1, the radial angle spirals by
            // the golden angle so points never bunch into stripes.
            let y = 1 - (Float(index) + 0.5) * (2 / Float(count))
            let ringRadius = sqrt(max(0, 1 - y * y))
            let phi = Float(index) * goldenAngle

            let unit = SIMD3<Float>(
                cos(phi) * ringRadius,
                y,
                sin(phi) * ringRadius
            )

            // jitter ∈ [-radiusJitter, +radiusJitter] of the shell radius.
            let jitter = (rng.nextUnitFloat() * 2 - 1) * radiusJitter
            let radius = shellRadius * (1 + jitter)
            points.append(unit * radius)
        }

        return points
    }

    /// Minimal deterministic 64-bit LCG (Numerical Recipes constants).
    /// Not for cryptography — just reproducible jitter.
    private struct LCG {
        private var state: UInt64
        init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }

        /// A float in [0, 1).
        mutating func nextUnitFloat() -> Float {
            // Top 24 bits → [0, 1) at single-precision resolution.
            Float(next() >> 40) / Float(1 << 24)
        }
    }
}
