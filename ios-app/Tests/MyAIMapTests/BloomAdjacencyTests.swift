import Testing
@testable import MyAIMap

@Suite("BloomAdjacency — sparse meaningful neighbours")
struct BloomAdjacencyTests {

    private func tool(_ id: String, _ cat: ToolCategoryId, _ stage: WorkflowStageId,
                      rel: [String] = []) -> Tool {
        Tool(id: id, name: id, category: cat, summary: "", stage: stage, orbit: .middle,
             angle: 0, url: nil, logoDomain: nil, relationIds: rel, classification: nil)
    }

    @Test func adjacencyIsSymmetric() {
        let a = tool("a", .coding, .execution)
        let b = tool("b", .coding, .execution) // alternative of a
        let adj = BloomAdjacency.build(tools: [a, b])
        #expect(adj["a"]?.contains("b") == true)
        #expect(adj["b"]?.contains("a") == true)
    }

    @Test func dropsWeakConstellationKind() {
        // Same category, non-adjacent stages → only a .constellation link, which
        // must NOT become a Bloom neighbour.
        let a = tool("a", .coding, .research)
        let b = tool("b", .coding, .review)
        let adj = BloomAdjacency.build(tools: [a, b])
        #expect(adj["a"]?.contains("b") != true)
    }

    @Test func keepsCuratedRelation() {
        let a = tool("a", .coding, .execution, rel: ["b"])
        let b = tool("b", .design, .planning) // different category, only linked by curated rel
        let adj = BloomAdjacency.build(tools: [a, b])
        #expect(adj["a"]?.contains("b") == true)
        #expect(adj["b"]?.contains("a") == true)
    }

    @Test func edgesAreUniqueUndirected() {
        let a = tool("a", .coding, .execution)
        let b = tool("b", .coding, .execution)
        let edges = BloomAdjacency.edges(tools: [a, b])
        #expect(edges.count == 1)
        #expect(edges.first?.a == "a")
        #expect(edges.first?.b == "b")
    }

    @Test func seedRevealsCoreNeighboursInRealSeed() {
        let adj = BloomAdjacency.build(tools: UniverseSeed.tools)
        // Founder OS should have at least one meaningful neighbour to bloom into.
        #expect((adj[PlanetData.centralCoreToolID]?.isEmpty == false))
    }
}
