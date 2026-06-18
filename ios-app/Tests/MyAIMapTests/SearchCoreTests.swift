import Testing
@testable import MyAIMap

@Suite("SearchCore — pure search ranking")
struct SearchCoreTests {

    // MARK: - Fixtures

    /// Inline fixtures via Tool's memberwise init; layout fields are
    /// irrelevant to search, so they get neutral values.
    private func makeTool(
        id: String,
        name: String,
        summary: String = "—",
        category: ToolCategoryId = .coding
    ) -> Tool {
        Tool(
            id: id,
            name: name,
            category: category,
            summary: summary,
            stage: .execution,
            orbit: .inner,
            angle: 0,
            url: nil,
            logoDomain: nil,
            relationIds: [],
            classification: nil
        )
    }

    /// Fixed category display names so tests don't depend on seed data.
    private func categoryName(_ id: ToolCategoryId) -> String {
        switch id {
        case .design: return "Design & Product UI"
        case .coding: return "Coding & Agentic Dev"
        default: return String(describing: id).capitalized
        }
    }

    private func results(_ query: String, _ tools: [Tool]) -> [Tool] {
        SearchCore.results(for: query, in: tools, categoryName: categoryName)
    }

    // MARK: - Empty / whitespace

    @Test func emptyQueryReturnsNothing() {
        let tools = [makeTool(id: "a", name: "Figma")]
        #expect(results("", tools).isEmpty)
    }

    @Test func whitespaceOnlyQueryReturnsNothing() {
        let tools = [makeTool(id: "a", name: "Figma")]
        #expect(results("   \n\t", tools).isEmpty)
    }

    // MARK: - Rank buckets

    @Test func namePrefixBeatsNameSubstring() {
        // Substring match listed first in input — prefix must still win.
        let tools = [
            makeTool(id: "uifigma", name: "Uifigma-ish"),
            makeTool(id: "figma", name: "Figma"),
        ]
        #expect(results("fig", tools).map(\.id) == ["figma", "uifigma"])
    }

    @Test func summaryMatchRanksAfterNameMatches() {
        let tools = [
            makeTool(id: "summary-hit", name: "Linear", summary: "Plan figures and fig trees"),
            makeTool(id: "substring-hit", name: "Uifigma-ish"),
            makeTool(id: "prefix-hit", name: "Figma"),
        ]
        #expect(results("fig", tools).map(\.id) == ["prefix-hit", "substring-hit", "summary-hit"])
    }

    @Test func categoryNameMatchRanksLast() {
        let tools = [
            makeTool(id: "category-hit", name: "Sketch", summary: "Vector editor", category: .design),
            makeTool(id: "summary-hit", name: "Linear", summary: "Design planning board", category: .coding),
            makeTool(id: "name-hit", name: "Design OS", category: .coding),
        ]
        #expect(results("design", tools).map(\.id) == ["name-hit", "summary-hit", "category-hit"])
    }

    @Test func extraKnowledgeMatchRanksBeforeCategoryName() {
        let tools = [
            makeTool(id: "category-hit", name: "Sketch", summary: "Vector editor", category: .design),
            makeTool(id: "knowledge-hit", name: "Backend Box", summary: "Runtime shell", category: .coding),
        ]
        let hits = SearchCore.results(
            for: "database",
            in: tools,
            categoryName: categoryName,
            extraText: { tool in tool.id == "knowledge-hit" ? "Postgres database auth storage" : "" }
        )
        #expect(hits.map(\.id) == ["knowledge-hit"])
    }

    // MARK: - Folding

    @Test func matchingIsCaseInsensitive() {
        let tools = [makeTool(id: "figma", name: "Figma")]
        #expect(results("FIG", tools).map(\.id) == ["figma"])
    }

    @Test func matchingIsDiacriticInsensitive() {
        let tools = [makeTool(id: "ember", name: "Émber Studio")]
        #expect(results("ember", tools).map(\.id) == ["ember"])
        // And the other direction: accented query, plain name.
        let plain = [makeTool(id: "plain", name: "Ember Studio")]
        #expect(results("émber", plain).map(\.id) == ["plain"])
    }

    // MARK: - Cap and dedupe

    @Test func resultsAreCappedAtMaxResults() {
        let tools = (0..<10).map { makeTool(id: "tool-\($0)", name: "Figment \($0)") }
        let hits = results("fig", tools)
        #expect(SearchCore.maxResults == 6)
        #expect(hits.count == SearchCore.maxResults)
        // Stable order within the bucket = input order.
        #expect(hits.map(\.id) == (0..<6).map { "tool-\($0)" })
    }

    @Test func toolMatchingMultipleBucketsAppearsOnce() {
        // Name prefix + summary + category name all contain the query.
        let tools = [
            makeTool(id: "design-os", name: "Design OS", summary: "All-in-one design hub", category: .design),
        ]
        let hits = results("design", tools)
        #expect(hits.map(\.id) == ["design-os"])
    }
}
