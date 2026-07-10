import Foundation
import RealityKit
import UIKit

/// Owns the RealityKit entity graph for the AI Universe Map.
///
/// Persistent-scene contract (docs/UNIVERSE_ARCHITECTURE.md): planet entities
/// are created once per category id and held in `registry`; selection and mode
/// changes are applied as component mutations on those same entities via
/// `applyMode`. Only structural changes (tool set / visualization style) run
/// the registry diff, and only satellites — transient reveal elements of the
/// focused branch — are still rebuilt per focus change.
@MainActor
final class UniverseSceneController {
    private let root = Entity()
    private let planetRoot = Entity()
    private let orbitRoot = Entity()
    private let starRoot = Entity()
    private let satelliteRoot = Entity()
    private let lightRoot = Entity()
    private let camera = PerspectiveCamera()

    /// id → persistent planet handle. Entity identity survives any
    /// selection/mode change; see `PlanetHandle`.
    private(set) var registry: [ToolCategoryId: PlanetHandle] = [:]
    private var founderHalo: ModelEntity?
    private var haloPaused = false
    private var orbitRingEntities: [ModelEntity] = []
    private var coreLinks: [ToolCategoryId: ModelEntity] = [:]

    private var structureSignature = ""
    private var satelliteSignature = ""

    /// `active` = the 3D renderer is the visible one. While inactive the scene
    /// stays dormant: structure is not built until first activation (2D-default
    /// users never pay the IBL/star build), and an already-built scene pauses
    /// every animation clip so a hidden RealityView costs no ambient GPU work.
    func makeScene(
        planets: [PlanetData],
        mode: UniverseMode,
        visualizationStyle: VisualizationStyle,
        cameraRig: CameraRigController,
        reduceMotion: Bool,
        active: Bool
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
        } else {
            // The RealityView is always-mounted now (UniverseMapView keeps it
            // out of the renderer switch), so `make` should run exactly once
            // per controller lifetime. A second call means the view was torn
            // down unexpectedly — log it; the persistent graph still re-binds.
            universeSceneLog.error("makeScene called again on a live scene")
        }
        universeSceneLog.debug("scene init")

        // Attach the camera to this RealityView content's render pass. (The old
        // G1 `sceneSignature = \"\"` full-rebuild hack is gone: the scene no
        // longer unmounts on renderer/mode changes, and the entity graph is
        // persistent by construction.)
        cameraRig.attach(camera)

