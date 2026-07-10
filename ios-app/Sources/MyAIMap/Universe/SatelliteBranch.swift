import Foundation
import RealityKit
import UIKit

/// Persistent satellite layer for ONE focused category (RK.2.2).
///
/// Built when a category gains focus; while the focus stays inside that
/// category, tool selection / detail / chat / reduce-motion changes are
/// applied as component mutations on the SAME entities — the per-tool
/// satellites are never recreated by selection. Only leaving the category
/// (or a structural tool-set change) tears the branch down.
@MainActor
final class SatelliteBranch {
    let categoryID: ToolCategoryId
    let root = Entity()

    private let orbitShell: Entity
    private let pivot = Entity()
    private var handles: [String: SatelliteHandle] = [:]
    private var traceHost = Entity()
    private var tracedToolID: String?
    private var isPaused: Bool
    private let planet: PlanetData
    private let category: ToolCategory
    private let visualizationStyle: VisualizationStyle

    /// Selected satellites grow by this factor (legacy: radius 0.29 vs 0.20).
    static let selectionScale: Float = 0.29 / 0.20
    /// Legacy halo radius factors relative to the body radius.
    static let haloFactorSelected: Float = 1.34
    static let haloFactorUnselected: Float = 1.22

    init(
        planet: PlanetData,
        visualizationStyle: VisualizationStyle,
        pauseMotion: Bool
    ) {
        self.categoryID = planet.id
        self.planet = planet
        self.category = UniverseSeed.category(planet.id)
        self.visualizationStyle = visualizationStyle
        self.isPaused = pauseMotion
        root.name = "satellite-branch:\(planet.id.rawValue)"

        orbitShell = PlanetEntityFactory.makeSatelliteOrbitShell(
            radius: max(2.4, planet.radius * 4.2),
            category: category,
            visualizationStyle: visualizationStyle,
            reduceMotion: pauseMotion
        )
        orbitShell.position = planet.position3D
        root.addChild(orbitShell)

        pivot.name = "satellite-pivot:\(planet.id.rawValue)"
        pivot.position = planet.position3D
        root.addChild(pivot)

        traceHost.name = "trace-host:\(planet.id.rawValue)"
        root.addChild(traceHost)

        // For core, founder-os is the central planet itself, so only its other
        // tools become satellites. Indices/count stay aligned with the full
        // tool list so screen-space labels match the 3D nodes.
        let satelliteTools = planet.tools.enumerated().filter { _, tool in
            !(planet.id == .core && tool.id == PlanetData.centralCoreToolID)
        }
        for (index, tool) in satelliteTools {
            let handle = SatelliteHandle(
                tool: tool,
                category: category,
                index: index,
                count: planet.tools.count,
                visualizationStyle: visualizationStyle,
                pauseMotion: pauseMotion
            )
            pivot.addChild(handle.root)
            handles[tool.id] = handle

            // Structural graph edge: category anchor → tool satellite (secondary
            // tier — dimmer/thinner than core→category). Static, in world space.
            let toolWorld = UniverseSpatialLayout.satelliteWorldPosition(
                for: tool, in: planet, index: index, count: planet.tools.count
            )
            root.addChild(PlanetEntityFactory.makeLink(
                from: planet.position3D,
                to: toolWorld,
                color: category.color.uiColor,
                opacity: 0.045,
                thickness: 0.006,
                name: "link:\(planet.id.rawValue)-\(tool.id)"
            ))
        }
        universeSceneLog.debug("satellite branch created \(planet.id.rawValue, privacy: .public)")
    }

    /// Test hook: stable identity of each tool's root entity.
    var toolRootIdentities: [String: ObjectIdentifier] {
        handles.mapValues { ObjectIdentifier($0.root) }
    }

    /// Apply mode-derived state as mutations (never recreates satellites).
    func apply(mode: UniverseMode, pauseMotion: Bool) {
        orbitShell.components.set(
            OpacityComponent(opacity: mode.selectedToolID == nil ? 0.42 : 0.28))
        if pauseMotion != isPaused {
            orbitShell.stopAllAnimations()
            if !pauseMotion {
                PlanetEntityFactory.spin(orbitShell, axis: SIMD3<Float>(0, 1, 0), duration: 32)
            }
        }
        for (_, handle) in handles {
            handle.apply(mode: mode, pauseMotion: pauseMotion)
        }
        isPaused = pauseMotion
        syncTraces(mode: mode)
    }

    /// 3D connection traces: when a tool is focused, brighter lines from it to
    /// its connections (shared `ConnectionResolver`), scoped to this branch's
    /// tools. Traces are transient line overlays — rebuilt per selected tool.
    private func syncTraces(mode: UniverseMode) {
        let selectedID = mode.selectedToolID
        guard selectedID != tracedToolID else { return }
        tracedToolID = selectedID
        for child in Array(traceHost.children) { child.removeFromParent() }
        guard let selectedID,
              let selectedTool = planet.tools.first(where: { $0.id == selectedID }),
              let selectedIndex = planet.tools.firstIndex(where: { $0.id == selectedID }) else { return }

        let count = planet.tools.count
        let fromWorld = UniverseSpatialLayout.satelliteWorldPosition(
            for: selectedTool, in: planet, index: selectedIndex, count: count
        )
        for connection in ConnectionResolver.connections(for: selectedTool, in: planet.tools) {
            guard let targetIndex = planet.tools.firstIndex(where: { $0.id == connection.targetID }) else { continue }
            let targetTool = planet.tools[targetIndex]
            let toWorld = UniverseSpatialLayout.satelliteWorldPosition(
                for: targetTool, in: planet, index: targetIndex, count: count
            )
            let strong = connection.kind == .curated || connection.kind == .ai || connection.kind == .alternative
            traceHost.addChild(PlanetEntityFactory.makeLink(
                from: fromWorld,
                to: toWorld,
                color: category.color.uiColor,
                opacity: strong ? 0.5 : 0.22,
                thickness: strong ? 0.014 : 0.008,
                name: "trace:\(selectedID)-\(connection.targetID)"
            ))
        }
    }
}

