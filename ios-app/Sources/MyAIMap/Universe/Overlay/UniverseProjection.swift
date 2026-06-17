import Foundation
import simd
import CoreGraphics

// MARK: - CameraState

/// Snapshot of the camera's current position and orbit angles, consumed
/// by `UniverseProjection` to map 3D world points to 2D screen points.
/// Pure value type; no RealityKit or SwiftUI dependency.
struct CameraState: Sendable {
    var eye: SIMD3<Float>
    var target: SIMD3<Float>
    var fovYRadians: Float
    var orbitYaw: Float
    var orbitPitch: Float
}

// MARK: - ProjectedNode

/// Result of projecting a single world-space node onto the screen.
struct ProjectedNode: Sendable {
    /// 2D screen position (origin = top-left, Y grows downward).
    var screen: CGPoint
    /// Depth-based size scale: >1 when close, <1 when far, clamped to [0.6, 1.6].
    var depthScale: CGFloat
    /// Small screen-space shear from orbit yaw/pitch × (1 − depthScale).
    var parallax: CGSize
    /// False when the point is on or behind the near plane (w ≤ 0).
    var isVisible: Bool
}

// MARK: - UniverseProjection

/// Pure math projector: maps a 3D world point + camera state onto a 2D
/// screen point, depth scale, and parallax offset.
///
/// Imports: Foundation, simd, CoreGraphics only — no RealityKit, no SwiftUI.
/// Swift 6 strict-concurrency: all methods are nonisolated and operate on
/// Sendable value types.
enum UniverseProjection {

    // MARK: - Constants

    /// Reference distance at which depthScale == 1. Derived from the
    /// web build's overview framing (eye ≈ 19.5 units from origin, near
    /// pocket/node at ~1–5 units away → midpoint ~18).
    private static let referenceDistance: Float = 18.0

    /// Depth-scale band: near nodes appear bigger, far nodes smaller.
    private static let minDepthScale: CGFloat = 0.6
    private static let maxDepthScale: CGFloat = 1.6

    /// Parallax strength multiplier (tunable).  Keeps shear subtle.
    private static let parallaxStrength: CGFloat = 40.0

    // MARK: - Public API

    /// Project `world` into screen coordinates for `viewport`.
    ///
    /// Algorithm:
    /// 1. Build a look-at view matrix from `camera.eye` and `camera.target`.
    /// 2. Build a perspective matrix from `camera.fovYRadians` and the
    ///    viewport aspect ratio (near=0.1, far=1000).
    /// 3. Transform the world point into clip space; divide by w (perspective
    ///    divide); map NDC to screen coords (flip Y so +Y is down on screen).
    /// 4. Return `isVisible=false` when w ≤ 0 (point is behind the camera).
    static func project(
        world: SIMD3<Float>,
        camera: CameraState,
        viewport: CGSize
    ) -> ProjectedNode {

        let view = makeViewMatrix(eye: camera.eye, target: camera.target)
        let proj = makePerspectiveMatrix(
            fovYRadians: camera.fovYRadians,
            aspect: Float(viewport.width / viewport.height),
            near: 0.1,
            far: 1000.0
        )
        let vp = proj * view

        // World point in homogeneous coords.
        let pw = SIMD4<Float>(world.x, world.y, world.z, 1)
        let clip = vp * pw

        // Behind (or on) the near plane.
        guard clip.w > 0 else {
            return ProjectedNode(
                screen: .zero,
                depthScale: 1,
                parallax: .zero,
                isVisible: false
            )
        }

        // Perspective divide → NDC in [-1, 1].
        let ndcX = clip.x / clip.w
        let ndcY = clip.y / clip.w

        // NDC to screen (origin top-left, Y flipped).
        let sx = CGFloat((ndcX + 1) * 0.5) * viewport.width
        let sy = CGFloat((1 - (ndcY + 1) * 0.5)) * viewport.height

        // Depth scale based on distance from eye.
        let dist = simd_length(world - camera.eye)
        let scale = depthScale(distance: dist)

        // Parallax: small screen-space shear from orbit yaw/pitch.
        // Far layers (scale < 1) drift less; near (scale > 1) drift more.
        let parallaxFactor = (1.0 - scale) * parallaxStrength
        let px = CGFloat(camera.orbitYaw) * parallaxFactor
        let py = CGFloat(camera.orbitPitch) * parallaxFactor

        return ProjectedNode(
            screen: CGPoint(x: sx, y: sy),
            depthScale: scale,
            parallax: CGSize(width: px, height: py),
            isVisible: true
        )
    }

    /// Depth scale for a node at `distance` from the camera eye.
    /// Returns values in [0.6, 1.6]: near → bigger, far → smaller.
    static func depthScale(distance: Float) -> CGFloat {
        let ratio = CGFloat(referenceDistance) / CGFloat(max(distance, 1e-6))
        return min(max(ratio, minDepthScale), maxDepthScale)
    }

    // MARK: - Private matrix helpers

    /// Standard look-at view matrix (column-major, right-handed).
    /// Camera looks down -Z. Matches `CameraController.lookRotation` basis:
    /// back = normalize(eye - target), right = cross(worldUp, back), up = cross(back, right).
    private static func makeViewMatrix(
        eye: SIMD3<Float>,
        target: SIMD3<Float>
    ) -> simd_float4x4 {
        let offset = eye - target
        let back: SIMD3<Float>
        if simd_length(offset) > 1e-6 {
            back = simd_normalize(offset)
        } else {
            back = SIMD3<Float>(0, 0, 1)
        }

        let worldUp = SIMD3<Float>(0, 1, 0)
        var right = simd_cross(worldUp, back)
        if simd_length(right) < 1e-6 {
            right = SIMD3<Float>(1, 0, 0)
        } else {
            right = simd_normalize(right)
        }
        let up = simd_cross(back, right)

        // View matrix = rotation^T * translation(-eye)
        let rx = simd_dot(right, eye)
        let ry = simd_dot(up, eye)
        let rz = simd_dot(back, eye)

        return simd_float4x4(columns: (
            SIMD4<Float>(right.x, up.x, back.x, 0),
            SIMD4<Float>(right.y, up.y, back.y, 0),
            SIMD4<Float>(right.z, up.z, back.z, 0),
            SIMD4<Float>(-rx,     -ry,   -rz,   1)
        ))
    }

    /// Standard OpenGL-style symmetric perspective projection matrix
    /// (column-major, right-handed, maps depth to [-1, 1]).
    private static func makePerspectiveMatrix(
        fovYRadians: Float,
        aspect: Float,
        near: Float,
        far: Float
    ) -> simd_float4x4 {
        let f = 1.0 / tan(fovYRadians * 0.5)
        let rangeInv = 1.0 / (near - far)

        return simd_float4x4(columns: (
            SIMD4<Float>(f / aspect, 0,  0,                          0),
            SIMD4<Float>(0,          f,  0,                          0),
            SIMD4<Float>(0,          0,  (far + near) * rangeInv,   -1),
            SIMD4<Float>(0,          0,  2 * far * near * rangeInv,  0)
        ))
    }
}
