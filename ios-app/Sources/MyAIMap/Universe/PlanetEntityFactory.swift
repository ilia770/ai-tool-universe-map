import Foundation
import RealityKit
import UIKit

/// Procedural RealityKit entities for the universe.
///
/// Generated spheres keep the prototype dependency-free. Later, replace the
/// `ModelEntity(mesh: .generateSphere(...))` calls with `Entity(named:)` USDZ
/// assets or Spline-exported Reality files while keeping the same names and
/// collision setup so taps/camera behavior continue to work.
@MainActor
enum PlanetEntityFactory {
    // NOTE: the one-shot `makePlanet(data:isSelected:...)` builder was replaced
    // by the persistent `PlanetHandle` (created once per category id, mutated on
    // selection/mode change) — see PlanetHandle.swift and UNIVERSE_ARCHITECTURE.md.

    // NOTE: the one-shot `makeSatellite(tool:isSelected:...)` builder was
    // replaced by the persistent `SatelliteHandle` (SatelliteBranch.swift).

    static func makeSatelliteOrbitShell(
        radius: Float,
        category: ToolCategory,
        visualizationStyle: VisualizationStyle,
        reduceMotion: Bool
    ) -> Entity {
        let root = Entity()
        root.name = "satellite-orbits:\(category.id.rawValue)"

        for index in 0..<3 {
            let ring = makeOrbitLine(
                radius: radius * visualizationStyle.nodeScale * (0.56 + Float(index) * 0.2),
                tube: 0.005,
                color: category.glow.uiColor,
                opacity: (0.085 - Float(index) * 0.016) * visualizationStyle.glowBoost
            )
            ring.orientation = simd_quatf(angle: .pi / 2 + Float(index) * 0.22, axis: SIMD3<Float>(1, 0, 0))
                * simd_quatf(angle: Float(index) * 0.52, axis: SIMD3<Float>(0, 1, 0))
            root.addChild(ring)
        }

        if !reduceMotion {
            spin(root, axis: SIMD3<Float>(0, 1, 0), duration: 32)
        }
        return root
    }

    static func makeUniverseOrbit(radius: Float, color: UIColor, opacity: Float, tilt: Float = 0) -> ModelEntity {
        let ring = makeOrbitLine(radius: radius, tube: 0.006, color: color, opacity: opacity)
        ring.orientation = simd_quatf(angle: .pi / 2 + tilt, axis: SIMD3<Float>(1, 0, 0))
            * simd_quatf(angle: tilt * 0.7, axis: SIMD3<Float>(0, 1, 0))
        return ring
    }

    /// RK.3 mesh caches — geometry is shared and entities scale it, instead of
    /// regenerating a sphere/torus per node (audit: ~250+ mesh allocations per
    /// scene before this).
    static let unitSphere = MeshResource.generateSphere(radius: 1)

    /// Torus meshes keyed by quantized (radius, tube). Orbit shells and rims
    /// with identical parameters share one MeshResource.
    private static var torusCache: [String: MeshResource] = [:]

    static func torusMesh(radius: Float, tube: Float) -> MeshResource {
        let key = "\(Int((radius * 10_000).rounded()))x\(Int((tube * 10_000).rounded()))"
        if let cached = torusCache[key] { return cached }
        let torus = PocketShellGeometry.torus(radius: radius, tube: tube, radialSegments: 6, tubularSegments: 128)
        var descriptor = MeshDescriptor(name: "universe-orbit")
        descriptor.positions = MeshBuffer(torus.positions)
        descriptor.normals = MeshBuffer(torus.normals)
        descriptor.primitives = .triangles(torus.indices)
        let mesh = (try? MeshResource.generate(from: [descriptor])) ?? .generateSphere(radius: tube)
        torusCache[key] = mesh
        return mesh
    }

    /// Shared unit-box mesh for every structural link, reused across the one
    /// transform + material so links keep allocations down.
    private static let linkMesh = MeshResource.generateBox(size: 1)

