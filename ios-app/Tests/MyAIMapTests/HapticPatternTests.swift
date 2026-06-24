import Testing
@testable import MyAIMap

/// Unit coverage for the testable slices of the haptics foundation:
/// the graduated ticker tier logic, the `Pattern` enum shape, and the
/// in-app Haptics-toggle gate. Actual haptic playback is hardware-driven
/// and not unit-testable, so it is intentionally not faked here.
@Suite("Haptic patterns")
struct HapticPatternTests {

    // MARK: TickerTier (anti-machine-gun graduation)

    @Test func tickerTierSingleForOneOrLess() {
        #expect(TickerTier(count: 1) == .single)
        // Defensive: zero / negative deltas collapse to a single tick.
        #expect(TickerTier(count: 0) == .single)
        #expect(TickerTier(count: -3) == .single)
    }

    @Test func tickerTierArpeggioForTwoToFour() {
        #expect(TickerTier(count: 2) == .arpeggio(steps: 2))
        #expect(TickerTier(count: 3) == .arpeggio(steps: 3))
        #expect(TickerTier(count: 4) == .arpeggio(steps: 4))
    }

    @Test func tickerTierSwellForFiveOrMore() {
        #expect(TickerTier(count: 5) == .swell)
        #expect(TickerTier(count: 12) == .swell)
        #expect(TickerTier(count: 999) == .swell)
    }

    @Test func tickerTierBoundariesAreContiguous() {
        // No gap or overlap across the three tiers for 1...6.
        let tiers = (1...6).map { TickerTier(count: $0) }
        #expect(tiers == [
            .single,
            .arpeggio(steps: 2),
            .arpeggio(steps: 3),
            .arpeggio(steps: 4),
            .swell,
            .swell,
        ])
    }

    // MARK: Pattern enum

    @Test func tickerPatternsDistinguishByCount() {
        #expect(CoreHapticsEngine.Pattern.ticker(count: 1)
            != CoreHapticsEngine.Pattern.ticker(count: 2))
        #expect(CoreHapticsEngine.Pattern.ticker(count: 3)
            == CoreHapticsEngine.Pattern.ticker(count: 3))
    }

    @Test func toolLandIsDistinctFromExistingPatterns() {
        #expect(CoreHapticsEngine.Pattern.toolLand != .pocketOpen)
        #expect(CoreHapticsEngine.Pattern.toolLand != .classifySuccess)
    }

    // MARK: In-app Haptics gate

    @MainActor
    @Test func playReturnsFalseWhenHapticsDisabled() {
        let previous = BrandHaptics.isEnabled
        defer { BrandHaptics.isEnabled = previous }

        BrandHaptics.isEnabled = false
        // Regardless of hardware, a disabled toggle must short-circuit.
        #expect(CoreHapticsEngine.shared.play(.toolLand) == false)
        #expect(CoreHapticsEngine.shared.play(.ticker(count: 3)) == false)
        #expect(CoreHapticsEngine.shared.play(.pocketOpen) == false)
    }
}
