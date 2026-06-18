import Foundation

struct AssistantReply: Equatable, Sendable {
    let text: String
    let matchIDs: [String]
}

enum UniverseAssistantCore {
    static func reply(
        for query: String,
        tools: [Tool],
        categoryName: (ToolCategoryId) -> String,
        knowledge: @escaping (Tool) -> ToolKnowledge
    ) -> AssistantReply {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AssistantReply(text: "Ask what you want to find or paste a service URL.", matchIDs: [])
        }

        let matches = rankedMatches(
            for: trimmed,
            tools: tools,
            categoryName: categoryName,
            knowledge: knowledge
        )

        if matches.isEmpty {
            return missingReply(for: trimmed)
        }

        let topMatches = Array(matches.prefix(3))
        let rows = topMatches.map { tool in
            let info = knowledge(tool)
            return "| \(tool.name) | \(categoryName(tool.category)) | \(info.pricing) |"
        }
        return AssistantReply(
            text: """
            **Best matches**

            | Tool | Branch | Pricing |
            | --- | --- | --- |
            \(rows.joined(separator: "\n"))

            **Next:** open one below, or ask me to compare fit, pricing, and workflow stage.
            """,
            matchIDs: topMatches.map(\.id)
        )
    }

    private static func missingReply(for query: String) -> AssistantReply {
        let folded = fold(query)
        let broadPlatforms = ["google", "instagram", "facebook", "meta", "apple", "microsoft", "amazon"]
        if broadPlatforms.contains(where: { folded == $0 || folded.contains($0) }) {
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

    private static func fold(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
