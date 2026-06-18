import Foundation

/// Pure search ranking for the SearchDock. Foundation-only (no SwiftUI /
/// RealityKit) so it stays independently testable from `MyAIMapTests`,
/// matching the `UniverseLayout` pure-core pattern.
///
/// Web parity: `AIToolUniverseMap.tsx` caps search results at 6
/// (`searchResultTools = queryResultTools.slice(0, 6)`). The web filter is
/// flat; this core adds rank buckets so the dock surfaces the best matches
/// first within the same cap.
enum SearchCore {
    /// Web parity: `queryResultTools.slice(0, 6)`.
    static let maxResults = 6

    /// Ranked, capped search results.
    ///
    /// Matching is case- and diacritic-insensitive (Unicode folding via
    /// `String.folding`). Rank buckets, best first:
    /// 0. tool name has the query as a prefix
    /// 1. tool name contains the query
    /// 2. summary contains the query
    /// 3. category display name contains the query
    ///
    /// Each tool appears once, at its best rank. Order within a bucket is
    /// the input order. Buckets are concatenated and capped at
    /// ``maxResults``.
    static func results(
        for query: String,
        in tools: [Tool],
        categoryName: (ToolCategoryId) -> String,
        extraText: ((Tool) -> String)? = nil
    ) -> [Tool] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let needle = fold(trimmed)

        var buckets: [[Tool]] = [[], [], [], [], []]
        for tool in tools {
            let name = fold(tool.name)
            if name.hasPrefix(needle) {
                buckets[0].append(tool)
            } else if name.contains(needle) {
                buckets[1].append(tool)
            } else if fold(tool.summary).contains(needle) {
                buckets[2].append(tool)
            } else if let extraText, fold(extraText(tool)).contains(needle) {
                buckets[3].append(tool)
            } else if fold(categoryName(tool.category)).contains(needle) {
                buckets[4].append(tool)
            }
        }
        return Array(buckets.joined().prefix(maxResults))
    }

    private static func fold(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
