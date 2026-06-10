import Foundation
import simd

/// Pure layout math, ported one-for-one from the web app's
/// `src/components/AIToolUniverse3D/layout.ts`.
///
/// Keeping this module Foundation + simd only (no SwiftUI / RealityKit
/// imports) makes the layout independently testable from the
/// `MyAIMapTests` target.
enum UniverseLayout {
    static let categoryRadiusX: Float = 4.55
    static let categoryRadiusZ: Float = 3.45
    static let orbitRadii: [Float] = [0, 0.96, 1.48, 1.98]
    static let pocketOrbitRadii: [Float] = [0, 2.9, 4.6, 6.4]
    static let pocketWorldRadius: Float = 7.0

    private static let goldenAngle: Float = Float.pi * (3 - sqrt(5))

    /// Position of a category anchor at the given angle (degrees).
    static func categoryPosition(angleDegrees angle: Float) -> SIMD3<Float> {
        let radians = angle * .pi / 180
        return SIMD3<Float>(
            cos(radians) * categoryRadiusX,
            sin(radians * 1.7) * 1.35,
            sin(radians) * categoryRadiusZ
        )
    }

    /// Default (non-pocket) tool position relative to its category anchor.
    static func toolPosition(
        angleDegrees angle: Float,
        orbit: OrbitRing,
        categoryAngleDegrees categoryAngle: Float
    ) -> SIMD3<Float> {
        guard orbit != .core else { return .zero }

        let cat = categoryPosition(angleDegrees: categoryAngle)
        let toolRad = angle * .pi / 180
        let radius = orbitRadii[orbit.rawValue]
        let verticalLift = sin(toolRad * 1.35 + categoryAngle * 0.03) * (0.48 + Float(orbit.rawValue) * 0.12)
        return SIMD3<Float>(
            cat.x + cos(toolRad) * radius,
            cat.y + verticalLift,
            cat.z + sin(toolRad) * radius * 0.78
        )
    }

    /// Pocket-world tool position: Fibonacci-sphere distribution with a
    /// 22 % blend of the tool's own angle so stage / relation groups stay
    /// visually clustered instead of fully randomised.
    static func pocketToolPosition(
        angleDegrees angle: Float,
        orbit: OrbitRing,
        categoryAngleDegrees categoryAngle: Float,
        slotIndex: Int,
        slotCount: Int
    ) -> SIMD3<Float> {
        guard orbit != .core else { return .zero }

        let cat = categoryPosition(angleDegrees: categoryAngle)
        let safeSlotCount = max(Float(slotCount), 1)

        let y: Float = 1 - (Float(slotIndex) + 0.5) * (2 / safeSlotCount)
        let yRadius = sqrt(max(0, 1 - y * y))
        let localRad = (angle - categoryAngle) * .pi / 180
        let phi = Float(slotIndex) * goldenAngle + localRad * 0.22

        let radius = pocketOrbitRadii[orbit.rawValue]
        return SIMD3<Float>(
            cat.x + cos(phi) * yRadius * radius,
            cat.y + y * radius * 0.62,
            cat.z + sin(phi) * yRadius * radius
        )
    }
}