    /// A static structural connection line (core→category, category→tool) drawn
    /// as a thin box stretched/oriented via `LinkGeometry`. UnlitMaterial so it
    /// reads the same regardless of the lighting rig. NOT tappable (no
    /// InputTargetComponent/collision) so a link never steals a tap from the
    /// node under it.
    static func makeLink(
        from: SIMD3<Float>,
        to: SIMD3<Float>,
        color: UIColor,
        opacity: Float,
        thickness: Float,
        name: String
    ) -> ModelEntity {
        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        let link = ModelEntity(mesh: linkMesh, materials: [material])
        link.name = name

        let t = LinkGeometry.transform(from: from, to: to, thickness: thickness)
        link.position = t.position
        link.scale = t.scale
        link.orientation = t.rotation
        return link
    }

    static let founderHaloRadius: Float = 1.2
    static let founderHaloOpacity: Float = 0.12
    static let founderHaloBreathScale: Float = 0.06
    static let founderHaloBreathDuration: TimeInterval = 2.6

    /// Frosted translucent PBR shell around the central Founder OS core so it
    /// reads as the scene's hero. Slow breathing scale unless Reduce Motion.
    static func makeFounderHalo(reduceMotion: Bool) -> ModelEntity {
        let coreColor = UniverseSeed.category(.core).color.uiColor
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: coreColor)
        material.roughness = .init(floatLiteral: 0.85)
        material.metallic = .init(floatLiteral: 0.0)
        material.blending = .transparent(opacity: .init(floatLiteral: founderHaloOpacity))
        material.emissiveColor = .init(color: coreColor)
        material.emissiveIntensity = 0.4

        let halo = ModelEntity(mesh: unitSphere, materials: [material])
        halo.scale = SIMD3<Float>(repeating: founderHaloRadius)
        halo.name = "founder-halo"
        halo.position = .zero

