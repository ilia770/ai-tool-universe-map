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
    static func makePlanet(
        data: PlanetData,
        isSelected: Bool,
        visualizationStyle: VisualizationStyle,
        reduceMotion: Bool
    ) -> Entity {
        let root = Entity()
        root.name = "planet-root:\(data.id.rawValue)"
        root.position = data.position3D
        let radius: Float
        if data.id == .core {
            radius = data.radius * 0.54
        } else {
            radius = data.radius * visualizationStyle.categoryScale * (isSelected ? 1.44 : 0.92)
        }

        let planet = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [planetMaterial(data: data, isSelected: isSelected, visualizationStyle: visualizationStyle)]
        )
        planet.name = "planet:\(data.id.rawValue)"
        configureTap(on: planet, radius: max(radius * 1.45, 0.95))
        root.addChild(planet)

        let atmosphere = ModelEntity(
            mesh: .generateSphere(radius: radius * (isSelected ? 1.20 : 1.12)),
            materials: [atmosphereMaterial(data: data, isSelected: isSelected, visualizationStyle: visualizationStyle)]
        )
        atmosphere.name = "atmosphere:\(data.id.rawValue)"
        root.addChild(atmosphere)

        if data.id != .core || isSelected {
            let rim = makeOrbitLine(
                radius: radius * (isSelected ? 1.30 : 1.18),
                tube: isSelected ? 0.012 : 0.007,
                color: data.accentUIColor,
                opacity: (isSelected ? 0.24 : 0.052) * visualizationStyle.glowBoost
            )
            rim.orientation = simd_quatf(angle: .pi / 2.7, axis: SIMD3<Float>(1, 0, 0))
            root.addChild(rim)
        }

        if !reduceMotion {
            spin(planet, axis: SIMD3<Float>(0.18, 1, 0.08), duration: isSelected ? 18 : 30)
            if isSelected {
                pulse(atmosphere, baseScale: atmosphere.scale, duration: 2.4)
            }
        }
        return root
    }

    static func makeSatellite(
        tool: Tool,
        category: ToolCategory,
        index: Int,
        count: Int,
        isSelected: Bool,
        visualizationStyle: VisualizationStyle,
        reduceMotion: Bool
    ) -> Entity {
        let root = Entity()
        root.name = "satellite-root:\(tool.id)"
        root.position = UniverseSpatialLayout.satelliteOffset(index: index, count: count, orbit: tool.orbit)

        let radius: Float = (isSelected ? 0.29 : 0.20) * visualizationStyle.nodeScale
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: mix(category.color.uiColor, with: .white, amount: isSelected ? 0.34 : 0.18))
        material.roughness = .init(floatLiteral: 0.42)
        material.metallic = .init(floatLiteral: 0.08)
        material.emissiveColor = .init(color: category.glow.uiColor)
        material.emissiveIntensity = (isSelected ? 1.2 : 0.38) * visualizationStyle.glowBoost

        let body = ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
        body.name = "tool:\(tool.id)"
        configureTap(on: body, radius: max(radius * 2.2, 0.44))
        root.addChild(body)

        let halo = ModelEntity(
            mesh: .generateSphere(radius: radius * (isSelected ? 1.34 : 1.22)),
            materials: [unlitGlow(color: category.glow.uiColor, opacity: isSelected ? 0.16 : 0.055)]
        )
        root.addChild(halo)

        if isSelected {
            let ring = makeOrbitLine(
                radius: radius * 1.78,
                tube: 0.006,
                color: category.glow.uiColor,
                opacity: 0.42 * visualizationStyle.glowBoost
            )
            ring.orientation = simd_quatf(angle: .pi / 2.35, axis: SIMD3<Float>(1, 0, 0))
                * simd_quatf(angle: .pi / 8, axis: SIMD3<Float>(0, 1, 0))
            root.addChild(ring)
        }

        if !reduceMotion {
            spin(body, axis: SIMD3<Float>(0, 1, 0), duration: 12 + Double(index % 4) * 2)
        }
        return root
    }

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

    static func makeStar(index: Int) -> ModelEntity {
        let radius = Float(0.008 + Double(index % 4) * 0.004)
        let color: UIColor = index.isMultiple(of: 9)
            ? UIColor(red: 0.55, green: 0.86, blue: 1, alpha: 1)
            : .white
        let star = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [unlitGlow(color: color, opacity: Float(0.28 + Double(index % 5) * 0.08))]
        )
        star.position = starPosition(index: index)
        return star
    }

    private static func planetMaterial(
        data: PlanetData,
        isSelected: Bool,
        visualizationStyle: VisualizationStyle
    ) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: mix(data.uiColor, with: .black, amount: data.id == .core ? 0.06 : isSelected ? 0.16 : 0.32))
        material.roughness = .init(floatLiteral: data.id == .core ? 0.26 : isSelected ? 0.36 : 0.52)
        material.metallic = .init(floatLiteral: data.id == .core ? 0.18 : 0.06)
        material.emissiveColor = .init(color: data.accentUIColor)
        material.emissiveIntensity = (data.id == .core ? 1.15 : isSelected ? 0.86 : 0.26) * visualizationStyle.glowBoost
        material.clearcoat = .init(floatLiteral: isSelected ? 0.52 : 0.28)
        material.clearcoatRoughness = .init(floatLiteral: 0.24)
        return material
    }

    private static func atmosphereMaterial(
        data: PlanetData,
        isSelected: Bool,
        visualizationStyle: VisualizationStyle
    ) -> UnlitMaterial {
        let baseOpacity: Float = data.id == .core ? 0.12 : isSelected ? 0.16 : 0.035
        return unlitGlow(color: data.accentUIColor, opacity: baseOpacity * visualizationStyle.glowBoost)
    }

    private static func unlitGlow(color: UIColor, opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: color)
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

    private static func makeOrbitLine(radius: Float, tube: Float, color: UIColor, opacity: Float) -> ModelEntity {
        let torus = PocketShellGeometry.torus(radius: radius, tube: tube, radialSegments: 6, tubularSegments: 128)
        var descriptor = MeshDescriptor(name: "universe-orbit")
        descriptor.positions = MeshBuffer(torus.positions)
        descriptor.normals = MeshBuffer(torus.normals)
        descriptor.primitives = .triangles(torus.indices)
        let mesh = (try? MeshResource.generate(from: [descriptor])) ?? .generateSphere(radius: tube)
        return ModelEntity(mesh: mesh, materials: [unlitGlow(color: color, opacity: opacity)])
    }

    private static func configureTap(on entity: ModelEntity, radius: Float) {
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

    private static func mix(_ first: UIColor, with second: UIColor, amount: CGFloat) -> UIColor {
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

    private static func spin(_ entity: Entity, axis: SIMD3<Float>, duration: TimeInterval) {
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

    private static func pulse(_ entity: Entity, baseScale: SIMD3<Float>, duration: TimeInterval) {
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
