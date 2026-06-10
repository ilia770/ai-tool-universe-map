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
