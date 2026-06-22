import Testing
@testable import MyAIMap

@Suite("UniverseAssistantCore — truthful tool answers")
struct UniverseAssistantCoreTests {
    private func reply(_ query: String, tools: [Tool] = UniverseSeed.tools) -> AssistantReply {
        UniverseAssistantCore.reply(
            for: query,
            tools: tools,
            categoryName: { UniverseSeed.category($0).shortName },
            knowledge: { ToolKnowledgeBook.knowledge(for: $0) }
        )
    }

    @Test func postHogLivesInAnalytics() {
        let postHog = UniverseSeed.tools.first { $0.id == "posthog" }
        #expect(postHog?.category == .analytics)
    }

    @Test func databaseQueryFindsSupabaseFromKnowledge() {
        let reply = reply("fast postgres database")
        #expect(reply.matchIDs.contains("supabase"))
        #expect(reply.text.contains("Supabase"))
    }

    @Test func missingServiceAsksForWebsite() {
        let reply = reply("zzzapflow unknown service")
        #expect(reply.matchIDs.isEmpty)
        #expect(reply.text.contains("website URL"))
    }

    @Test func singleUnknownServiceStillAsksForWebsite() {
        let reply = reply("zzzapflow")
        #expect(reply.matchIDs.isEmpty)
        #expect(reply.text.contains("website URL"))
    }

    @Test func russianSmallTalkDoesNotReturnMissingService() {
        let reply = reply("как дела")
        #expect(reply.matchIDs.isEmpty)
        #expect(!reply.text.contains("I did not find this service"))
        #expect(!reply.text.contains("website URL"))
    }

    @Test func transliteratedSmallTalkDoesNotReturnMissingService() {
        let reply = reply("yak дела")
        #expect(reply.matchIDs.isEmpty)
        #expect(!reply.text.contains("I did not find this service"))
        #expect(!reply.text.contains("website URL"))
    }

    @Test func englishGreetingDoesNotReturnMissingService() {
        let reply = reply("how are you")
        #expect(reply.matchIDs.isEmpty)
        #expect(!reply.text.contains("I did not find this service"))
        #expect(!reply.text.contains("website URL"))
    }

    @Test func broadPlatformAsksForSpecificProduct() {
        let reply = reply("google")
        #expect(reply.matchIDs.isEmpty)
        #expect(reply.text.contains("broad platform"))
    }

    @Test func appWorkflowRecommendsExistingStackAndMissingTools() {
        let reply = reply("I need to create an app. Which tools should I use?")

        #expect(!reply.text.contains("I did not find this service"))
        #expect(reply.matchIDs.contains("figma"))
        #expect(reply.matchIDs.contains("codex"))
        #expect(reply.matchIDs.contains("supabase"))
        #expect(reply.text.contains("Fastest:"))
        #expect(reply.text.contains("Cheapest/free:"))
        #expect(reply.text.contains("Advanced/pro:"))
        #expect(reply.text.contains("Caveats / tradeoffs"))
        #expect(reply.missingToolSuggestions.map(\.name).contains("GitHub"))
        #expect(reply.missingToolSuggestions.map(\.name).contains("Sentry"))
    }

    @Test func designDomainUsesExistingToolsAndSuggestsAddableGaps() {
        let reply = reply("Which tool should I use for app design?")

        #expect(reply.matchIDs.contains("figma"))
        #expect(reply.matchIDs.contains("dessn"))
        // Framer ships in the sample seed, so it is an existing design tool and
        // must NOT be re-suggested as a gap (the suggestion filter drops tools
        // already present in the universe). Mobbin is absent, so it stays a gap.
        #expect(!reply.missingToolSuggestions.map(\.name).contains("Framer"))
        #expect(reply.missingToolSuggestions.map(\.name).contains("Mobbin"))
        #expect(reply.text.contains("Recommended tools"))
    }

    @Test func domainWithoutExistingToolSaysSoAndSuggestsMissingTools() {
        let tools = UniverseSeed.tools.filter { $0.category != .design }
        let reply = reply("Which tool should I use for app design?", tools: tools)

        #expect(reply.matchIDs.isEmpty)
        #expect(reply.text.contains("No strong existing design tool"))
        #expect(reply.missingToolSuggestions.count == 3)
        #expect(reply.missingToolSuggestions.allSatisfy { $0.pricingNote == "Pricing unknown, verify website." })
    }

