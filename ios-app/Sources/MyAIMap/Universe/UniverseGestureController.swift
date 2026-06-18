import Foundation
import SwiftUI

/// Keeps gesture bookkeeping out of the SwiftUI/RealityKit bridge.
@MainActor
final class UniverseGestureController {
    private var previousDragTranslation: CGSize = .zero
    private var entityTapGeneration = 0
    private var lastEntityTapAt: Date?
    private var dragInteracting = false
    private var pinchInteracting = false

    nonisolated init() {}

    func dragChanged(_ value: DragGesture.Value, camera: CameraRigController) {
        if !dragInteracting {
            dragInteracting = true
            camera.beginInteraction()
        }
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
        endDragInteraction(camera)
        guard !camera.isTransitioning else { return }
        camera.finishPan(predictedDelta: predicted)
    }

    func cancelDrag(camera: CameraRigController) {
        previousDragTranslation = .zero
        endDragInteraction(camera)
    }

    private func endDragInteraction(_ camera: CameraRigController) {
        guard dragInteracting else { return }
        dragInteracting = false
        camera.endInteraction()
    }

    func pinchChanged(_ value: MagnifyGesture.Value, camera: CameraRigController) {
        if !pinchInteracting {
            pinchInteracting = true
            camera.beginInteraction()
        }
        camera.zoom(magnification: Float(value.magnification))
    }

    func pinchEnded(camera: CameraRigController) {
        camera.endZoom()
        if pinchInteracting {
            pinchInteracting = false
            camera.endInteraction()
        }
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
