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
