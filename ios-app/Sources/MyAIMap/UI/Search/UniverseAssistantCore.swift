import Foundation

struct AssistantReply: Equatable, Sendable {
    let text: String
    let matchIDs: [String]
    let missingToolSuggestions: [MissingToolSuggestion]

    init(
        text: String,
        matchIDs: [String] = [],
        missingToolSuggestions: [MissingToolSuggestion] = []
    ) {
        self.text = text
        self.matchIDs = matchIDs
        self.missingToolSuggestions = missingToolSuggestions
    }
}

enum UniverseAssistantCore {
    static func reply(
        for query: String,
        tools: [Tool],
        categoryName: (ToolCategoryId) -> String,
        knowledge: @escaping (Tool) -> ToolKnowledge,
        recentActivity: [UniverseActivity] = []
    ) -> AssistantReply {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AssistantReply(text: "Ask what you want to build, compare, or add to the universe.")
        }

        let matches = rankedMatches(
            for: trimmed,
            tools: tools,
            categoryName: categoryName,
            knowledge: knowledge
        )

        let folded = fold(trimmed)
        if let domain = domainIntent(for: folded),
           !isFullAppWorkflow(folded) {
            return domainReply(
                for: trimmed,
                domain: domain,
                directMatches: matches,
                tools: tools,
                categoryName: categoryName,
                knowledge: knowledge,
                recentActivity: recentActivity
            )
        }

        if isFullAppWorkflow(folded) {
            return appWorkflowReply(
                for: trimmed,
                directMatches: matches,
                tools: tools,
                categoryName: categoryName,
                knowledge: knowledge,
                recentActivity: recentActivity
            )
        }

        if matches.isEmpty {
            return noMatchReply(for: trimmed)
        }

