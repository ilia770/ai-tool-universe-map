import Foundation
import SwiftUI

/// Keeps gesture bookkeeping out of the SwiftUI/RealityKit bridge.
@MainActor
final class UniverseGestureController {
    private var previousDragTranslation: CGSize = .zero
    private var entityTapGeneration = 0
    private var lastEntityTapAt: Date?

    nonisolated init() {}

    func dragChanged(_ value: DragGesture.Value, camera: CameraRigController) {
        let delta = CGSize(
            width: value.translation.width - previousDragTranslation.width,
            height: value.translation.height - previousDragTranslation.height
        )
        previousDragTranslation = value.translation
        camera.pan(delta: delta)
    }

    func dragEnded(_ value: DragGesture.Value, camera: CameraRigController) {
        let predicted = CGSize(
            width: value.predictedEndTranslation.width - value.translation.width,
            height: value.predictedEndTranslation.height - value.translation.height
        )
        previousDragTranslation = .zero
        guard !camera.isTransitioning else { return }
        camera.finishPan(predictedDelta: predicted)
    }

    func cancelDrag() {
        previousDragTranslation = .zero
    }

    func pinchChanged(_ value: MagnifyGesture.Value, camera: CameraRigController) {
        camera.zoom(magnification: Float(value.magnification))
    }

    func pinchEnded(camera: CameraRigController) {
        camera.endZoom()
    }

    func markEntityTap() {
        entityTapGeneration += 1
        lastEntityTapAt = Date()
    }

    func handlePotentialEmptyTap(_ action: @escaping @MainActor @Sendable () -> Void) {
        let generation = entityTapGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard generation == entityTapGeneration else { return }
            if let lastEntityTapAt, Date().timeIntervalSince(lastEntityTapAt) < 0.18 {
                return
            }
            action()
        }
    }
}
