import Testing
@testable import MyAIMap

@Suite("QueryEngine — NL query ranking")
struct QueryEngineTests {

    private func makeTool(
        id: String,
        name: String,
        summary: String = "—",
        category: ToolCategoryId = .coding
    ) -> Tool {
        Tool(
            id: id, name: name, category: category, summary: summary,
            stage: .execution, orbit: .inner, angle: 0, url: nil,
            logoDomain: nil, relationIds: [], classification: nil
        )
    }

    private func run(_ q: String, _ tools: [Tool]) -> QueryEngine.Result {
        QueryEngine.run(q, in: tools)
    }

    @Test func emptyQueryReturnsNothing() {
        let tools = [makeTool(id: "a", name: "Figma")]
        #expect(run("", tools).matches.isEmpty)
        // Stopwords-only collapses to zero tokens.
        #expect(run("the to a for me", tools).matches.isEmpty)
    }

    @Test func nameMatchRanksToTop() {
        let tools = [
            makeTool(id: "linear", name: "Linear", summary: "planning"),
            makeTool(id: "figma", name: "Figma", summary: "design canvas"),
        ]
        #expect(run("figma", tools).matches.first?.id == "figma")
    }

    @Test func categoryHintBiasesResults() {
        // "database" hints the .infrastructure category (web CATEGORY_HINTS).
        let tools = [
            makeTool(id: "neon", name: "Neon", summary: "serverless postgres", category: .infrastructure),
            makeTool(id: "canva", name: "Canva", summary: "graphics", category: .design),
        ]
        let res = run("найди сервис чтобы быстро построить базу данных database", tools)
        #expect(res.matches.first?.id == "neon")
    }

    @Test func capsAtFiveMatches() {
        let tools = (0..<9).map { makeTool(id: "code-\($0)", name: "CodeAgent \($0)", category: .coding) }
        #expect(run("code agent dev build", tools).matches.count <= 5)
    }

    @Test func answerIsNonEmptyWhenMatched() {
        let tools = [makeTool(id: "neon", name: "Neon", summary: "serverless postgres database")]
        let res = run("database", tools)
        #expect(!res.matches.isEmpty)
        #expect(!res.answer.isEmpty)
        #expect(res.answer.contains("Neon"))
    }

    @Test func noMatchAnswerSuggestsAdding() {
        let tools = [makeTool(id: "neon", name: "Neon")]
        let res = run("zzzqqq xyzzy", tools)
        #expect(res.matches.isEmpty)
        #expect(res.answer.contains("+"))
    }
}
