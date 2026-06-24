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
    let onOrbitSettled: @MainActor @Sendable () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Honor the system Reduce Motion setting, and also force a static scene
    /// when launched with `-uitestStatic` so XCUITest can reach quiescence
    /// (the perpetual RealityKit spin/pulse animations otherwise keep the app
    /// from ever going idle, timing out accessibility snapshots). Prod behavior
    /// is unchanged unless that launch argument is present.
    private var effectiveReduceMotion: Bool {
        reduceMotion || ProcessInfo.processInfo.arguments.contains("-uitestStatic")
    }

    var body: some View {
        RealityView { content in
            content.add(sceneController.makeScene(
                planets: planets,
                mode: mode,
                visualizationStyle: visualizationStyle,
                cameraRig: cameraRig,
                reduceMotion: effectiveReduceMotion
            ))
        } update: { _ in
            sceneController.update(
                planets: planets,
                mode: mode,
                visualizationStyle: visualizationStyle,
                reduceMotion: effectiveReduceMotion
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
                        gestureController.cancelDrag(camera: cameraRig)
                        return
                    }
                    gestureController.dragEnded(value, camera: cameraRig)
                    onOrbitSettled()
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
        .onAppear { cameraRig.prefersInstant = effectiveReduceMotion }
        .onChange(of: reduceMotion) { _, _ in
            cameraRig.prefersInstant = effectiveReduceMotion
        }
    }
}
