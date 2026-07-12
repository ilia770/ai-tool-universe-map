import Foundation
import RealityKit
import UIKit

/// Light impulses running along synapse links (Neural Universe spec §Visual
/// system). One small additive bead per link, animating from→to on a looping
/// clip with deterministic stagger — RealityKit-time-based, no per-frame
/// SwiftUI work. The owner rebuilds the set when its link set changes and
/// drives `setPaused` from the scene's pause matrix (Reduce Motion / detail /
/// chat / hidden renderer).
@MainActor
final class SynapsePulses {
    struct Spec {
        let from: SIMD3<Float>
        let to: SIMD3<Float>
        let color: UIColor
        /// Seconds for one traversal.
        let duration: TimeInterval
    }

    private struct Bead {
        let entity: ModelEntity
        let spec: Spec
        let phase: TimeInterval
    }

    private var beads: [Bead] = []
    private var paused: Bool
    /// Bumped on every pause/rebuild so stale staggered-start tasks no-op.
    private var generation = 0

    static let beadScale: Float = 0.045

    init(host: Entity, specs: [Spec], paused: Bool) {
        self.paused = paused
        for (index, spec) in specs.enumerated() {
            let material = PlanetEntityFactory.unlitGlow(color: spec.color, opacity: 0.9)
            let bead = ModelEntity(mesh: PlanetEntityFactory.unitSphere, materials: [material])
            bead.name = "pulse:\(index)"
            bead.scale = SIMD3<Float>(repeating: Self.beadScale)
            bead.position = spec.from
            bead.components.set(OpacityComponent(opacity: 0)) // hidden until started
            host.addChild(bead)
            // Deterministic stagger: spread starts across one traversal.
            let phase = spec.duration * Double(index) / Double(max(specs.count, 1))
            beads.append(Bead(entity: bead, spec: spec, phase: phase))
        }
        if !paused { start() }
    }

    var beadCount: Int { beads.count }
    var isPaused: Bool { paused }

    func setPaused(_ newValue: Bool) {
        guard newValue != paused else { return }
        paused = newValue
        generation += 1
        if newValue {
            for bead in beads {
                bead.entity.stopAllAnimations()
                bead.entity.components.set(OpacityComponent(opacity: 0))
            }
        } else {
            start()
        }
    }

    func removeAll() {
        generation += 1
        for bead in beads { bead.entity.removeFromParent() }
        beads = []
    }

    private func start() {
        let expected = generation
        for bead in beads {
            Task { @MainActor in
                if bead.phase > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(bead.phase * 1_000_000_000))
                }
                guard expected == generation, !paused else { return }
                bead.entity.components.set(OpacityComponent(opacity: 1))
                var from = Transform(scale: SIMD3<Float>(repeating: Self.beadScale))
                from.translation = bead.spec.from
                var to = from
                to.translation = bead.spec.to
                let run = FromToByAnimation<Transform>(
                    from: from,
                    to: to,
                    duration: bead.spec.duration,
                    timing: .easeInOut,
                    bindTarget: .transform,
                    repeatMode: .repeat
                )
                if let resource = try? AnimationResource.generate(with: run) {
                    bead.entity.playAnimation(resource)
                }
            }
        }
    }
}
