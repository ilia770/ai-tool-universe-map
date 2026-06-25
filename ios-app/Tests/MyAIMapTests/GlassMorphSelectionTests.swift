import Testing
@testable import MyAIMap

@Suite("GlassMorphCluster selection logic")
struct GlassMorphSelectionTests {
    @Test func selectedOptionSharesTheSingleTravellingID() {
        // The selected slot carries the one "active" id; that shared id is what
        // makes a single glass shape morph between slots.
        #expect(GlassMorphSelection.glassID(optionIndex: 2, selectedIndex: 2, base: "tabs") == "tabs.active")
    }
    @Test func unselectedOptionsCarryStablePerSlotIDs() {
        #expect(GlassMorphSelection.glassID(optionIndex: 1, selectedIndex: 2, base: "tabs") == "tabs.option1")
    }
    @Test func clampGuardsAgainstStaleIndices() {
        #expect(GlassMorphSelection.clamped(5, count: 3) == 2)
        #expect(GlassMorphSelection.clamped(-1, count: 3) == 0)
        #expect(GlassMorphSelection.clamped(0, count: 0) == 0)
    }
}