    @Test func userAddedToolsAreVisibleInFutureAnswers() {
        let custom = Tool(
            id: "internal-builder",
            name: "Internal Builder",
            category: .coding,
            summary: "User-added internal app builder for admin tools.",
            stage: .execution,
            orbit: .inner,
            angle: -120,
            url: nil,
            logoDomain: nil,
            relationIds: [],
            classification: Tool.Classification(
                confidence: 0.48,
                matchedKeywords: ["coding"],
                reason: "User-added tool; needs website-backed enrichment."
            )
        )
        let reply = reply("internal app builder", tools: UniverseSeed.tools + [custom])

        #expect(reply.matchIDs.contains("internal-builder"))
        #expect(reply.text.contains("Pricing unknown") || reply.text.contains("Unknown pricing model"))
        #expect(reply.text.contains("Use cautious claims"))
    }

    // H2: naming a specific tool routes to the direct answer even when the
    // query also contains a domain word, so the exact hit is never dropped.
    @Test func namingAToolRoutesDirectEvenWithDomainWord() {
        let reply = reply("Supabase for video")
        #expect(reply.matchIDs.contains("supabase"))
    }

    // M4: Latin-transliterated RU small talk must not fall through to the
    // missing-service reply.
    @Test func transliteratedSingleWordGreetingIsSmallTalk() {
        let reply = reply("privet")
        #expect(reply.matchIDs.isEmpty)
        #expect(!reply.text.contains("website URL"))
        #expect(!reply.text.contains("I did not find this service"))
    }

    // R14: recommendation phrasing ("I need …", "looking for …") must route to
    // a domain/recommendation answer, not the missing-service URL request.
    @Test func iNeedADesignToolRoutesToRecommendation() {
        let reply = reply("I need a design tool")
        #expect(!reply.text.contains("I did not find this service"))
        #expect(!reply.text.contains("website URL"))
        #expect(reply.matchIDs.contains("figma"))
        #expect(reply.text.contains("Recommended tools"))
    }

    @Test func lookingForAnalyticsRoutesToRecommendation() {
        let reply = reply("looking for analytics")
        #expect(!reply.text.contains("I did not find this service"))
        #expect(!reply.text.contains("website URL"))
        #expect(reply.matchIDs.contains("posthog"))
        #expect(reply.text.contains("Recommended tools"))
    }

    // R15: a name-like short unknown query routes to the add-tool / missing
    // service path (asks for a website), instead of falling into generic chat.
    @Test func multiWordUnknownToolAsksForWebsite() {
        let reply = reply("Magic Canvas")
        #expect(reply.matchIDs.isEmpty)
        #expect(reply.text.contains("website URL"))
    }

    @Test func singleTokenUnknownToolAsksForWebsite() {
        let reply = reply("Zylo")
        #expect(reply.matchIDs.isEmpty)
        #expect(reply.text.contains("website URL"))
    }

    // §6 intent #4: an existing-universe inventory query ("what do I have for X")
    // lists the user's OWN tools — not a workflow recommendation and not a
    // missing-service prompt.
    @Test func inventoryQueryForDomainListsExistingTools() {
        let reply = reply("what tools do I have for analytics")
        #expect(reply.matchIDs.contains("posthog"))
        #expect(reply.text.contains("Your"))
        // Inventory answers are a plain listing, not the workflow Options block.
        #expect(!reply.text.contains("Fastest:"))
        #expect(!reply.text.contains("website URL"))
    }

    @Test func inventoryQueryWholeUniverseListsTools() {
        let reply = reply("what do I have in my universe")
        #expect(!reply.matchIDs.isEmpty)
        #expect(!reply.text.contains("website URL"))
        #expect(!reply.text.contains("I did not find this service"))
    }

    @Test func russianInventoryQueryListsTools() {
        let reply = reply("что у меня есть")
        #expect(!reply.matchIDs.isEmpty)
        #expect(!reply.text.contains("website URL"))
    }

    @Test func inventoryQueryForEmptyDomainSuggestsAdding() {
        let postHog = UniverseSeed.tools.first { $0.id == "posthog" }!
        let reply = reply("what do I have for design", tools: [postHog])
        #expect(reply.matchIDs.isEmpty)
        #expect(!reply.missingToolSuggestions.isEmpty)
    }
}
