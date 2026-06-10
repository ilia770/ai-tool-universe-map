import Testing
import simd
@testable import MyAIMap

@Suite("UniverseLayout — parity with web app math")
struct UniverseLayoutTests {

    @Test func corePositionStaysAtOrigin() {
        let pos = UniverseLayout.toolPosition(
            angleDegrees: 0,
            orbit: .core,
            categoryAngleDegrees: 0
        )
        #expect(pos == .zero)
    }

    @Test func categoryPositionMatchesWebMath() {
        let pos = UniverseLayout.categoryPosition(angleDegrees: 0)
        // x = cos(0) * 4.55 = 4.55; y = sin(0) * 1.35 = 0; z = sin(0) * 3.45 = 0
        #expect(abs(pos.x - 4.55) < 0.001)
        #expect(abs(pos.y) < 0.001)
        #expect(abs(pos.z) < 0.001)
    }

    @Test func pocketLayoutFitsInsidePocketWorldRadius() {
        // Fibonacci-sphere should never push a tool past the
        // PocketWorldShell sphere on any orbit ring.
        let categoryAngle: Float = 45
        let categoryCenter = UniverseLayout.categoryPosition(angleDegrees: categoryAngle)
        let slotCount = 12

        for slot in 0..<slotCount {
            for ring in [OrbitRing.inner, .middle, .outer] {
                let pos = UniverseLayout.pocketToolPosition(
                    angleDegrees: Float(slot * 30),
                    orbit: ring,
                    categoryAngleDegrees: categoryAngle,
                    slotIndex: slot,
                    slotCount: slotCount
                )
                let offset = pos - categoryCenter
                let dist = sqrt(offset.x * offset.x + offset.y * offset.y + offset.z * offset.z)
                #expect(dist <= UniverseLayout.pocketWorldRadius + 0.001,
                        "ring \(ring.rawValue) slot \(slot) drifted to \(dist)")
            }
        }
    }

    @Test func eightCategoriesSpreadEvenlyAround() {
        let positions = UniverseSeed.categories
            .filter { $0.id != .core }
            .map { UniverseLayout.categoryPosition(angleDegrees: $0.angle) }
        // Categories should not collapse onto each other.
        for i in 0..<positions.count {
            for j in (i + 1)..<positions.count {
                let delta = positions[i] - positions[j]
                let dist = sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z)
                #expect(dist > 0.5, "categories at indices \(i) and \(j) too close: \(dist)")
            }
        }
    }
}
