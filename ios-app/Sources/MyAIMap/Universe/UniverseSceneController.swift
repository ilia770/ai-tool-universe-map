import Foundation
import RealityKit
import UIKit

/// Owns the RealityKit entity graph for the AI Universe Map.
@MainActor
final class UniverseSceneController {
    private let root = Entity()
    private let planetRoot = Entity()
    private let orbitRoot = Entity()
    private let starRoot = Entity()
    private let satelliteRoot = Entity()
    private let lightRoot = Entity()
    private let camera = PerspectiveCamera()

    private var sceneSignature = ""
    func makeScene(
        planets: [PlanetData],
        mode: UniverseMode,
        visualizationStyle: VisualizationStyle,
        cameraRig: CameraRigController,
        reduceMotion: Bool
    ) -> Entity {
        root.name = "ai-universe-root"
        planetRoot.name = "planet-root"
        orbitRoot.name = "orbit-root"
        starRoot.name = "star-root"
        satelliteRoot.name = "satellite-root"
        lightRoot.name = "light-root"

        if root.children.isEmpty {
            root.addChild(starRoot)
            root.addChild(orbitRoot)
            root.addChild(planetRoot)
            root.addChild(satelliteRoot)
            root.addChild(lightRoot)
            root.addChild(camera)
            addLights()
            addStars()
            addBackdropAndIBL()
        }

        // G1 (empty 3D scene on return): `sceneController` is `@State` and so
        // outlives the `RealityView`. Toggling render mode (3D → 2D/chat/detail
        // → 3D) tears down `UniverseRealityView` and builds a fresh one, whose
        // `make` closure calls `makeScene` again. The persisted entity graph no
        // longer participates in the new `RealityView`'s content as built, so
        // the scene came back empty (only a couple of stray static rings, no
        // planet/satellites). Re-attach the camera to the new content's render
        // pass and force a from-scratch rebuild of the dynamic graph every time
        // the scene mounts, by invalidating the rebuild gate. `update`/`F3` edits
        // keep using the signature gate so steady-state frames stay cheap.
        cameraRig.attach(camera)
        sceneSignature = ""

        rebuildIfNeeded(
            planets: planets,
            mode: mode,
            visualizationStyle: visualizationStyle,
            reduceMotion: reduceMotion
        )
        return root
    }

    func update(
        planets: [PlanetData],
        mode: UniverseMode,
        visualizationStyle: VisualizationStyle,
        reduceMotion: Bool
    ) {
        rebuildIfNeeded(
            planets: planets,
            mode: mode,
            visualizationStyle: visualizationStyle,
            reduceMotion: reduceMotion
        )
    }

    func target(from entity: Entity) -> UniverseSceneTarget? {
        var current: Entity? = entity
        while let candidate = current {
            if candidate.name.hasPrefix("planet:") {
                let raw = String(candidate.name.dropFirst("planet:".count))
                // `ToolCategoryId` is now a non-failable string wrapper; the
                // entity-name prefix already guarantees this is a planet id.
                return .planet(ToolCategoryId(rawValue: raw))
            }
            if candidate.name.hasPrefix("tool:") {
                return .tool(String(candidate.name.dropFirst("tool:".count)))
            }
            current = candidate.parent
        }
        return nil
    }

    /// Cache key deciding whether the RealityKit scene must be rebuilt. Must
    /// encode every input that changes what is drawn.
    ///
    /// F3 (deleted tool reappears in 3D): the satellites (tool nodes) are built
    /// from each planet's actual tools, but the key previously used only the
    /// per-planet `toolCount`. Deleting a tool while adding another in the same
    /// category (or any edit that preserves per-category counts) left the key
    /// unchanged, so the scene never rebuilt and the removed tool's satellite
    /// persisted. Encode the actual tool ids so any change to the visible tool
    /// set forces a rebuild. `visibleAllTools` already filters hidden/removed
    /// tools upstream, so a removed tool drops out of this key immediately.
    static func sceneSignature(
        planets: [PlanetData],
        mode: UniverseMode,
        visualizationStyle: VisualizationStyle,
        reduceMotion: Bool
    ) -> String {
        [
            mode.signature,
            visualizationStyle.rawValue,
            planets.map { planet in
                "\(planet.id.rawValue):\(planet.tools.map(\.id).joined(separator: ","))"
            }.joined(separator: "|"),
            reduceMotion ? "reduce" : "motion",
        ].joined(separator: "#")
    }

