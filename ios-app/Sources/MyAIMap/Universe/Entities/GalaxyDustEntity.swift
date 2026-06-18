import Foundation
import RealityKit
import UIKit

/// Sparse ambient cosmic-haze layer — a static cloud of large, very faint
/// translucent blobs at a MID shell radius (closer than the star field, well
/// outside the camera's playable volume), adding depth between the near node
/// cloud and the far stars. Native port of the web `GalaxyDust.tsx` in
/// spirit: far fewer, far larger, far softer, far dimmer than the stars. No
/// per-frame animation in this slice (the web layer's slow drift is a later
/// polish).
///
/// As with the star field, RealityKit has no soft-sprite/point primitive, so
/// each blob is a sphere ModelEntity at a `GalaxyDustGeometry` position. ONE
/// MeshResource and ONE UnlitMaterial are built and shared across every
/// child — only the lightweight Entity wrappers and transforms differ. Dust
/// carries no InputTargetComponent or collision, so it can never steal a tap.
///
/// v1 LIMITATION: large transparent overlapping spheres can read as hard
/// translucent balls rather than soft haze — true soft sprites need a
/// billboarded textured quad or a particle system, deferred to the
/// sparkles/particle slice. The opacity is kept very low
/// (GalaxyDustGeometry.opacity) so the layer reads as faint depth and the
/// hard edges stay subtle.
@MainActor
enum GalaxyDustEntity {

    /// Category-agnostic deep blue-violet cosmic tint — a neutral haze color
    /// that sits behind every category's hue without competing with it.
    private static let dustColor = UIColor(red: 0.4, green: 0.35, blue: 0.7, alpha: 1)

    static func make() -> Entity {
        let root = Entity()
        root.name = "galaxy-dust"

        // One shared mesh + material across all blobs (see type doc — reuse
        // is the whole point of the sphere-instancing approach).
        let mesh = MeshResource.generateSphere(radius: GalaxyDustGeometry.spriteRadius)
        let dustMaterial = material(opacity: GalaxyDustGeometry.opacity)

        for position in GalaxyDustGeometry.positions() {
            let blob = ModelEntity(mesh: mesh, materials: [dustMaterial])
            blob.position = position
            root.addChild(blob)
        }

        return root
    }

    /// Unlit so the haze glows at a fixed faint brightness independent of the
    /// scene's key/fill lighting rig.
    private static func material(opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: dustColor)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }
}
