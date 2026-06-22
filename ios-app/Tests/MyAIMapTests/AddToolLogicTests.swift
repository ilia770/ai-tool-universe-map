import Testing
@testable import MyAIMap

@Suite("AddToolLogic — branch mode and auto suggestion")
struct AddToolLogicTests {
    @Test func autoModeResolvesToSuggestedBranch() {
        let resolved = AddToolLogic.resolvedCategory(
            mode: .auto,
            manualCategory: .design,
            suggestedCategory: .analytics
        )

        #expect(resolved == .analytics)
    }

    @Test func manualModeRespectsManualBranch() {
        let resolved = AddToolLogic.resolvedCategory(
            mode: .manual,
            manualCategory: .design,
            suggestedCategory: .analytics
        )

        #expect(resolved == .design)
    }

    @Test func postHogAutoSuggestsAnalyticsEvenFromDifferentActiveBranch() {
        let suggested = AddToolLogic.suggestedCategory(
            name: "PostHog",
            website: "https://posthog.com",
            activeCategory: .coding
        )

        #expect(suggested == .analytics)
    }

    @Test func randomToolFallsBackToActiveBranchInAutoMode() {
        let suggested = AddToolLogic.suggestedCategory(
            name: "Random User Tool",
            website: "",
            activeCategory: .design
        )

        #expect(suggested == .design)
    }

    @Test func blankAutoFallsBackToAnalyticsFromCore() {
        let suggested = AddToolLogic.suggestedCategory(
            name: "",
            website: "",
            activeCategory: .core
        )

        #expect(suggested == .analytics)
    }

    @Test func addRequiresNameOnly() {
        #expect(AddToolLogic.canAdd(name: "PostHog"))
        #expect(!AddToolLogic.canAdd(name: "   "))
    }
}