        let topMatches = Array(matches.prefix(4))
        return directMatchReply(
            for: trimmed,
            matches: topMatches,
            tools: tools,
            categoryName: categoryName,
            knowledge: knowledge,
            recentActivity: recentActivity
        )
    }

    private static func appWorkflowReply(
        for query: String,
        directMatches: [Tool],
        tools: [Tool],
        categoryName: (ToolCategoryId) -> String,
        knowledge: (Tool) -> ToolKnowledge,
        recentActivity: [UniverseActivity]
    ) -> AssistantReply {
        let preferredIDs = [
            "figma", "codex", "cursor", "supabase", "vercel", "posthog",
            "founder-os", "claude-code", "dessn", "agent-skills", "openswarm",
        ]
        let workflowCategories: [ToolCategoryId] = [
            .core, .design, .coding, .infrastructure, .analytics, .knowledge,
        ]
        let candidates = orderedTools(
            preferredIDs: preferredIDs,
            directMatches: directMatches,
            fallback: tools.filter { workflowCategories.contains($0.category) },
            limit: 6
        )
        let suggestions = missingSuggestions(from: appWorkflowSuggestions, tools: tools, limit: 3)
        let summary: String
        if candidates.isEmpty {
            summary = "I do not see app-building tools in the current universe yet. Add a design tool, a coding agent, a backend/runtime, and analytics first."
        } else {
            summary = "For an app workflow, use the existing universe as a stack: \(names(candidates.prefix(4))). Add the missing chips only where the current map has a gap."
        }

        return AssistantReply(
            text: structuredText(
                summary: summary,
                recommended: recommendedLines(
                    for: candidates,
                    allTools: tools,
                    categoryName: categoryName,
                    knowledge: knowledge
                ),
                noExistingLine: candidates.isEmpty ? "No strong existing app-workflow stack is visible in this universe yet." : nil,
                fastest: fastestAppPath(candidates: candidates, suggestions: suggestions),
                cheapest: cheapestPath(candidates: candidates),
                easiest: easiestAppPath(candidates: candidates),
                advanced: advancedAppPath(candidates: candidates, suggestions: suggestions),
                caveats: caveats(
                    for: candidates,
                    suggestions: suggestions,
                    knowledge: knowledge,
                    recentActivity: recentActivity
                )
            ),
            matchIDs: candidates.map(\.id),
            missingToolSuggestions: suggestions
        )
    }

    private static func domainReply(
        for query: String,
        domain: ToolCategoryId,
        directMatches: [Tool],
        tools: [Tool],
        categoryName: (ToolCategoryId) -> String,
        knowledge: (Tool) -> ToolKnowledge,
        recentActivity: [UniverseActivity]
    ) -> AssistantReply {
        let domainTools = orderedTools(
            preferredIDs: preferredIDs(for: domain),
            directMatches: directMatches.filter { $0.category == domain },
            fallback: tools.filter { $0.category == domain },
            limit: 4
        )
        let suggestions = missingSuggestions(from: suggestionTemplates(for: domain), tools: tools, limit: 3)
        let domainLabel = categoryName(domain).lowercased()
        let noExisting = domainTools.isEmpty
            ? "No strong existing \(domainLabel) tool is visible in the current universe."
            : nil
        let summary: String
        if domainTools.isEmpty {
            summary = "I would add a \(domainLabel) tool before choosing a workflow. The universe does not currently show a strong existing option for that domain."
        } else {
            summary = "Start with \(names(domainTools.prefix(2))) from the existing \(domainLabel) branch, then add a missing specialist only if that gap matters."
        }

        return AssistantReply(
            text: structuredText(
                summary: summary,
                recommended: recommendedLines(
                    for: domainTools,
                    allTools: tools,
                    categoryName: categoryName,
                    knowledge: knowledge
                ),
                noExistingLine: noExisting,
                fastest: fastestDomainPath(domain: domain, tools: domainTools, suggestions: suggestions),
                cheapest: cheapestPath(candidates: domainTools),
                easiest: easiestDomainPath(domain: domain, tools: domainTools, suggestions: suggestions),
                advanced: advancedDomainPath(domain: domain, tools: domainTools, suggestions: suggestions),
                caveats: caveats(
                    for: domainTools,
                    suggestions: suggestions,
                    knowledge: knowledge,
                    recentActivity: recentActivity
                )
            ),
            matchIDs: domainTools.map(\.id),
            missingToolSuggestions: suggestions
        )
    }

    private static func directMatchReply(
        for query: String,
        matches: [Tool],
        tools: [Tool],
        categoryName: (ToolCategoryId) -> String,
        knowledge: (Tool) -> ToolKnowledge,
        recentActivity: [UniverseActivity]
    ) -> AssistantReply {
        let suggestions = relatedMissingSuggestions(for: matches, tools: tools, limit: 2)
        return AssistantReply(
            text: structuredText(
                summary: "I found matching tools already in the universe. Open the chips below to inspect details before adding anything new.",
                recommended: recommendedLines(
                    for: matches,
                    allTools: tools,
                    categoryName: categoryName,
                    knowledge: knowledge
                ),
                noExistingLine: nil,
                fastest: matches.first.map { "Open \($0.name) and use its related tools for the next step." } ?? "Open the best match first.",
                cheapest: cheapestPath(candidates: matches),
                easiest: matches.first.map { "Use \($0.name) if its current tradeoffs fit the job." } ?? "Pick the clearest existing match.",
                advanced: "Ask a follow-up comparison if you need stage, relation, or tradeoff ranking.",
                caveats: caveats(
                    for: matches,
                    suggestions: suggestions,
                    knowledge: knowledge,
                    recentActivity: recentActivity
                )
            ),
            matchIDs: matches.map(\.id),
            missingToolSuggestions: suggestions
        )
    }

    private static func noMatchReply(for query: String) -> AssistantReply {
        if isGeneralConversation(query) {
            return generalReply(for: query)
        }
        return missingReply(for: query)
    }

    private static func generalReply(for query: String) -> AssistantReply {
        AssistantReply(
            text: """
            **I am here.**

            Ask me normally, or tell me what you are trying to build. I can recommend tools already in your universe, compare branches, or help add a missing service when you name one.

            **Next:** ask for a workflow, a tool recommendation, or a specific service.
            """,
            matchIDs: []
        )
    }

    private static func missingReply(for query: String) -> AssistantReply {
        let folded = fold(query)
        let broadPlatforms = ["google", "instagram", "facebook", "meta", "apple", "microsoft", "amazon"]
        // Match whole tokens, not substrings — otherwise "metabase", "metadata",
        // "apple notes alternative" all falsely trip the broad-platform branch.
        let tokens = Set(folded.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        if broadPlatforms.contains(where: { folded == $0 || tokens.contains($0) }) {
            return AssistantReply(
                text: """
                **Need a specific product**

                - This looks like a broad platform, not one exact tool.
                - Send the product page or a precise use case.
                - I will place only the relevant branch and relations.

                **Next:** paste a product page or attach files with context.
                """,
                matchIDs: []
            )
        }

        return AssistantReply(
            text: """
            **I did not find this service in the universe.**

            - Send its website URL.
            - I will classify it, name the right branch, and suggest only point-specific relations.

            **Next:** add the tool or attach files so I can read the context.
            """,
            matchIDs: []
        )
    }

    private static func isGeneralConversation(_ query: String) -> Bool {
        let folded = fold(query)
        let serviceWords = [
            "add", "tool", "service", "website", "url", "app", "platform", "find",
            "lookup", "search", "добав", "сервис", "инструмент", "сайт", "найди",
        ]
        if containsAny(folded, serviceWords) {
            return false
        }

        let smallTalk = [
            "hi", "hello", "hey", "yo", "how are you", "how r u", "whats up",
            "what's up", "thanks", "thank you", "привет", "здравствуи",
            "здравствуй", "как дела", "как ты", "спасибо",
        ]
        if containsAny(folded, smallTalk) {
            return true
        }

        let tokens = folded
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        if tokens.contains("yak"), tokens.contains("дела") {
            return true
        }

        // Short unmatched natural-language fragments are not enough evidence
        // for a service lookup. Keep them in general chat unless the user
        // names a tool/service/add intent above.
        return tokens.count >= 2
    }

    private static func structuredText(
        summary: String,
        recommended: [String],
        noExistingLine: String?,
        fastest: String,
        cheapest: String,
        easiest: String,
        advanced: String,
        caveats: [String]
    ) -> String {
        let recommendedBlock: String
        if let noExistingLine {
            recommendedBlock = "- \(noExistingLine)"
        } else if recommended.isEmpty {
            recommendedBlock = "- No matching existing tool is visible yet."
        } else {
            recommendedBlock = recommended.map { "- \($0)" }.joined(separator: "\n")
        }

        let caveatBlock = caveats.map { "- \($0)" }.joined(separator: "\n")
        return """
        **Summary**
        \(summary)

        **Recommended tools**
        \(recommendedBlock)

        **Options**
        - Fastest: \(fastest)
        - Cheapest/free: \(cheapest)
        - Easiest: \(easiest)
        - Advanced/pro: \(advanced)

        **Caveats / tradeoffs**
        \(caveatBlock)

        **Action chips**
        Open existing tool chips for details. Add suggested missing tools from their chips; pricing unknown, verify website before relying on them.
        """
    }

    private static func recommendedLines(
        for tools: [Tool],
        allTools: [Tool],
        categoryName: (ToolCategoryId) -> String,
        knowledge: (Tool) -> ToolKnowledge
    ) -> [String] {
        tools.map { tool in
            let info = knowledge(tool)
            let relationText = relatedNames(for: tool, in: allTools).isEmpty
                ? ""
                : " Related: \(relatedNames(for: tool, in: allTools).joined(separator: ", "))."
            return "\(tool.name) (\(categoryName(tool.category))) - \(firstSentence(info.useCase)) Pricing: \(safePricing(info.pricing))\(relationText)"
        }
    }

    private static func caveats(
        for tools: [Tool],
        suggestions: [MissingToolSuggestion],
        knowledge: (Tool) -> ToolKnowledge,
        recentActivity: [UniverseActivity]
    ) -> [String] {
        var lines: [String] = []
        let unknownPricingTools = tools.filter { safePricing(knowledge($0).pricing).lowercased().contains("unknown") }
        if unknownPricingTools.isEmpty {
            lines.append("Pricing notes come only from local universe knowledge; verify live websites before purchase.")
        } else {
            lines.append("Pricing unknown for \(names(unknownPricingTools)); verify website before relying on it.")
        }
        if !suggestions.isEmpty {
            lines.append("Missing suggestions are popular candidates, not verified entries in your universe yet; pricing unknown, verify website.")
        }
        let cautiousTools = tools.filter { ($0.classification?.confidence ?? 1) < 0.75 || $0.url == nil }
        if !cautiousTools.isEmpty {
            lines.append("Use cautious claims for \(names(cautiousTools.prefix(3))); details are local or not website-verified.")
        }
        if let recent = recentActivity.first(where: { $0.kind == .added || $0.kind == .focused }) {
            lines.append("Recent context: \(recent.title) - \(recent.detail).")
        }
        if lines.isEmpty {
            lines.append("Tradeoffs depend on workflow stage, team skill, and current plan limits.")
        }
        return lines
    }

    private static func rankedMatches(
        for query: String,
        tools: [Tool],
        categoryName: (ToolCategoryId) -> String,
        knowledge: @escaping (Tool) -> ToolKnowledge
    ) -> [Tool] {
        let directMatches = SearchCore.results(
            for: query,
            in: tools,
            categoryName: categoryName,
            extraText: { knowledge($0).searchableText }
        )
        if !directMatches.isEmpty {
            return directMatches
        }

        let stopWords: Set<String> = [
            "find", "tool", "service", "app", "apps", "for", "with", "and", "the", "a", "an", "ai",
            "fast", "some", "unknown", "missing", "totally",
        ]
        let tokens = fold(query)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 && !stopWords.contains($0) }

        guard !tokens.isEmpty else { return [] }

        var scores: [String: Int] = [:]
        for token in tokens {
            for tool in SearchCore.results(
                for: token,
                in: tools,
                categoryName: categoryName,
                extraText: { knowledge($0).searchableText }
            ) {
                scores[tool.id, default: 0] += 1
            }
        }

        let minimumScore = tokens.count > 1 ? 2 : 1
        return Array(
            tools
                .filter { scores[$0.id, default: 0] >= minimumScore }
                .sorted { lhs, rhs in
                    let leftScore = scores[lhs.id, default: 0]
                    let rightScore = scores[rhs.id, default: 0]
                    if leftScore != rightScore {
                        return leftScore > rightScore
                    }
                    let leftIndex = tools.firstIndex { $0.id == lhs.id } ?? 0
                    let rightIndex = tools.firstIndex { $0.id == rhs.id } ?? 0
                    return leftIndex < rightIndex
                }
                .prefix(SearchCore.maxResults)
        )
    }

    private static func orderedTools(
        preferredIDs: [String],
        directMatches: [Tool],
        fallback: [Tool],
        limit: Int
    ) -> [Tool] {
        var ordered: [Tool] = []
        appendUnique(tools: preferredIDs.compactMap { id in
            fallback.first { $0.id == id } ?? directMatches.first { $0.id == id }
        }, to: &ordered)
        appendUnique(tools: directMatches, to: &ordered)
        appendUnique(tools: fallback, to: &ordered)
        return Array(ordered.prefix(limit))
    }

    private static func appendUnique(tools: [Tool], to ordered: inout [Tool]) {
        for tool in tools where !ordered.contains(where: { $0.id == tool.id }) {
            ordered.append(tool)
        }
    }

    private static func missingSuggestions(
        from templates: [SuggestionTemplate],
        tools: [Tool],
        limit: Int
    ) -> [MissingToolSuggestion] {
        // Dedupe by slug (== MissingToolSuggestion.id) before capping, so two
        // templates resolving to the same id never collide in SwiftUI ForEach
        // and never waste a limit slot on a duplicate.
        var seen = Set<String>()
        return Array(
            templates
                .filter { template in !containsTool(named: template.name, in: tools) }
                .filter { template in seen.insert(MissingToolSuggestion.slug(for: template.name)).inserted }
                .prefix(limit)
                .map { $0.suggestion }
        )
    }

    private static func relatedMissingSuggestions(
        for tools: [Tool],
        tools allTools: [Tool],
        limit: Int
    ) -> [MissingToolSuggestion] {
        let relatedIDs = tools.flatMap(\.relationIds)
        let relatedNames = relatedIDs.filter { id in !allTools.contains { $0.id == id } }
        let templates = relatedNames.compactMap { missingTemplate(forRelatedID: $0) }
        return missingSuggestions(from: templates, tools: allTools, limit: limit)
    }

    private static func containsTool(named name: String, in tools: [Tool]) -> Bool {
        let slug = MissingToolSuggestion.slug(for: name)
        return tools.contains { tool in
            tool.id == slug || MissingToolSuggestion.slug(for: tool.name) == slug
        }
    }

    private static func isFullAppWorkflow(_ folded: String) -> Bool {
        let asks = containsAny(
            folded,
            [
                "which tool", "which tools", "what tool", "what tools", "should i use",
                "recommend", "workflow", "stack", "need to", "i need", "use for",
                "какой", "какие", "что использовать", "посовет", "подбери", "нужно", "надо",
            ]
        )
        let app = containsAny(
            folded,
            ["create an app", "build an app", "make an app", "create app", "build app", "mvp", "web app", "website", "прилож", "сайт"]
        )
        let build = containsAny(
            folded,
            ["create", "build", "make", "launch", "ship", "develop", "собрать", "создать", "сделать", "запустить", "разработ"]
        )
        return asks && app && build
    }

    private static func domainIntent(for folded: String) -> ToolCategoryId? {
        guard containsAny(
            folded,
            [
                "which tool", "which tools", "what tool", "what tools", "should i use",
                "recommend", "best for", "use for", "какой", "какие", "что использовать",
                "посовет", "подбери", "нужно", "надо",
            ]
        ) else { return nil }

        let domains: [(ToolCategoryId, [String])] = [
            (.design, ["design", "ui", "ux", "prototype", "mockup", "wireframe", "figma", "дизайн", "интерфейс", "макет", "прототип"]),
            (.coding, ["code", "coding", "developer", "development", "repo", "refactor", "agentic dev", "код", "разработ", "репозитор"]),
            (.infrastructure, ["backend", "database", "postgres", "auth", "deploy", "hosting", "runtime", "server", "бэкенд", "база", "деплой", "сервер"]),
            (.analytics, ["analytics", "events", "funnel", "growth", "tracking", "session replay", "аналит", "воронк", "метрик"]),
            (.media, ["video", "media", "creative", "avatar", "motion", "генерац", "видео", "креатив"]),
            (.distribution, ["social", "publish", "content", "distribution", "launch campaign", "публикац", "контент", "соцсет"]),
            (.research, ["research", "scrape", "extract", "data intake", "source", "исслед", "парс", "данн", "источник"]),
            (.knowledge, ["knowledge", "skills", "playbook", "workflow memory", "agent skill", "знани", "скилл", "процедур"]),
        ]
        return domains.first { _, terms in containsAny(folded, terms) }?.0
    }

    private static func preferredIDs(for domain: ToolCategoryId) -> [String] {
        switch domain {
        case .coding: return ["codex", "cursor", "claude-code"]
        case .design: return ["figma", "dessn"]
        case .research: return ["supadata"]
        case .analytics: return ["posthog"]
        case .media: return ["remotion", "runway", "heygen", "higgsfield"]
        case .distribution: return ["buffer"]
        case .infrastructure: return ["supabase", "vercel"]
        case .knowledge: return ["agent-skills", "founder-os"]
        case .core: return ["founder-os", "openswarm"]
        }
    }

    private static func suggestionTemplates(for domain: ToolCategoryId) -> [SuggestionTemplate] {
        switch domain {
        case .coding:
            return [
                SuggestionTemplate("GitHub", .coding, "Repository hosting, collaboration, and pull-request workflow."),
                SuggestionTemplate("Replit", .coding, "Cloud coding workspace for quick prototypes."),
                SuggestionTemplate("Lovable", .coding, "AI app builder for fast full-stack prototypes."),
            ]
        case .design:
            return [
                SuggestionTemplate("Framer", .design, "Visual website and landing-page builder for polished frontends."),
                SuggestionTemplate("Mobbin", .design, "UI pattern research for mobile and web product design."),
                SuggestionTemplate("Relume", .design, "Sitemap and wireframe generation for early product structure."),
            ]
        case .research:
            return [
                SuggestionTemplate("Perplexity", .research, "Answer and source research before workflow decisions."),
                SuggestionTemplate("Firecrawl", .research, "Website crawling and extraction for AI-ready context."),
                SuggestionTemplate("Apify", .research, "Hosted scraping actors and data collection workflows."),
            ]
        case .analytics:
            return [
                SuggestionTemplate("Mixpanel", .analytics, "Product analytics and funnel exploration."),
                SuggestionTemplate("Amplitude", .analytics, "Behavior analytics for product and growth teams."),
                SuggestionTemplate("Sentry", .analytics, "Error monitoring and performance visibility."),
            ]
        case .media:
            return [
                SuggestionTemplate("CapCut", .media, "Fast editing for short-form launch assets."),
                SuggestionTemplate("ElevenLabs", .media, "Voice generation for explainers and product media."),
                SuggestionTemplate("Midjourney", .media, "Image ideation for creative direction."),
            ]
        case .distribution:
            return [
                SuggestionTemplate("Hootsuite", .distribution, "Social scheduling and publishing operations."),
                SuggestionTemplate("Beehiiv", .distribution, "Newsletter publishing and audience growth."),
                SuggestionTemplate("Taplio", .distribution, "LinkedIn content workflow and scheduling."),
            ]
        case .infrastructure:
            return [
                SuggestionTemplate("Neon", .infrastructure, "Serverless Postgres option for database-heavy apps."),
                SuggestionTemplate("Railway", .infrastructure, "Simple app and service deployment platform."),
                SuggestionTemplate("Firebase", .infrastructure, "Backend, auth, hosting, and mobile app services."),
            ]
        case .knowledge:
            return [
                SuggestionTemplate("Notion", .knowledge, "Shared docs, product specs, and team knowledge."),
                SuggestionTemplate("Obsidian", .knowledge, "Local knowledge base for connected notes."),
                SuggestionTemplate("Linear", .knowledge, "Issue tracking and product execution memory."),
            ]
        case .core:
            return [
                SuggestionTemplate("OpenAI Platform", .core, "Model and API layer for AI-native workflows."),
                SuggestionTemplate("Anthropic Console", .core, "Model console for Claude-based workflows."),
                SuggestionTemplate("LangSmith", .core, "LLM tracing, evals, and workflow observability."),
            ]
        }
    }

    private static let appWorkflowSuggestions: [SuggestionTemplate] = [
        SuggestionTemplate("GitHub", .coding, "Source control, issues, reviews, and integration hub for the app."),
        SuggestionTemplate("Linear", .knowledge, "Planning and execution tracker for the build loop."),
        SuggestionTemplate("Sentry", .analytics, "Error monitoring after the app ships."),
    ]

    private static func missingTemplate(forRelatedID id: String) -> SuggestionTemplate? {
        switch id {
        case "framer":
            return SuggestionTemplate("Framer", .design, "Website and prototype builder related to Figma workflows.")
        case "paper-design":
            return SuggestionTemplate("Paper Design", .design, "Design exploration tool related to Figma workflows.")
        case "vscode":
            return SuggestionTemplate("VS Code", .coding, "General editor related to Cursor workflows.")
        case "warp":
            return SuggestionTemplate("Warp", .coding, "AI terminal related to coding workflows.")
        case "docker":
            return SuggestionTemplate("Docker", .infrastructure, "Container runtime related to deployment workflows.")
        case "genmedia":
            return SuggestionTemplate("Genmedia Stack", .media, "Creative-media generation stack related to Remotion.")
        case "distribution-loop":
            return SuggestionTemplate("Distribution Loop", .distribution, "Launch and publishing workflow related to Buffer.")
        case "api-mega-list":
            return SuggestionTemplate("API Mega List", .research, "API discovery reference related to data intake.")
        default:
            return nil
        }
    }

    private static func fastestAppPath(candidates: [Tool], suggestions: [MissingToolSuggestion]) -> String {
        let chain = preferredNames(["figma", "codex", "cursor", "supabase", "vercel"], in: candidates)
        if chain.isEmpty {
            return "Add the missing chips for design, coding, backend, and deployment, then run one thin MVP path."
        }
        return "Use \(chain.joined(separator: " -> ")) for one thin MVP path."
    }

    private static func easiestAppPath(candidates: [Tool]) -> String {
        let chain = preferredNames(["founder-os", "figma", "cursor", "codex"], in: candidates)
        return chain.isEmpty
            ? "Start with one design tool and one coding agent; keep the first build narrow."
            : "Let \(chain.joined(separator: " + ")) handle planning, UI direction, and implementation."
    }

    private static func advancedAppPath(candidates: [Tool], suggestions: [MissingToolSuggestion]) -> String {
        let chain = preferredNames(["claude-code", "codex", "agent-skills", "openswarm", "posthog"], in: candidates)
        if chain.isEmpty {
            return "Add repo, agent-skill, observability, and issue-tracking tools before scaling the workflow."
        }
        return "Combine \(chain.joined(separator: " + ")) for repo work, reusable agent procedures, and review loops."
    }

    private static func fastestDomainPath(
        domain: ToolCategoryId,
        tools: [Tool],
        suggestions: [MissingToolSuggestion]
    ) -> String {
        if let first = tools.first {
            return "Open \(first.name), then use the closest related chip before adding new tools."
        }
        if let first = suggestions.first {
            return "Add \(first.name) first, then compare it with the next two suggestions."
        }
        return "Add one verified tool in this branch before deciding."
    }

    private static func easiestDomainPath(
        domain: ToolCategoryId,
        tools: [Tool],
        suggestions: [MissingToolSuggestion]
    ) -> String {
        if let first = tools.first {
            return "Use \(first.name) as the default until a specific tradeoff blocks you."
        }
        if let first = suggestions.first {
            return "Start by adding \(first.name), then verify the website before making claims."
        }
        return "Pick the simplest tool with verified docs and pricing."
    }

    private static func advancedDomainPath(
        domain: ToolCategoryId,
        tools: [Tool],
        suggestions: [MissingToolSuggestion]
    ) -> String {
        let existing = names(tools.prefix(2))
        let missing = names(suggestions.prefix(2))
        if !existing.isEmpty && !missing.isEmpty {
            return "Use \(existing) plus add \(missing) if you need specialist coverage."
        }
        if !existing.isEmpty {
            return "Compare \(existing) against related tools and plan limits."
        }
        if !missing.isEmpty {
            return "Add \(missing), then enrich details before recommending deeply."
        }
        return "Build a branch with at least two comparable tools before advanced recommendations."
    }

    private static func cheapestPath(candidates: [Tool]) -> String {
        if candidates.isEmpty {
            return "Use free trials or free tiers only after verifying current limits on each website."
        }
        let names = names(candidates.prefix(3))
        return "Start with \(names); many entries are freemium/subscription or usage based, so verify current free limits."
    }

    private static func preferredNames(_ ids: [String], in tools: [Tool]) -> [String] {
        ids.compactMap { id in tools.first { $0.id == id }?.name }
    }

    private static func relatedNames(for tool: Tool, in tools: [Tool]) -> [String] {
        Array(tool.relationIds.compactMap { id in tools.first { $0.id == id }?.name }.prefix(3))
    }

    private static func firstSentence(_ text: String) -> String {
        let separators = CharacterSet(charactersIn: ".!?")
        let sentence = text.components(separatedBy: separators).first ?? text
        return sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func safePricing(_ pricing: String) -> String {
        pricing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Pricing unknown, verify website."
            : pricing
    }

    private static func names<S: Sequence>(_ tools: S) -> String where S.Element == Tool {
        tools.map(\.name).joined(separator: ", ")
    }

    private static func names<S: Sequence>(_ suggestions: S) -> String where S.Element == MissingToolSuggestion {
        suggestions.map(\.name).joined(separator: ", ")
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func fold(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private struct SuggestionTemplate: Equatable {
        let name: String
        let category: ToolCategoryId
        let reason: String

        init(_ name: String, _ category: ToolCategoryId, _ reason: String) {
            self.name = name
            self.category = category
            self.reason = reason
        }

        var suggestion: MissingToolSuggestion {
            MissingToolSuggestion(name: name, category: category, reason: reason)
        }
    }
}
