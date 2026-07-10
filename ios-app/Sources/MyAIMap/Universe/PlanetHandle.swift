import Foundation
import OSLog
import RealityKit
import UIKit

/// Debug-only scene lifecycle logging (stripped to no-ops in release by OSLog).
let universeSceneLog = Logger(subsystem: "com.iliaturilia.myaimap", category: "universe-scene")

/// Persistent handle to one category planet's entity hierarchy. Created once
/// when the category first appears in the tool set and destroyed only when it
/// leaves — selection/mode changes mutate components on these same entities
/// (scale, materials, rim visibility, spin speed, opacity, sun intensity)
/// instead of tearing the planet down. This is the core of the RealityKit
/// redesign's "entities never recreated on selection" contract
/// (docs/UNIVERSE_ARCHITECTURE.md).
@MainActor
final class PlanetHandle {
    let data: PlanetData
    let root: Entity
    let body: ModelEntity
    let atmosphere: ModelEntity
    /// Rim ring built with unselected params; hidden while selected.
    let rimUnselected: ModelEntity
    /// Rim ring built with selected params (pre-divided by the selection scale
    /// so the scaled result matches the legacy selected geometry exactly).
    let rimSelected: ModelEntity
    let sun: PointLight?

    /// Material variants swapped on selection change (visual parity with the
    /// legacy per-rebuild materials).
    private let bodyMaterialSelected: PhysicallyBasedMaterial
    private let bodyMaterialUnselected: PhysicallyBasedMaterial
    private let atmosphereMaterialSelected: UnlitMaterial
    private let atmosphereMaterialUnselected: UnlitMaterial

    /// Non-core planets grow by this factor when selected
    /// (legacy: radius × 1.28 selected vs × 0.80 unselected).
    static let selectionScale: Float = 1.28 / 0.80

    private let atmosphereBaseScale: Float

    private(set) var isSelected = false
    private(set) var isPaused = false

    init(
        data: PlanetData,
        visualizationStyle: VisualizationStyle
    ) {
        self.data = data

        let baseRadius: Float
        if data.id == .core {
            baseRadius = data.radius * 0.54
        } else {
            baseRadius = data.radius * visualizationStyle.categoryScale * 0.80
        }

        root = Entity()
        root.name = "planet-root:\(data.id.rawValue)"
        root.position = data.position3D

        bodyMaterialSelected = PlanetEntityFactory.planetMaterial(
            data: data, isSelected: true, visualizationStyle: visualizationStyle)
        bodyMaterialUnselected = PlanetEntityFactory.planetMaterial(
            data: data, isSelected: false, visualizationStyle: visualizationStyle)
        atmosphereMaterialSelected = PlanetEntityFactory.atmosphereMaterial(
            data: data, isSelected: true, visualizationStyle: visualizationStyle)
        atmosphereMaterialUnselected = PlanetEntityFactory.atmosphereMaterial(
            data: data, isSelected: false, visualizationStyle: visualizationStyle)

        // Shared unit-sphere mesh, scaled per node (RK.3 cache). Collision
        // shapes live in entity-local space, so the tap radius is expressed
        // relative to the body scale to keep the legacy world-space size.
        body = ModelEntity(mesh: PlanetEntityFactory.unitSphere, materials: [bodyMaterialUnselected])
        body.scale = SIMD3<Float>(repeating: baseRadius)
        body.name = "planet:\(data.id.rawValue)"
        PlanetEntityFactory.configureTap(on: body, radius: max(baseRadius * 1.45, 0.95) / baseRadius)
        root.addChild(body)

        atmosphereBaseScale = baseRadius * 1.12
        atmosphere = ModelEntity(mesh: PlanetEntityFactory.unitSphere, materials: [atmosphereMaterialUnselected])
        atmosphere.scale = SIMD3<Float>(repeating: atmosphereBaseScale)
        atmosphere.name = "atmosphere:\(data.id.rawValue)"
        root.addChild(atmosphere)

        // Both rim states prebuilt; selection toggles which one is visible.
        // Legacy geometry: unselected ring at radius×1.18 tube 0.007 (hidden on
        // core), selected at (selected radius)×1.30 tube 0.012. The selected
        // ring lives under the scaled root, so its build-time radius/tube are
        // pre-divided by `selectionScale` for non-core planets.
        let rimTilt = simd_quatf(angle: .pi / 2.7, axis: SIMD3<Float>(1, 0, 0))
        let selectedRimScale: Float = data.id == .core ? 1 : Self.selectionScale
        rimUnselected = PlanetEntityFactory.makeOrbitLine(
            radius: baseRadius * 1.18,
            tube: 0.007,
            color: data.accentUIColor,
            opacity: 0.052 * visualizationStyle.glowBoost
        )
        rimUnselected.orientation = rimTilt
        rimUnselected.components.set(OpacityComponent(opacity: data.id == .core ? 0 : 1))
        root.addChild(rimUnselected)

        rimSelected = PlanetEntityFactory.makeOrbitLine(
            radius: baseRadius * 1.30,
            tube: 0.012 / selectedRimScale,
            color: data.accentUIColor,
            opacity: 0.24 * visualizationStyle.glowBoost
        )
        rimSelected.orientation = rimTilt
        rimSelected.components.set(OpacityComponent(opacity: 0))
        root.addChild(rimSelected)

        if data.id != .core {
            let light = PlanetEntityFactory.makeSunLight(data: data, intensity: 0)
            root.addChild(light)
            sun = light
        } else {
            sun = nil
        }

        universeSceneLog.debug("entity created planet-root:\(data.id.rawValue, privacy: .public)")
        restartMotion()
    }

