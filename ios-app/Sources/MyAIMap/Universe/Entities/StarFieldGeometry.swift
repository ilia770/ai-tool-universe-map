import Foundation
import simd

/// Pure (Foundation + simd) star-field math — the ambient cosmic backdrop
/// behind the universe, mirroring the web `StarField.tsx` in spirit: a few
/// hundred dim points distributed on a large sphere shell that encloses the
/// whole scene, well beyond the camera's maxDistance (46) so the stars are
/// always "out there" and never collide with the playable volume.
///
/// Distribution is a deterministic Fibonacci sphere (golden-angle spiral):
/// no RNG is needed for the *placement*, which keeps it perfectly even and
/// reproducible. A small per-point radius jitter is layered on via a simple
/// seeded LCG so the shell doesn't look mechanically perfect — the jitter is
/// still fully deterministic for a given seed, so tests can assert exact
/// equality and bounded radius.
///
/// Kept RealityKit-free so `StarFieldGeometryTests` can exercise it in the
/// `MyAIMapTests` target.
enum StarFieldGeometry {
    /// Total stars across both tiers. A few hundred tiny spheres is cheap
    /// for a static backdrop (see StarFieldEntity perf note).
    static let starCount = 220

    /// Shell radius — beyond CameraController.maxDistance (46) so stars sit
    /// far outside the scene at all zoom levels.
    static let shellRadius: Float = 120

    /// Fraction of the radius the LCG jitter may push a star in or out, so
    /// the shell reads as a band rather than a perfect surface.
    static let radiusJitter: Float = 0.12

    /// Fraction of stars in the bright/large tier (web: a minority of
    /// brighter points over a dimmer majority).
    static let brightTierFraction: Float = 0.3

    /// Per-star sphere radii (world units) for each tier. Tiny — they read
    /// as points at shell distance.
    static let brightStarRadius: Float = 0.42
    static let dimStarRadius: Float = 0.26

    /// Opacities mirror the web tiers (bright ~0.7, dim ~0.38).
    static let brightStarOpacity: Float = 0.7
    static let dimStarOpacity: Float = 0.38

    /// Default seed for the production star field.
    static let defaultSeed: UInt64 = 0x5EED_5_A11

    private static let goldenAngle: Float = .pi * (3 - sqrt(5))

    /// Deterministic points on (or near) the sphere shell.
    ///
    /// Placement uses the golden-angle Fibonacci spiral — even coverage with
    /// no RNG. The radius of each point is jittered within
    /// `±radiusJitter * shellRadius` by a seeded LCG, so the same seed always
    /// yields the same array (reproducible for tests) while different seeds
    /// shift the band.
    static func positions(count: Int = starCount, shellRadius: Float = shellRadius, seed: UInt64 = defaultSeed) -> [SIMD3<Float>] {
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
