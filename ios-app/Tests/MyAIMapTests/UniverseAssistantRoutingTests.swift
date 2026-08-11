import Testing
import Foundation
@testable import MyAIMap

@Suite("UniverseAssistantCore — intent routing")
struct UniverseAssistantRoutingTests {
    private func reply(_ query: String, tools: [Tool] = UniverseSeed.tools) -> AssistantReply {
        UniverseAssistantCore.reply(
            for: query,
            tools: tools,
            categoryName: { UniverseSeed.category($0).shortName },
            knowledge: { ToolKnowledgeBook.knowledge(for: $0) }
        )
    }

    // MARK: - isFullAppWorkflow AND-logic (asks AND app AND build)

    // Positive baseline lives in UniverseAssistantCoreTests; here we pin the
    // NEGATIVE: an app+build query missing an ASK term must NOT produce the
    // full app-workflow reply (which contains all three of Fastest/Cheapest/
    // Advanced *and* its app-workflow summary).
    @Test func appPlusBuildWithoutAskTermIsNotFullAppWorkflow() {
        let reply = reply("create an app and build it")
        #expect(!reply.text.contains("For an app workflow, use the existing universe as a stack"))
    }

    // ask+build but NO app term must NOT route to the full app-workflow reply.
    @Test func askPlusBuildWithoutAppTermIsNotFullAppWorkflow() {
        let reply = reply("which tool should I use to build")
        #expect(!reply.text.contains("For an app workflow, use the existing universe as a stack"))
    }

    // MARK: - domainIntent vs domainKeyword routing

    // A recommendation-phrased domain query routes to a domain recommendation
    // (infra), surfacing infra preferred tools.
    @Test func iNeedABackendRoutesToInfrastructureRecommendation() {
        let reply = reply("I need a backend")
        #expect(reply.matchIDs.contains("supabase"))
        #expect(reply.text.contains("Recommended tools"))
        #expect(!reply.text.contains("Your universe"))
    }

    // An inventory-phrased query ("what do I have for analytics") routes to the
    // inventory listing path (distinct Russian/possessive heading), not a
    // recommendation. Distinct from existing analytics inventory test by domain.
    @Test func whatDoIHaveForCodingRoutesToInventory() {
        let reply = reply("what do I have for coding")
        #expect(reply.text.contains("Your"))
        #expect(!reply.text.contains("Fastest:"))
    }

    // MARK: - Named-tool override

    // A distinctive tool name buried in a domain phrase answers about that tool
    // directly. "Vercel for analytics" — vercel is distinctive, analytics is a
    // domain word; the direct hit must survive.
    @Test func distinctiveToolNameWithDomainWordRoutesDirect() {
        let reply = reply("Vercel for analytics")
        #expect(reply.matchIDs.first == "vercel")
    }

    // A GENERIC single-token tool name that coincides with a domain word must
    // NOT hijack a domain query. "which tool for research" is a research-domain
    // ask, not a request for any tool literally named "Research".
    @Test func genericNameWordDoesNotHijackDomainQuery() {
        let reply = reply("which tool for research")
        // Routes to research domain recommendation, not a single direct hit.
        #expect(reply.text.contains("Recommended tools"))
        #expect(reply.missingToolSuggestions.map(\.name).contains("Perplexity"))
    }

    // MARK: - Low-confidence caveat via real ViewModel

    @MainActor
    @Test func lowConfidenceUserToolSurfacesCautiousCaveat() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let model = UniverseViewModel(store: UniverseStore(defaults: defaults))
        // Added with no URL → confidence ~0.48, url == nil → cautious branch.
        #expect(model.addCustomTool(name: "Mystery Builder", urlString: "", category: .coding))

        let reply = reply("Mystery Builder", tools: model.visibleAllTools)
        #expect(reply.matchIDs.contains { $0.contains("mystery-builder") })
        #expect(reply.text.contains("Use cautious claims"))
    }

    // MARK: - Empty / whitespace query

    @Test func emptyQueryReturnsSafePrompt() {
        let reply = reply("")
        #expect(reply.text == "Ask what you want to build, compare, or add to the universe.")
        #expect(reply.matchIDs.isEmpty)
    }

    @Test func whitespaceOnlyQueryReturnsSafePrompt() {
        let reply = reply("   \n\t ")
        #expect(reply.text == "Ask what you want to build, compare, or add to the universe.")
        #expect(reply.matchIDs.isEmpty)
    }

    // MARK: - Inventory for an empty domain suggests adding

    // Possessive inventory phrasing scoped to a domain the universe lacks →
    // "add one" prompt with suggestions, not a listing. Distinct from the
    // existing design-empty test: here we use a media-empty universe.
    @Test func inventoryForEmptyDomainSuggestsAdding() {
        let postHog = UniverseSeed.tools.first { $0.id == "posthog" }!
        let reply = reply("what do I have for video", tools: [postHog])
        #expect(reply.matchIDs.isEmpty)
        #expect(reply.text.contains("Add one from the chips below"))
        #expect(!reply.missingToolSuggestions.isEmpty)
    }
}
