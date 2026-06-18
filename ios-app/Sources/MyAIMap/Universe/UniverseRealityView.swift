import RealityKit
import SwiftUI

/// SwiftUI bridge for the native RealityKit universe scene.
struct UniverseRealityView: View {
    let planets: [PlanetData]
    let mode: UniverseMode
    let visualizationStyle: VisualizationStyle
    let sceneController: UniverseSceneController
    let cameraRig: CameraRigController
    let gestureController: UniverseGestureController
    let onPlanetTap: @MainActor @Sendable (ToolCategoryId) -> Void
    let onToolTap: @MainActor @Sendable (String) -> Void
    let onEmptyTap: @MainActor @Sendable () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RealityView { content in
            content.add(sceneController.makeScene(
                planets: planets,
                mode: mode,
                visualizationStyle: visualizationStyle,
                cameraRig: cameraRig,
                reduceMotion: reduceMotion
            ))
        } update: { _ in
            sceneController.update(
                planets: planets,
                mode: mode,
                visualizationStyle: visualizationStyle,
                reduceMotion: reduceMotion
            )
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard mode.allowsMapGestures, !cameraRig.isTransitioning else { return }
                    gestureController.markEntityTap()
                    guard let target = sceneController.target(from: value.entity) else { return }
                    switch target {
                    case .planet(let id):
                        onPlanetTap(id)
                    case .tool(let id):
                        onToolTap(id)
                    }
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    guard (mode.allowsMapGestures || mode.isChatOpen), !cameraRig.isTransitioning else { return }
                    gestureController.handlePotentialEmptyTap(onEmptyTap)
                }
        )
        .highPriorityGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard mode.allowsMapGestures, !cameraRig.isTransitioning else { return }
                    gestureController.dragChanged(value, camera: cameraRig)
                }
                .onEnded { value in
                    guard mode.allowsMapGestures else {
                        gestureController.cancelDrag()
                        return
                    }
                    gestureController.dragEnded(value, camera: cameraRig)
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    guard mode.allowsMapGestures, !cameraRig.isTransitioning else { return }
                    gestureController.pinchChanged(value, camera: cameraRig)
                }
                .onEnded { _ in
                    gestureController.pinchEnded(camera: cameraRig)
                }
        )
        .opacity(mode.mapOpacity)
        .blur(radius: CGFloat(mode.mapBlurRadius))
    }
}