/// One persistent tool satellite: body + halo + prebuilt selection ring.
/// Selection mutates scale/materials/ring visibility; entity identity is
/// stable for the branch's lifetime.
@MainActor
final class SatelliteHandle {
    let root: Entity
    let body: ModelEntity
    private let halo: ModelEntity
    private let selectionRing: ModelEntity
    private let bodyMaterialSelected: PhysicallyBasedMaterial
    private let bodyMaterialUnselected: PhysicallyBasedMaterial
    private let haloMaterialSelected: UnlitMaterial
    private let haloMaterialUnselected: UnlitMaterial
    private let spinDuration: TimeInterval
    private var isSelected = false
    private var isPaused: Bool

    init(
        tool: Tool,
        category: ToolCategory,
        index: Int,
        count: Int,
        visualizationStyle: VisualizationStyle,
        pauseMotion: Bool
    ) {
        isPaused = pauseMotion
        spinDuration = 12 + Double(index % 4) * 2

        root = Entity()
        root.name = "satellite-root:\(tool.id)"
        root.position = UniverseSpatialLayout.satelliteOffset(index: index, count: count, orbit: tool.orbit)

        let baseRadius: Float = 0.20 * visualizationStyle.nodeScale

        func bodyMaterial(_ selected: Bool) -> PhysicallyBasedMaterial {
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: PlanetEntityFactory.mix(
                category.color.uiColor, with: .white, amount: selected ? 0.34 : 0.18))
            material.roughness = .init(floatLiteral: 0.42)
            material.metallic = .init(floatLiteral: 0.08)
            material.emissiveColor = .init(color: category.glow.uiColor)
            material.emissiveIntensity = (selected ? 1.6 : 0.30) * visualizationStyle.glowBoost
            return material
        }
        bodyMaterialSelected = bodyMaterial(true)
        bodyMaterialUnselected = bodyMaterial(false)
        haloMaterialSelected = PlanetEntityFactory.unlitGlow(color: category.glow.uiColor, opacity: 0.22)
        haloMaterialUnselected = PlanetEntityFactory.unlitGlow(color: category.glow.uiColor, opacity: 0.04)

        body = ModelEntity(mesh: .generateSphere(radius: baseRadius), materials: [bodyMaterialUnselected])
        body.name = "tool:\(tool.id)"
        PlanetEntityFactory.configureTap(on: body, radius: max(baseRadius * 2.2, 0.44))
        root.addChild(body)

        halo = ModelEntity(
            mesh: .generateSphere(radius: baseRadius * SatelliteBranch.haloFactorUnselected),
            materials: [haloMaterialUnselected]
        )
        root.addChild(halo)

        // Selection ring prebuilt hidden. Legacy: radius = selectedRadius×1.78,
        // tube 0.006 — pre-divided by the root selection scale so the scaled
        // result matches exactly.
        selectionRing = PlanetEntityFactory.makeOrbitLine(
            radius: baseRadius * 1.78,
            tube: 0.006 / SatelliteBranch.selectionScale,
            color: category.glow.uiColor,
            opacity: 0.42 * visualizationStyle.glowBoost
        )
        selectionRing.orientation = simd_quatf(angle: .pi / 2.35, axis: SIMD3<Float>(1, 0, 0))
            * simd_quatf(angle: .pi / 8, axis: SIMD3<Float>(0, 1, 0))
        selectionRing.components.set(OpacityComponent(opacity: 0))
        root.addChild(selectionRing)

        restartMotion()
    }

    func apply(mode: UniverseMode, pauseMotion: Bool) {
        let toolID = String(body.name.dropFirst("tool:".count))
        let selected = mode.selectedToolID == toolID
        let selectionChanged = selected != isSelected
        let pauseChanged = pauseMotion != isPaused
        isSelected = selected
        isPaused = pauseMotion

        root.components.set(OpacityComponent(opacity: mode.satelliteOpacity(for: toolID)))

        if selectionChanged {
            root.scale = SIMD3<Float>(repeating: selected ? SatelliteBranch.selectionScale : 1)
            body.model?.materials = [selected ? bodyMaterialSelected : bodyMaterialUnselected]
            halo.model?.materials = [selected ? haloMaterialSelected : haloMaterialUnselected]
            // Legacy halo factor 1.34 selected vs 1.22 unselected (the root
            // scale supplies the body-radius growth; this tops up the ratio).
            halo.scale = SIMD3<Float>(repeating:
                selected ? SatelliteBranch.haloFactorSelected / SatelliteBranch.haloFactorUnselected : 1)
            selectionRing.components.set(OpacityComponent(opacity: selected ? 1 : 0))
        }
        if pauseChanged {
            restartMotion()
        }
    }

    private func restartMotion() {
        body.stopAllAnimations()
        guard !isPaused else { return }
        PlanetEntityFactory.spin(body, axis: SIMD3<Float>(0, 1, 0), duration: spinDuration)
    }
}