    /// Apply selection + mode-derived state as component mutations. The entity
    /// objects are never recreated (`root`/`body`/`atmosphere` identities are
    /// stable for the handle's lifetime).
    func apply(mode: UniverseMode, pauseMotion: Bool) {
        let selected = mode.isPrimaryPlanet(data.id)
        let selectionChanged = selected != isSelected
        let pauseChanged = pauseMotion != isPaused
        isSelected = selected
        isPaused = pauseMotion

        root.components.set(OpacityComponent(opacity: mode.planetOpacity(for: data.id)))
        sun?.light.intensity = SunLightIntensity.intensity(for: mode, isFocused: selected)

        if selectionChanged {
            body.model?.materials = [selected ? bodyMaterialSelected : bodyMaterialUnselected]
            atmosphere.model?.materials = [selected ? atmosphereMaterialSelected : atmosphereMaterialUnselected]
            // (atmosphere scale — legacy 1.20 vs 1.12 factor — is pinned by
            // restartMotion below, which always runs on a selection change.)
            if data.id != .core {
                root.scale = SIMD3<Float>(repeating: selected ? Self.selectionScale : 1)
                rimUnselected.components.set(OpacityComponent(opacity: selected ? 0 : 1))
            } else {
                // Core shows its rim only while selected (legacy behavior).
                rimUnselected.components.set(OpacityComponent(opacity: 0))
            }
            rimSelected.components.set(OpacityComponent(opacity: selected ? 1 : 0))
        }
        if selectionChanged || pauseChanged {
            restartMotion()
        }
    }

    /// Spin/pulse clips depend on selection + pause state; restart them from
    /// scratch when either changes. Frame-rate independent RealityKit clips.
    private func restartMotion() {
        body.stopAllAnimations()
        atmosphere.stopAllAnimations()
        // A stopped pulse can strand the atmosphere at a mid-animation scale;
        // pin it back to the selection-state base before (re)starting clips.
        // (Unit-mesh world: base scale carries the radius; legacy factor
        // 1.20 selected vs 1.12 unselected rides on top.)
        atmosphere.scale = SIMD3<Float>(
            repeating: atmosphereBaseScale * (isSelected ? 1.20 / 1.12 : 1))
        guard !isPaused else { return }
        let visual = PlanetVisual.descriptor(for: data.id)
        PlanetEntityFactory.spin(
            body,
            axis: visual.spinAxis,
            duration: isSelected ? visual.spinDuration * 0.6 : visual.spinDuration
        )
        if isSelected {
            PlanetEntityFactory.pulse(atmosphere, baseScale: atmosphere.scale, duration: 2.4)
        }
    }
}

/// RK.3 visual descriptor — deterministic per-category motion parameters
/// (docs/UNIVERSE_VISUAL_SYSTEM.md §1/§7). Same id → same values on every
/// launch; unknown/custom categories derive stable values from the id hash.
enum PlanetVisual {
    struct Descriptor: Equatable, Sendable {
        /// Full-rotation duration (seconds) while unselected; selection
        /// multiplies by 0.6 (legacy 18/30 ratio — selected planets slow
        /// relative to their size bump for readability).
        let spinDuration: TimeInterval
        /// Axial tilt: the spin axis leans away from +Y deterministically.
        let spinAxis: SIMD3<Float>
    }

    /// Authored speeds for the seed categories — slow, slightly different per
    /// planet (brief: "each planet has a slightly different speed").
    private static let spinDurations: [ToolCategoryId: TimeInterval] = [
        .core: 38,
        ToolCategoryId(rawValue: "coding"): 27,
        ToolCategoryId(rawValue: "design"): 31,
        ToolCategoryId(rawValue: "research"): 24,
        ToolCategoryId(rawValue: "media"): 22,
        ToolCategoryId(rawValue: "distribution"): 20,
        ToolCategoryId(rawValue: "infrastructure"): 34,
        ToolCategoryId(rawValue: "knowledge"): 29,
        ToolCategoryId(rawValue: "analytics"): 26,
    ]

    static func descriptor(for id: ToolCategoryId) -> Descriptor {
        // Stable per-id pseudo-random in [0,1) — NOT Hasher (seeded per-launch).
        let h = id.rawValue.unicodeScalars.reduce(UInt64(1469598103934665603)) { acc, scalar in
            (acc ^ UInt64(scalar.value)) &* 1099511628211
        }
        let unit = Double(h % 1000) / 1000
        let duration = spinDurations[id] ?? (24 + unit * 12) // 24…36s fallback
        // Lean the legacy axis (0.18, 1, 0.08) by a per-id tilt: ±0.14 around
        // each horizontal component, normalized by `spin` itself.
        let tiltX = Float(0.18 + (unit - 0.5) * 0.28)
        let tiltZ = Float(0.08 + (Double((h >> 10) % 1000) / 1000 - 0.5) * 0.28)
        return Descriptor(
            spinDuration: duration,
            spinAxis: SIMD3<Float>(tiltX, 1, tiltZ)
        )
    }
}
