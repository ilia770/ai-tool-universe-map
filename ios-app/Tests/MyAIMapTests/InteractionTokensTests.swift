import Testing
import SwiftUI
@testable import MyAIMap

@Suite("Interaction tokens")
struct InteractionTokensTests {

    @Test func tokensMatchWebContract() {
        // Literal parity with src/playground/designSystem.ts so both lanes
        // dismiss/peek at the same thresholds.
        #expect(InteractionTokens.longPressSeconds == 0.42)
        #expect(InteractionTokens.dismissDistance == 100)
        #expect(InteractionTokens.dismissVelocity == 0.5)
        #expect(InteractionTokens.dismissResistance == 0.25)
        #expect(InteractionTokens.peekSeconds == 0.40)
    }

    @Test func dismissCommitsPastDistanceOrFlick() {
        #expect(InteractionTokens.shouldDismiss(translation: 101, velocity: 0))
        #expect(InteractionTokens.shouldDismiss(translation: 10, velocity: 0.6))
        #expect(!InteractionTokens.shouldDismiss(translation: 10, velocity: 0))
    }

    @Test func rubberBandFollowsDownOnlyAndResistsUp() {
        #expect(InteractionTokens.rubberBand(50) == 50)            // down: 1:1
        #expect(InteractionTokens.rubberBand(-100) == -25)         // up: resisted
    }

    @Test func swipeProgressIsClampedAndUsesRubberBand() {
        // Downward drag follows 1:1.
        #expect(SwipeDismissModel.offset(for: 80) == 80)
        // Upward drag is resisted (rubber-banded), never positive past 0.
        #expect(SwipeDismissModel.offset(for: -40) == -10)
    }

    @Test func swipeCommitMatchesContract() {
        #expect(SwipeDismissModel.commits(translation: 120, velocity: 0))
        #expect(SwipeDismissModel.commits(translation: 5, velocity: 0.7))
        #expect(!SwipeDismissModel.commits(translation: 5, velocity: 0.1))
    }
}
