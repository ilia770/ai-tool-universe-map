import Foundation

/// Pure natural-language query engine for the ChatDock. Foundation-only
/// (no SwiftUI / RealityKit) so it stays independently testable from
/// `MyAIMapTests`, matching the `SearchCore` and `UniverseLayout`
/// pure-core pattern.
///
/// Direct port of the web playground's `src/playground/query.ts`: tokenise
/// the ask, drop stopwords, map intent words to category hints, score
/// every tool, and build a one-line answer from the top match. The "brain"
/// is the structured seed data + this ranker — no backend, instant.
enum QueryEngine {

    /// Web parity: `matches = scored.slice(0, 5)`.
    static let maxResults = 5

    struct Result: Sendable {
        let matches: [Tool]
        let answer: String
    }

    /// Tokens dropped before scoring (web parity: `STOPWORDS`). English +
    /// the few Russian fillers the demo asks use, so a Cyrillic ask like
    /// "найди сервис чтобы быстро построить базу данных" reduces to the
    /// load-bearing nouns.
    private static let stopwords: Set<String> = [
        "a", "an", "the", "to", "for", "me", "my", "i", "we", "find", "show",
        "get", "need", "want", "which", "what", "that", "can", "with", "and",
        "or", "of", "is", "are", "how", "do", "use", "using", "best", "good",
        "service", "services", "tool", "tools", "app", "apps", "some", "any",
        "quickly", "fast",
        // Russian fillers (parity with the demo asks).
        "найди", "найти", "сервис", "сервисы", "чтобы", "быстро", "мне", "что",
        "как", "для",
    ]

    /// Word → category hint, so intent words steer ranking
    /// (web parity: `CATEGORY_HINTS`). `.infrastructure` covers the
    /// database/backend/deploy asks.
    private static let categoryHints: [String: ToolCategoryId] = [
        "code": .coding, "coding": .coding, "dev": .coding, "developer": .coding,
        "agent": .coding, "app": .coding, "build": .coding, "programming": .coding,
        "ide": .coding,
        "design": .design, "ui": .design, "ux": .design, "figma": .design,
        "logo": .design, "brand": .design,
        "research": .research, "search": .research, "data": .research,
        "knowledge": .research, "answer": .research,
        "image": .media, "video": .media, "audio": .media, "music": .media,
        "media": .media, "art": .media,
        "social": .distribution, "marketing": .distribution,
        "content": .distribution, "post": .distribution,
        "database": .infrastructure, "db": .infrastructure, "backend": .infrastructure,
        "deploy": .infrastructure, "host": .infrastructure, "infra": .infrastructure,
        "server": .infrastructure, "api": .infrastructure,
        // Cyrillic intent words used by the demo asks.
        "базу": .infrastructure, "данных": .infrastructure, "базаданных": .infrastructure,
    ]

    /// Rank tools for a natural-language ask and build a short answer.
    /// `knowledge` returns extra searchable text for a tool id (P1 enriched
    /// layer); P3 passes a no-op, matching the web `searchableText` fallback
    /// to seed fields only.
    static func run(
        _ text: String,
        in tools: [Tool],
        knowledge: (String) -> String = { _ in "" }
    ) -> Result {
        let qTokens = tokens(text)
        guard !qTokens.isEmpty else { return Result(matches: [], answer: "") }

        let wantedCategories = Set(qTokens.compactMap { categoryHints[$0] })

        let scored: [(tool: Tool, score: Int)] = tools.map { tool in
            let hay = searchable(tool, knowledge: knowledge)
            let name = fold(tool.name)
            var score = 0
            for t in qTokens {
                if name.contains(t) { score += 5 }
                else if hay.contains(t) { score += 2 }
            }
            if wantedCategories.contains(tool.category) { score += 3 }
            return (tool, score)
        }
        .filter { $0.score > 0 }
        .sorted { $0.score > $1.score }

        let matches = scored.prefix(maxResults).map(\.tool)
        guard let top = matches.first else {
            return Result(
                matches: [],
                answer: "No tool in the map matches that yet. Try the + button to add one — the classifier will place it."
            )
        }

        let why = top.summary.isEmpty ? "" : " — \(top.summary)"
        let others = matches.dropFirst().prefix(2).map(\.name)
        let tail = others.isEmpty ? "" : " Also worth a look: \(others.joined(separator: ", "))."
        return Result(matches: matches, answer: "\(top.name)\(why).\(tail)")
    }

    // MARK: - Internals

    private static func tokens(_ text: String) -> [String] {
        fold(text)
            .map { ($0.isLetter || $0.isNumber) ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 1 && !stopwords.contains($0) }
    }

    private static func searchable(_ tool: Tool, knowledge: (String) -> String) -> String {
        var parts = [tool.name, String(describing: tool.category),
                     tool.stage.rawValue, tool.summary]
        let extra = knowledge(tool.id)
        if !extra.isEmpty { parts.append(extra) }
        return fold(parts.joined(separator: " "))
    }

    private static func fold(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
