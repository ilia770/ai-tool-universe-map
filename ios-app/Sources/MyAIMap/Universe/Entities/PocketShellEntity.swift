import Foundation
import RealityKit
import UIKit

/// Translucent shell + two counter-rotating torus rings marking an open
/// pocket world — native port of the web `PocketWorldShell` (drei
/// Sparkles + HTML readout intentionally omitted; see the slice plan).
/// Fades in over `BrandMotion.flow`'s 0.36 s; with reduce-motion the
/// shell renders static at final opacity with no spins.
@MainActor
enum PocketShellEntity {

    /// Duration mirrors BrandMotion.flow (.smooth(duration: 0.36)) —
    /// Animation values aren't introspectable, so the literal lives here.
    static let fadeDuration: TimeInterval = 0.36

    static func make(category: ToolCategory, position: SIMD3<Float>, reduceMotion: Bool) -> Entity {
        let root = Entity()
        // Stable name so the persistent scene (UniverseView's update
        // closure) can find and swap the shell on category change.
        root.name = "pocket-shell"
        root.position = position

        let color = category.color.uiColor

        let shell = ModelEntity(
            mesh: .generateSphere(radius: UniverseLayout.pocketWorldRadius),
            materials: [material(color, opacity: PocketShellGeometry.shellOpacity)]
        )
        shell.scale = PocketShellGeometry.shellScale
        root.addChild(shell)

        let outer = ringEntity(
            radius: UniverseLayout.pocketWorldRadius,
            tube: PocketShellGeometry.outerTube,
            tubularSegments: 104,
            color: color,
            opacity: PocketShellGeometry.outerRingOpacity
        )
        // Web: rotation={[Math.PI / 2, 0, 0]} — lay the XY torus flat.
        outer.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
        root.addChild(outer)

        let inner = ringEntity(
            radius: UniverseLayout.pocketWorldRadius * PocketShellGeometry.innerRadiusFactor,
            tube: PocketShellGeometry.innerTube,
            tubularSegments: 88,
            color: .white,
            opacity: PocketShellGeometry.innerRingOpacity
        )
        inner.orientation = tiltRotation(PocketShellGeometry.innerRingTilt)
        root.addChild(inner)

        // Bright sparkle field filling the pocket volume (web drei
        // <Sparkles>). Local to the shell root, so it's centred on the
        // category position and rides the shell's add/remove lifecycle.
        root.addChild(SparkleFieldEntity.make(color: color, reduceMotion: reduceMotion))

        if !reduceMotion {
            fadeIn(root)
            spin(outer, radPerSec: PocketShellGeometry.outerSpinRadPerSec)
            spin(inner, radPerSec: PocketShellGeometry.innerSpinRadPerSec)
        }
        return root
    }

    // MARK: - Pieces

    private static func material(_ color: UIColor, opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

    private static func ringEntity(radius: Float, tube: Float, tubularSegments: Int, color: UIColor, opacity: Float) -> ModelEntity {
        let torus = PocketShellGeometry.torus(radius: radius, tube: tube, radialSegments: 8, tubularSegments: tubularSegments)
        var descriptor = MeshDescriptor(name: "pocket-ring")
        descriptor.positions = MeshBuffer(torus.positions)
        descriptor.normals = MeshBuffer(torus.normals)
        descriptor.primitives = .triangles(torus.indices)
        let mesh = (try? MeshResource.generate(from: [descriptor]))
            ?? .generateSphere(radius: tube) // unreachable fallback; generation of a valid descriptor cannot throw in practice
        return ModelEntity(mesh: mesh, materials: [material(color, opacity: opacity)])
    }

    /// Web parity: rotation order in three.js is XYZ Euler.
    private static func tiltRotation(_ euler: SIMD3<Float>) -> simd_quatf {
        let x = simd_quatf(angle: euler.x, axis: SIMD3<Float>(1, 0, 0))
        let y = simd_quatf(angle: euler.y, axis: SIMD3<Float>(0, 1, 0))
        let z = simd_quatf(angle: euler.z, axis: SIMD3<Float>(0, 0, 1))
        return x * y * z
    }

    private static func fadeIn(_ entity: Entity) {
        entity.components.set(OpacityComponent(opacity: 0))
        let fade = FromToByAnimation<Float>(
            from: 0,
            to: 1,
            duration: fadeDuration,
            timing: .easeOut,
            bindTarget: .opacity
        )
        if let resource = try? AnimationResource.generate(with: fade) {
            entity.playAnimation(resource)
        } else {
            entity.components.set(OpacityComponent(opacity: 1))
        }
    }

    /// Continuous spin about the ring's local Z (its symmetry axis):
    /// repeating relative π rotations sidestep quaternion shortest-arc.
    private static func spin(_ entity: Entity, radPerSec: Float) {
        let halfTurn = simd_quatf(angle: .pi * (radPerSec < 0 ? -1 : 1), axis: SIMD3<Float>(0, 0, 1))
        let spin = FromToByAnimation<Transform>(
            by: Transform(rotation: halfTurn),
            duration: TimeInterval(Float.pi / abs(radPerSec)),
            timing: .linear,
            bindTarget: .transform,
            repeatMode: .repeat
        )
        if let resource = try? AnimationResource.generate(with: spin) {
            entity.playAnimation(resource)
        }
    }
}