    private func rebuildIfNeeded(
        planets: [PlanetData],
        mode: UniverseMode,
        visualizationStyle: VisualizationStyle,
        reduceMotion: Bool
    ) {
        let signature = Self.sceneSignature(
            planets: planets,
            mode: mode,
            visualizationStyle: visualizationStyle,
            reduceMotion: reduceMotion
        )
        guard signature != sceneSignature else { return }
        sceneSignature = signature
        clearDynamicChildren()

        // Pause ambient spin/pulse when the universe is only a dimmed backdrop
        // (detail/chat); honor Reduce Motion the same way.
        let pauseMotion = reduceMotion || mode.pausesAmbientMotion

        for ring in orbitRings(for: visualizationStyle) {
            let ring = PlanetEntityFactory.makeUniverseOrbit(
                radius: ring.radius,
                color: UIColor(white: 1, alpha: 1),
                opacity: ring.opacity * mode.orbitOpacityMultiplier,
                tilt: ring.tilt
            )
            orbitRoot.addChild(ring)
        }

        for planet in planets {
            let isSelected = mode.isPrimaryPlanet(planet.id)
            let entity = PlanetEntityFactory.makePlanet(
                data: planet,
                isSelected: isSelected,
                visualizationStyle: visualizationStyle,
                reduceMotion: pauseMotion
            )
            entity.components.set(OpacityComponent(opacity: mode.planetOpacity(for: planet.id)))
            if planet.id != .core {
                entity.addChild(PlanetEntityFactory.makeSunLight(
                    data: planet,
                    intensity: SunLightIntensity.intensity(for: mode, isFocused: isSelected)
                ))
            }
            planetRoot.addChild(entity)

            // Frosted hero halo around the central Founder OS core (only when a
            // core planet exists). Breathing pauses with the rest of the scene.
            if planet.id == .core {
                let halo = PlanetEntityFactory.makeFounderHalo(reduceMotion: pauseMotion)
                halo.components.set(OpacityComponent(opacity: mode.planetOpacity(for: .core)))
                planetRoot.addChild(halo)
            }
        }

        // Structural graph edges: founder core (origin) → each category planet
        // (primary tier). Static lines that fade with the orbit opacity, so they
        // vanish in detail/chat and soften when focused on a single branch.
        let linkFade = mode.orbitOpacityMultiplier / UniverseMode.overview.orbitOpacityMultiplier
        if linkFade > 0.001 {
            for planet in planets where planet.id != .core {
                orbitRoot.addChild(PlanetEntityFactory.makeLink(
                    from: .zero,
                    to: planet.position3D,
                    color: planet.uiColor,
                    opacity: 0.075 * linkFade,
                    thickness: 0.008,
                    name: "link:core-\(planet.id.rawValue)"
                ))
            }
        }

        if mode.showsSatellites,
           let selectedPlanet = planets.first(where: { $0.id == mode.focusedCategory }) {
            addSatellites(
                around: selectedPlanet,
                mode: mode,
                visualizationStyle: visualizationStyle,
                reduceMotion: reduceMotion
            )
        }
    }