        sync(
            planets: planets,
            mode: mode,
            visualizationStyle: visualizationStyle,
            reduceMotion: reduceMotion,
            active: active
        )
        return root
    }

    func update(
        planets: [PlanetData],
        mode: UniverseMode,
        visualizationStyle: VisualizationStyle,
        reduceMotion: Bool,
        active: Bool
    ) {
        sync(
            planets: planets,
            mode: mode,
            visualizationStyle: visualizationStyle,
            reduceMotion: reduceMotion,
            active: active
        )
    }

    private func sync(
        planets: [PlanetData],
        mode: UniverseMode,
        visualizationStyle: VisualizationStyle,
        reduceMotion: Bool,
        active: Bool
    ) {
        // Dormant until the 3D renderer is first shown; after that, an
        // inactive scene keeps its entities but pauses all motion (applyMode
        // below receives active=false and treats it as a global pause).
        guard active || !structureSignature.isEmpty else { return }
        syncStructure(planets: planets, visualizationStyle: visualizationStyle)
        applyMode(
            planets: planets,
            mode: mode,
            visualizationStyle: visualizationStyle,
            reduceMotion: reduceMotion,
            active: active
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

    // MARK: - Structure (tool set / style) — registry diff

    /// Structure key: everything that changes what entities EXIST — and nothing
    /// that merely changes how they look. Mode/selection/reduce-motion are
    /// deliberately absent (they are `applyMode` mutations). Per-planet
    /// geometry inputs (radius grows with tool count; positions shift when the
    /// branch count changes) are covered by the tool-id list: any tool add or
    /// remove changes this key, and `syncStructure` then re-checks each
    /// surviving planet's geometry.
    static func structureSignature(
        planets: [PlanetData],
        visualizationStyle: VisualizationStyle
    ) -> String {
        [
            visualizationStyle.rawValue,
            planets.map { planet in
                "\(planet.id.rawValue):\(planet.tools.map(\.id).joined(separator: ","))"
            }.joined(separator: "|"),
        ].joined(separator: "#")
    }

    private func syncStructure(planets: [PlanetData], visualizationStyle: VisualizationStyle) {
        let signature = Self.structureSignature(planets: planets, visualizationStyle: visualizationStyle)
        guard signature != structureSignature else { return }
        structureSignature = signature
        // Satellites hang off per-planet geometry; force their re-derive.
        satelliteSignature = ""

        // Planets: diff the registry against the wanted set. A surviving id
        // whose geometry inputs changed (radius from tool count, position from
        // branch layout, colors) is recreated — that is a structural change,
        // not a selection change, so the persistence contract holds.
        let wanted = Dictionary(uniqueKeysWithValues: planets.map { ($0.id, $0) })
        for (id, handle) in registry where wanted[id] == nil {
            universeSceneLog.debug("entity removed planet-root:\(id.rawValue, privacy: .public)")
            handle.root.removeFromParent()
            registry[id] = nil
        }
        for planet in planets {
            if let existing = registry[planet.id], Self.geometryMatches(existing.data, planet) {
                continue
            }
            registry[planet.id]?.root.removeFromParent()
            let handle = PlanetHandle(data: planet, visualizationStyle: visualizationStyle)
            planetRoot.addChild(handle.root)
            registry[planet.id] = handle
        }

        // Founder halo: persistent decoration around the core planet.
        let hasCore = wanted[.core] != nil
        if hasCore, founderHalo == nil {
            let halo = PlanetEntityFactory.makeFounderHalo(reduceMotion: true)
            planetRoot.addChild(halo)
            founderHalo = halo
            haloPaused = true
        } else if !hasCore, let halo = founderHalo {
            halo.removeFromParent()
            founderHalo = nil
        }

        // Universe orbit rings + core→category links are cheap structural
        // decorations; rebuild them with BASE material opacity — the per-mode
        // fade is applied as an OpacityComponent multiplier in applyMode.
        for ring in orbitRingEntities { ring.removeFromParent() }
        orbitRingEntities = orbitRings(for: visualizationStyle).map { spec in
            let ring = PlanetEntityFactory.makeUniverseOrbit(
                radius: spec.radius,
                color: UIColor(white: 1, alpha: 1),
                opacity: spec.opacity,
                tilt: spec.tilt
            )
            orbitRoot.addChild(ring)
            return ring
        }
        for (_, link) in coreLinks { link.removeFromParent() }
        coreLinks = [:]
        for planet in planets where planet.id != .core {
            let link = PlanetEntityFactory.makeLink(
                from: .zero,
                to: planet.position3D,
                color: planet.uiColor,
                opacity: 0.075,
                thickness: 0.008,
                name: "link:core-\(planet.id.rawValue)"
            )
            orbitRoot.addChild(link)
            coreLinks[planet.id] = link
        }
    }

    /// True when a planet's build-time geometry inputs are unchanged, so the
    /// existing handle can be kept and only mutated.
    static func geometryMatches(_ a: PlanetData, _ b: PlanetData) -> Bool {
        a.radius == b.radius
            && a.position3D == b.position3D
            && a.color.rawValue == b.color.rawValue
            && a.accent.rawValue == b.accent.rawValue
    }

    // MARK: - Mode / selection — component mutations only

    private func applyMode(
        planets: [PlanetData],
        mode: UniverseMode,
        visualizationStyle: VisualizationStyle,
        reduceMotion: Bool,
        active: Bool
    ) {
        // Pause ambient spin/pulse when the universe is only a dimmed backdrop
        // (detail/chat), when the 3D renderer is hidden behind the 2D graph,
        // or under Reduce Motion.
        let pauseMotion = reduceMotion || mode.pausesAmbientMotion || !active

        for (_, handle) in registry {
            handle.apply(mode: mode, pauseMotion: pauseMotion)
        }

        if let halo = founderHalo {
            halo.components.set(OpacityComponent(opacity: mode.planetOpacity(for: .core)))
            if pauseMotion != haloPaused {
                haloPaused = pauseMotion
                halo.stopAllAnimations()
                halo.scale = SIMD3<Float>(repeating: 1)
                if !pauseMotion {
                    PlanetEntityFactory.breathe(halo)
                }
            }
        }

        // Orbit rings and structural links fade with the mode: material keeps
        // the base opacity, the component carries the mode multiplier.
        let ringFade = mode.orbitOpacityMultiplier / UniverseMode.overview.orbitOpacityMultiplier
        for ring in orbitRingEntities {
            ring.components.set(OpacityComponent(opacity: mode.orbitOpacityMultiplier))
        }
        for (_, link) in coreLinks {
            link.components.set(OpacityComponent(opacity: ringFade))
        }

        syncSatellites(
            planets: planets,
            mode: mode,
            visualizationStyle: visualizationStyle,
            pauseMotion: pauseMotion
        )
    }

    /// Satellites are the focused branch's transient reveal layer; they are
    /// re-derived when the focus/selection context changes (scoped teardown —
    /// the persistent planets above are untouched by this).
    private func syncSatellites(
        planets: [PlanetData],
        mode: UniverseMode,
        visualizationStyle: VisualizationStyle,
        pauseMotion: Bool
    ) {
        let signature = mode.showsSatellites
            ? "\(mode.signature)#\(pauseMotion)"
            : "hidden"
        guard signature != satelliteSignature else { return }
        satelliteSignature = signature

        removeChildren(from: satelliteRoot)
        guard mode.showsSatellites,
              let selectedPlanet = planets.first(where: { $0.id == mode.focusedCategory }) else { return }
        addSatellites(
            around: selectedPlanet,
            mode: mode,
            visualizationStyle: visualizationStyle,
            pauseMotion: pauseMotion
        )
    }

    private func addSatellites(
        around planet: PlanetData,
        mode: UniverseMode,
        visualizationStyle: VisualizationStyle,
        pauseMotion: Bool
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
            reduceMotion: pauseMotion
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
                reduceMotion: pauseMotion
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

        addConnectionTraces(in: planet, category: category, mode: mode)
    }

    /// 3D connection traces (constellation Phase 3): when a tool is focused,
    /// draw brighter lines from it to the tools it connects to (via the shared
    /// `ConnectionResolver`). Scoped to the focused category's tools, which are
    /// the satellites actually rendered, so every line lands on a visible node.
    private func addConnectionTraces(in planet: PlanetData, category: ToolCategory, mode: UniverseMode) {
        guard let selectedID = mode.selectedToolID,
              let selectedTool = planet.tools.first(where: { $0.id == selectedID }),
              let selectedIndex = planet.tools.firstIndex(where: { $0.id == selectedID }) else { return }

        let count = planet.tools.count
        let fromWorld = UniverseSpatialLayout.satelliteWorldPosition(
            for: selectedTool, in: planet, index: selectedIndex, count: count
        )
        let connections = ConnectionResolver.connections(for: selectedTool, in: planet.tools)
        for connection in connections {
            guard let targetIndex = planet.tools.firstIndex(where: { $0.id == connection.targetID }) else { continue }
            let targetTool = planet.tools[targetIndex]
            let toWorld = UniverseSpatialLayout.satelliteWorldPosition(
                for: targetTool, in: planet, index: targetIndex, count: count
            )
            let strong = connection.kind == .curated || connection.kind == .ai || connection.kind == .alternative
            satelliteRoot.addChild(PlanetEntityFactory.makeLink(
                from: fromWorld,
                to: toWorld,
                color: category.color.uiColor,
                opacity: strong ? 0.5 : 0.22,
                thickness: strong ? 0.014 : 0.008,
                name: "trace:\(selectedID)-\(connection.targetID)"
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