        if !reduceMotion {
            breathe(halo)
        }
        return halo
    }

    /// (Re)start the halo's slow breathing clip. Split out so the persistent
    /// scene can pause/resume the same halo entity instead of rebuilding it.
    static func breathe(_ halo: ModelEntity) {
        var base = halo.transform
        base.scale = SIMD3<Float>(repeating: founderHaloRadius)
        var peak = base
        peak.scale = SIMD3<Float>(repeating: founderHaloRadius * (1 + founderHaloBreathScale))
        let breathe = FromToByAnimation<Transform>(
            from: base,
            to: peak,
            duration: founderHaloBreathDuration,
            timing: .easeInOut,
            bindTarget: .transform,
            repeatMode: .autoReverse
        )
        if let resource = try? AnimationResource.generate(with: breathe) {
            halo.playAnimation(resource)
        }
    }

    // A soft point light tinted to the category, parented at the sun so its
    // tool-planets are lit from their star.
    static func makeSunLight(data: PlanetData, intensity: Float) -> PointLight {
        let light = PointLight()
        light.light.color = data.accentUIColor
        light.light.intensity = intensity
        light.light.attenuationRadius = 9.5
        light.name = "sun-light:\(data.id.rawValue)"
        return light
    }

    /// Four opacity tiers → four shared materials; every star shares the unit
    /// sphere mesh and scales it (was: 120 individual mesh+material allocations).
    private static let starMaterials: [UnlitMaterial] = (0..<4).map { tier in
        unlitGlow(color: UIColor(white: 1, alpha: 1), opacity: Float(0.08 + Double(tier) * 0.025))
    }

    static func makeStar(index: Int) -> ModelEntity {
        let radius = Float(0.004 + Double(index % 3) * 0.002)
        let star = ModelEntity(mesh: unitSphere, materials: [starMaterials[index % 4]])
        star.scale = SIMD3<Float>(repeating: radius)
        star.position = starPosition(index: index)
        return star
    }

    static func planetMaterial(
        data: PlanetData,
        isSelected: Bool,
        visualizationStyle: VisualizationStyle
    ) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: mix(data.uiColor, with: .black, amount: data.id == .core ? 0.06 : isSelected ? 0.16 : 0.32))
        // RK.5: per-category surface (one rendering language, parameter-level
        // variation — VISUAL_SYSTEM §2). Core keeps its emissive-ceramic look.
        let visual = PlanetVisual.descriptor(for: data.id)
        material.roughness = .init(floatLiteral: data.id == .core ? 0.26 : visual.roughness * (isSelected ? 0.75 : 1))
        material.metallic = .init(floatLiteral: data.id == .core ? 0.18 : visual.metallic)
        material.emissiveColor = .init(color: data.accentUIColor)
        material.emissiveIntensity = (data.id == .core ? 1.15 : isSelected ? 1.05 : 0.58) * visualizationStyle.glowBoost
        material.clearcoat = .init(floatLiteral: isSelected ? 0.52 : 0.45)
        material.clearcoatRoughness = .init(floatLiteral: 0.14)
        return material
    }

    static func atmosphereMaterial(
        data: PlanetData,
        isSelected: Bool,
        visualizationStyle: VisualizationStyle
    ) -> UnlitMaterial {
        let baseOpacity: Float = data.id == .core ? 0.12 : isSelected ? 0.16 : 0.035
        return unlitGlow(color: data.accentUIColor, opacity: baseOpacity * visualizationStyle.glowBoost)
    }

    static func unlitGlow(color: UIColor, opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

    static func makeOrbitLine(radius: Float, tube: Float, color: UIColor, opacity: Float) -> ModelEntity {
        let mesh = torusMesh(radius: radius, tube: tube)

        // G2: thin transparent orbit rings z-fought / poked through the opaque
        // planet body at its silhouette edges, where the ring crosses in front
        // of and behind the sphere at near-equal depth. A transparent ring must
        // never write depth (it would fight the planet's own depth and clip the
        // body), but must still READ depth so the half of the ring that passes
        // behind the planet is correctly occluded. So: readsDepth on (default),
        // writesDepth off → rings always pass cleanly behind the planet.
        var material = unlitGlow(color: color, opacity: opacity)
        material.writesDepth = false
        return ModelEntity(mesh: mesh, materials: [material])
    }

    static func configureTap(on entity: ModelEntity, radius: Float) {
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: radius)]))
        entity.components.set(HoverEffectComponent())
    }

    private static func starPosition(index: Int) -> SIMD3<Float> {
        let seed = Float(index)
        let angle = seed * 2.3999632
        let radius = 12 + fmod(seed * 5.37, 15)
        let height = -7 + fmod(seed * 3.11, 14)
        return SIMD3<Float>(
            cos(angle) * radius,
            height,
            sin(angle) * radius - 8
        )
    }

    static func mix(_ first: UIColor, with second: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0
        first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let keep = 1 - amount
        return UIColor(
            red: r1 * keep + r2 * amount,
            green: g1 * keep + g2 * amount,
            blue: b1 * keep + b2 * amount,
            alpha: 1
        )
    }

    static func spin(_ entity: Entity, axis: SIMD3<Float>, duration: TimeInterval) {
        let halfTurn = simd_quatf(angle: .pi, axis: simd_normalize(axis))
        let spin = FromToByAnimation<Transform>(
            by: Transform(rotation: halfTurn),
            duration: duration / 2,
            timing: .linear,
            bindTarget: .transform,
            repeatMode: .repeat
        )
        if let resource = try? AnimationResource.generate(with: spin) {
            entity.playAnimation(resource)
        }
    }

    static func pulse(_ entity: Entity, baseScale: SIMD3<Float>, duration: TimeInterval) {
        let pulse = FromToByAnimation<Transform>(
            from: Transform(scale: baseScale * 0.96),
            to: Transform(scale: baseScale * 1.08),
            duration: duration,
            timing: .easeInOut,
            bindTarget: .transform,
            repeatMode: .autoReverse
        )
        if let resource = try? AnimationResource.generate(with: pulse) {
            entity.playAnimation(resource)
        }
    }
}