    private func addSatellites(
        around planet: PlanetData,
        mode: UniverseMode,
        visualizationStyle: VisualizationStyle,
        reduceMotion: Bool
    ) {
        let category = UniverseSeed.category(planet.id)

        // For core, founder-os is the central planet itself, so only its other
        // tools become satellites. Indices/count stay aligned with the full
        // tool list so screen-space labels match the 3D nodes.
        let satelliteTools = planet.tools.enumerated().filter { _, tool in
            !(planet.id == .core && tool.id == PlanetData.centralCoreToolID)
        }
        guard !satelliteTools.isEmpty else { return }

        let orbitShell = PlanetEntityFactory.makeSatelliteOrbitShell(
            radius: max(2.4, planet.radius * 4.2),
            category: category,
            visualizationStyle: visualizationStyle,
            reduceMotion: reduceMotion
        )
        orbitShell.position = planet.position3D
        orbitShell.components.set(OpacityComponent(opacity: mode.selectedToolID == nil ? 0.42 : 0.28))
        satelliteRoot.addChild(orbitShell)

        let pivot = Entity()
        pivot.name = "satellite-pivot:\(planet.id.rawValue)"
        pivot.position = planet.position3D
        satelliteRoot.addChild(pivot)

        for (index, tool) in satelliteTools {
            let satellite = PlanetEntityFactory.makeSatellite(
                tool: tool,
                category: category,
                index: index,
                count: planet.tools.count,
                isSelected: tool.id == mode.selectedToolID,
                visualizationStyle: visualizationStyle,
                reduceMotion: reduceMotion
            )
            satellite.components.set(OpacityComponent(opacity: mode.satelliteOpacity(for: tool.id)))
            pivot.addChild(satellite)

            // Structural graph edge: category anchor → tool satellite (secondary
            // tier — dimmer/thinner than core→category). Static, in world space.
            let toolWorld = UniverseSpatialLayout.satelliteWorldPosition(
                for: tool, in: planet, index: index, count: planet.tools.count
            )
            satelliteRoot.addChild(PlanetEntityFactory.makeLink(
                from: planet.position3D,
                to: toolWorld,
                color: category.color.uiColor,
                opacity: 0.045,
                thickness: 0.006,
                name: "link:\(planet.id.rawValue)-\(tool.id)"
            ))
        }
    }

    private func addLights() {
        removeChildren(from: lightRoot)

        // Lowered from a code-only rig now that IBL (addBackdropAndIBL) provides
        // ambient + specular fill; the directionals just shape the key/rim.
        let key = DirectionalLight()
        key.name = "cosmic-key-light"
        key.light.intensity = 2_600
        key.light.color = UIColor(red: 0.82, green: 0.9, blue: 1, alpha: 1)
        key.position = SIMD3<Float>(-5, 8, 9)
        key.look(at: .zero, from: key.position, relativeTo: nil)
        lightRoot.addChild(key)

        let rim = DirectionalLight()
        rim.name = "cosmic-rim-light"
        rim.light.intensity = 750
        rim.light.color = UIColor(red: 0.75, green: 0.72, blue: 1, alpha: 1)
        rim.position = SIMD3<Float>(6, 3, -8)
        rim.look(at: .zero, from: rim.position, relativeTo: nil)
        lightRoot.addChild(rim)
    }

    /// Image-based lighting (ported from pre-cutover main). The visible
    /// procedural skybox/dust layers are intentionally off: their raster stars
    /// render as square artifacts in TestFlight. The SwiftUI background stays
    /// visible behind the RealityKit scene, while the generated equirectangular
    /// map still drives ambient/specular lighting on PBR nodes.
    private func addBackdropAndIBL() {
        if let equirect = CosmicEnvironmentTexture.makeEquirectangular(),
           let environment = try? EnvironmentResource(equirectangular: equirect) {
            let ibl = Entity()
            ibl.name = "ibl"
            ibl.components.set(ImageBasedLightComponent(source: .single(environment)))
            root.addChild(ibl)
            root.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ibl))
        }
    }

    private func addStars() {
        guard starRoot.children.isEmpty else { return }
        for index in 0..<120 {
            starRoot.addChild(PlanetEntityFactory.makeStar(index: index))
        }
    }

    private func orbitRings(for style: VisualizationStyle) -> [(radius: Float, opacity: Float, tilt: Float)] {
        switch style {
        case .atlasOverlay:
            return [(3.9, 0.025, 0.00), (5.95, 0.022, 0.03), (7.75, 0.018, -0.03)]
        case .kineticPockets:
            return [(3.55, 0.046, 0.02), (5.35, 0.042, -0.06), (7.2, 0.035, 0.08), (8.65, 0.026, -0.1)]
        case .force3D:
            return [(3.25, 0.06, 0.0), (5.15, 0.052, 0.18), (7.35, 0.04, -0.16), (9.4, 0.03, 0.26)]
        case .orbitalGlass:
            return [(3.7, 0.018, 0.0), (5.45, 0.015, 0.04), (7.15, 0.012, -0.04)]
        }
    }

    private func clearDynamicChildren() {
        removeChildren(from: planetRoot)
        removeChildren(from: orbitRoot)
        removeChildren(from: satelliteRoot)
    }

    private func removeChildren(from entity: Entity) {
        for child in Array(entity.children) {
            child.removeFromParent()
        }
    }

}

enum UniverseSceneTarget: Equatable {
    case planet(ToolCategoryId)
    case tool(String)
}
