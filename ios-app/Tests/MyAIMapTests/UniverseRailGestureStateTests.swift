import Testing
@testable import MyAIMap

@Suite("UniverseRailGestureState — keyboard must resign on activation")
struct UniverseRailGestureStateTests {

    @Test func beginningHoldResignsTheKeyboard() {
        var state = UniverseRailGestureState()
        var resignCount = 0

        state.begin(activeCategory: .analytics, activeIndex: 2) { resignCount += 1 }

        #expect(state.isActive)
        #expect(resignCount == 1)
    }

    @Test func beginningHoldWhileAlreadyActiveDoesNotResignAgain() {
        var state = UniverseRailGestureState()
        var resignCount = 0
        state.begin(activeCategory: .analytics, activeIndex: 2) { resignCount += 1 }

        state.begin(activeCategory: .analytics, activeIndex: 2) { resignCount += 1 }

        #expect(resignCount == 1)
    }

    @Test func beginSeedsHoverAndStartIndexAndActivates() {
        var state = UniverseRailGestureState()

        state.begin(activeCategory: .design, activeIndex: 4) {}

        #expect(state.hoveredCategory == .design)
        #expect(state.holdStartIndex == 4)
        #expect(state.isActive)
    }

    @Test func resetReturnsToInactive() {
        var state = UniverseRailGestureState()
        state.begin(activeCategory: .design, activeIndex: 4) {}

        state.reset()

        #expect(!state.isActive)
        #expect(state.hoveredCategory == nil)
        #expect(state.holdStartIndex == 0)
    }
}
