import Foundation
import RealityKit

/// Cosmic skybox backdrop (backlog 28): replaces the flat SwiftUI radial
/// gradient with real spatial depth. A large inverted sphere enclosing the
/// whole scene, textured with the same procedural equirectangular map that
/// drives image-based lighting (`CosmicEnvironmentTexture`) — so the
/// reflections on the PBR nodes and the visible background agree.
///
/// The sphere is rendered with an `UnlitMaterial` so the backdrop glows at a
/// fixed brightness independent of the key/fill rig, and it is inverted
/// (negative X scale) so the camera, sitting inside, sees the textured
/// interior rather than a back-face-culled shell. It sits beyond the star
/// field (120) so the stars read as a nearer layer against it. No collision
/// or input target — it can never steal a tap. The SwiftUI gradient stays as
/// a cheap fallback that only shows if texture generation fails.
@MainActor
enum SkyboxEntity {

    /// Outermost shell — beyond `StarFieldGeometry.shellRadius` (120) so the
    /// skybox is always the farthest layer.
    static let shellRadius: Float = 300

    /// Visible-backdrop texture resolution. Larger than the IBL probe
    /// (`CosmicEnvironmentTexture.defaultWidth`) because the skybox is seen
    /// directly and must not look mushy; still 2:1 equirectangular.
    static let textureHeight = 512
    static let textureWidth = 1024

    /// Builds the skybox entity, or nil if the texture can't be generated
    /// (caller keeps the gradient fallback).
    static func make() -> Entity? {
        guard let cgImage = CosmicEnvironmentTexture.makeEquirectangular(
            width: textureWidth,
            height: textureHeight
        ) else { return nil }

        guard let texture = try? TextureResource(
            image: cgImage,
            withName: "cosmic-skybox",
            options: .init(semantic: .color)
        ) else { return nil }

        var material = UnlitMaterial()
        material.color = .init(texture: .init(texture))

        let sphere = ModelEntity(
            mesh: .generateSphere(radius: shellRadius),
            materials: [material]
        )
        sphere.name = "skybox"
        // Invert so the inside faces the camera.
        sphere.scale = SIMD3<Float>(-1, 1, 1)
        return sphere
    }
}
