import Testing
@testable import MyAIMap

/// Task 9c — pure boot-phase gate so the branded loading state (and the
/// black-frame kill) is unit-testable headless, without standing up the
/// RealityKit scene.
@Suite("UniverseBootState")
struct UniverseBootStateTests {

    @Test func startsLoading() {
        #expect(UniverseBootState().phase == .loading)
    }

    @Test func readyAfterSceneReady() {
        var s = UniverseBootState()
        s.markSceneReady()
        #expect(s.phase == .ready)
    }

    @Test func markSceneReadyIsIdempotent() {
        var s = UniverseBootState()
        s.markSceneReady()
        s.markSceneReady()
        #expect(s.phase == .ready)
    }
}
