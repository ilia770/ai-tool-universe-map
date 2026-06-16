import CoreGraphics
import simd

/// Pure camera→screen projection for the overlay. No RealityKit / SwiftUI.
enum UniverseProjection {
    struct Camera: Sendable, Equatable {
        var eye: SIMD3<Float>
        var target: SIMD3<Float>
        var up: SIMD3<Float>
        var verticalFOV: Float          // radians
        var viewport: CGSize
    }

    struct Projected: Sendable, Equatable {
        var point: CGPoint              // screen-space px
        var depthScale: Float           // 1.0 at reference depth; >1 closer, <1 farther
        var parallax: CGSize            // additive screen offset from depth
    }

    /// Reference distance at which depthScale == 1 (mid-scene).
    static let referenceDistance: Float = 18

    static func project(_ world: SIMD3<Float>, camera c: Camera) -> Projected? {
        // View basis (right, up, forward) — matches CameraController.lookRotation convention.
        let forward = simd_normalize(c.target - c.eye)
        let right = simd_normalize(simd_cross(forward, c.up))
        let trueUp = simd_cross(right, forward)
        let rel = world - c.eye
        let z = simd_dot(rel, forward)          // depth along view dir
        guard z > 0.001 else { return nil }     // behind / on camera plane
        let x = simd_dot(rel, right)
        let y = simd_dot(rel, trueUp)
        let h = Float(c.viewport.height)
        let w = Float(c.viewport.width)
        let f = (h * 0.5) / tan(c.verticalFOV * 0.5)   // focal length in px
        let sx = w * 0.5 + (x / z) * f
        let sy = h * 0.5 - (y / z) * f
        let depthScale = referenceDistance / z
        // Parallax: lateral world offset scaled by depth, capped.
        let par = CGSize(width: CGFloat(x * (depthScale - 1) * 0.04),
                         height: CGFloat(y * (depthScale - 1) * 0.04))
        return Projected(point: CGPoint(x: CGFloat(sx), y: CGFloat(sy)),
                         depthScale: depthScale, parallax: par)
    }
}
