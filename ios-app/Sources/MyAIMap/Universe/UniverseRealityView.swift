import RealityKit
import SwiftUI

/// SwiftUI bridge for the native RealityKit universe scene.
struct UniverseRealityView: View {
    let planets: [PlanetData]
    let mode: UniverseMode
    let visualizationStyle: VisualizationStyle
    /// False while the 2D graph renderer is the visible one. The RealityView
    /// stays mounted (persistent scene — entities are never torn down by a
    /// renderer toggle) but the scene is dormant/paused; see
    /// `UniverseSceneController.makeScene`.
    let isActive: Bool
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

    /// Unified interaction phase (RK.4) — one derivation for every gesture
    /// guard below, replacing the scattered mode/isTransitioning checks.
    private var interactionPhase: InteractionPhase {
        InteractionPhase.derive(
            mode: mode,
            isTransitioning: cameraRig.isTransitioning,
            isDragging: gestureController.dragInteracting,
            isPinching: gestureController.pinchInteracting
        )
    }

    var body: some View {
        RealityView { content in
            content.add(sceneController.makeScene(
                planets: planets,
                mode: mode,
                visualizationStyle: visualizationStyle,
                cameraRig: cameraRig,
                reduceMotion: effectiveReduceMotion,
                active: isActive
            ))
        } update: { _ in
            sceneController.update(
                planets: planets,
                mode: mode,
                visualizationStyle: visualizationStyle,
                reduceMotion: effectiveReduceMotion,
                active: isActive
            )
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard interactionPhase.allowsMapGestures else { return }
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
                    guard interactionPhase.allowsMapGestures || (mode.isChatOpen && !cameraRig.isTransitioning) else { return }
                    gestureController.handlePotentialEmptyTap(onEmptyTap)
                }
        )
        .highPriorityGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard interactionPhase.allowsMapGestures else { return }
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
                    guard interactionPhase.allowsMapGestures else { return }
                    gestureController.pinchChanged(value, camera: cameraRig)
                }
                .onEnded { _ in
                    gestureController.pinchEnded(camera: cameraRig)
                }
        )
        .opacity(mode.mapOpacity)
        .blur(radius: CGFloat(mode.mapBlurRadius))
        // RK.7 VoiceOver bridge: RealityKit entities aren't accessibility
        // elements, so expose the planets as a predictable, ordered set of
        // virtual children — VO users can select a planet without gestures
        // (QA checklist criterion 15). Order = layout order (deterministic).
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Universe map")
        .accessibilityChildren {
            ForEach(planets) { planet in
                Button("\(planet.title), \(planet.toolCount) tools") {
                    onPlanetTap(planet.id)
                }
            }
        }
        .onAppear { cameraRig.prefersInstant = effectiveReduceMotion }
        .onChange(of: reduceMotion) { _, _ in
            cameraRig.prefersInstant = effectiveReduceMotion
        }
    }
}
