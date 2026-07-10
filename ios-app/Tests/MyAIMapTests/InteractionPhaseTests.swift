import Testing
@testable import MyAIMap

/// RK.4 — unified interaction phase (docs/UNIVERSE_STATE_MACHINE.md §2).
/// The derivation priority must mirror the legacy guard order exactly:
/// overlay gate > camera flight > active gesture > idle.
@Suite("InteractionPhase — derivation priority + gesture legality")
struct InteractionPhaseTests {

    @Test func overlayModesGateEverything() {
        for mode in [UniverseMode.detail(.design, "figma"), .chatOpen(.design, "figma")] {
            let phase = InteractionPhase.derive(
                mode: mode, isTransitioning: true, isDragging: true, isPinching: true)
            #expect(phase == .overlayInteracting)
            #expect(!phase.allowsMapGestures)
        }
    }

    @Test func cameraFlightBeatsGestures() {
        let phase = InteractionPhase.derive(
            mode: .overview, isTransitioning: true, isDragging: true, isPinching: true)
        #expect(phase == .cameraAnimating)
        #expect(!phase.allowsMapGestures)
    }

    @Test func dragBeatsPinchBeatsIdle() {
        #expect(InteractionPhase.derive(
            mode: .overview, isTransitioning: false, isDragging: true, isPinching: true) == .dragging)
        #expect(InteractionPhase.derive(
            mode: .overview, isTransitioning: false, isDragging: false, isPinching: true) == .pinching)
        #expect(InteractionPhase.derive(
            mode: .overview, isTransitioning: false, isDragging: false, isPinching: false) == .idle)
    }

    @Test func navigableModesAllowGestures() {
        for mode in [UniverseMode.overview, .branchFocus(.design), .toolSelected(.design, "figma")] {
            let phase = InteractionPhase.derive(
                mode: mode, isTransitioning: false, isDragging: false, isPinching: false)
            #expect(phase == .idle)
            #expect(phase.allowsMapGestures)
        }
    }

    @Test func activeGesturePhasesStillAllowTheirGesture() {
        // Mid-drag/pinch callbacks keep flowing (the phase reports the gesture,
        // not a lockout).
        #expect(InteractionPhase.dragging.allowsMapGestures)
        #expect(InteractionPhase.pinching.allowsMapGestures)
    }
}
