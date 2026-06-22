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

    // MARK: - Auto proposes a NEW branch when nothing fits (blueprint §8)

    @Test func autoProposesNewBranchFromCoreWhenNoKeywordFits() {
        // A novel domain with no built-in keyword, added from the centre.
        // (Fixture must avoid keyword substrings — e.g. "Agents" ⊃ "agent".)
        let proposed = AddToolLogic.proposedBranchName(
            name: "Zencove Whisper",
            website: "https://zencove.example",
            activeCategory: .core
        )
        #expect(proposed == "Zencove Whisper")
    }

    @Test func autoDoesNotProposeWhenAKeywordFits() {
        // "design" keyword hits → an existing branch is a good home.
        let proposed = AddToolLogic.proposedBranchName(
            name: "SomeDesignTool",
            website: "",
            activeCategory: .core
        )
        #expect(proposed == nil)
    }

    @Test func autoDoesNotProposeWhenFocusedOnABranch() {
        // From a real branch context, that branch is the natural home.
        let proposed = AddToolLogic.proposedBranchName(
            name: "Acme Voice Agents",
            website: "",
            activeCategory: .design
        )
        #expect(proposed == nil)
    }

    @Test func autoReasonAnnouncesNewBranchProposal() {
        let reason = AddToolLogic.autoReason(
            name: "Zencove Whisper",
            website: "",
            activeCategory: .core,
            suggestedCategory: .analytics
        )
        #expect(reason.contains("Zencove Whisper"))
        #expect(reason.contains("No existing branch fits"))
    }
}
