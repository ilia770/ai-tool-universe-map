import Testing
@testable import MyAIMap

@Suite("UniverseAssistantCore — truthful tool answers")
struct UniverseAssistantCoreTests {

    @Test func postHogLivesInAnalytics() {
        let postHog = UniverseSeed.tools.first { $0.id == "posthog" }
        #expect(postHog?.category == .analytics)
    }

    @Test func databaseQueryFindsSupabaseFromKnowledge() {
        let reply = UniverseAssistantCore.reply(
            for: "fast postgres database",
            tools: UniverseSeed.tools,
            categoryName: { UniverseSeed.category($0).shortName },
            knowledge: { ToolKnowledgeBook.knowledge(for: $0) }
        )
        #expect(reply.matchIDs.contains("supabase"))
        #expect(reply.text.contains("Supabase"))
    }

    @Test func missingServiceAsksForWebsite() {
        let reply = UniverseAssistantCore.reply(
            for: "totally missing ai app",
            tools: UniverseSeed.tools,
            categoryName: { UniverseSeed.category($0).shortName },
            knowledge: { ToolKnowledgeBook.knowledge(for: $0) }
        )
        #expect(reply.matchIDs.isEmpty)
        #expect(reply.text.contains("website URL"))
    }

    @Test func broadPlatformAsksForSpecificProduct() {
        let reply = UniverseAssistantCore.reply(
            for: "google",
            tools: UniverseSeed.tools,
            categoryName: { UniverseSeed.category($0).shortName },
            knowledge: { ToolKnowledgeBook.knowledge(for: $0) }
        )
        #expect(reply.matchIDs.isEmpty)
        #expect(reply.text.contains("broad platform"))
    }
}
