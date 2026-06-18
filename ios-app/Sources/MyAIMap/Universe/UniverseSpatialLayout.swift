import Foundation
import simd

/// Shared spatial math for RealityKit entities and SwiftUI overlays.
///
/// Keeping satellite positions here lets labels, connector beams, and hit
/// targets line up with the actual 3D nodes. When generated spheres are
/// replaced with USDZ/Spline assets later, keep this contract stable.
enum UniverseSpatialLayout {
    static let categoryOrbitX: Float = 6.2
    static let categoryOrbitZ: Float = 4.75

    private static let categoryAngles: [ToolCategoryId: Float] = [
        .coding: -150,
        .design: -105,
        .research: -60,
        .analytics: -15,
        .media: 30,
        .distribution: 75,
        .infrastructure: 120,
        .knowledge: 165,
    ]

    static func categoryPosition(
        for category: ToolCategory,
        branchIndex: Int,
        branchCount: Int
    ) -> SIMD3<Float> {
        let fallbackStep = Float.pi * 2 / Float(max(branchCount, 1))
        let fallbackAngle = -Float.pi * 0.84 + Float(branchIndex) * fallbackStep
        let radians = (categoryAngles[category.id] ?? (fallbackAngle * 180 / .pi)) * .pi / 180
        return SIMD3<Float>(
            cos(radians) * categoryOrbitX,
            sin(radians * 1.36) * 0.84,
            sin(radians) * categoryOrbitZ
        )
    }

    static func satelliteOffset(index: Int, count: Int, orbit: OrbitRing) -> SIMD3<Float> {
        let safeCount = max(count, 1)
        let step = Float.pi * 2 / Float(safeCount)
        let angle = Float(index) * step + Float(orbit.rawValue) * 0.72 - .pi * 0.14
        let radius = 1.82 + Float(orbit.rawValue) * 0.62
        let vertical = sin(angle * 1.5) * 0.34
        return SIMD3<Float>(cos(angle) * radius, vertical, sin(angle) * radius * 0.82)
    }

    static func satelliteWorldPosition(
        for tool: Tool,
        in planet: PlanetData,
        index: Int,
        count: Int
    ) -> SIMD3<Float> {
        planet.position3D + satelliteOffset(index: index, count: count, orbit: tool.orbit)
    }
}
