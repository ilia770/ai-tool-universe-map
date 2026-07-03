import Testing
@testable import MyAIMap

@Suite("BloomEngine — progressive reveal mechanic")
struct BloomEngineTests {

    // a-b-c chain: a↔b, b↔c
    private func chain() -> BloomEngine {
        let adj = ["a": ["b"], "b": ["a", "c"], "c": ["b"]]
        return BloomEngine(adjacency: adj, seedID: "a")
    }

    @Test func seedRevealsItselfPlusNeighbours() {
        let e = chain()
        #expect(e.revealed == ["a", "b"]) // a + its neighbour b; c still hidden
        #expect(e.breadcrumb == ["a"])
    }

    @Test func expandRevealsHiddenNeighbours() {
        let e = chain()
        e.expand("b") // b's hidden neighbour is c
        #expect(e.revealed.contains("c"))
        #expect(e.breadcrumb == ["a", "b"])
        #expect(e.focusID == "b")
    }

    @Test func collapseRollsBackTheStack() {
        let e = chain()
        e.expand("b")
        e.collapse("b")
        #expect(!e.revealed.contains("c"))
        #expect(e.breadcrumb == ["a"])
    }

    @Test func tapExpandsThenCollapses() {
        let e = chain()
        e.tap("b")                 // has hidden c → expands
        #expect(e.revealed.contains("c"))
        e.tap("b")                 // now fully expanded → collapses
        #expect(!e.revealed.contains("c"))
    }

    @Test func collapseToStepCountTruncates() {
        let e = chain()
        e.expand("b")              // stack: [a, b]
        e.collapseTo(stepCount: 1) // back to just [a]
        #expect(e.breadcrumb == ["a"])
        #expect(!e.revealed.contains("c"))
    }

    @Test func tickKeepsRevealedNodesAndDropsCollapsed() {
        let e = chain()
        e.expand("b")
        for _ in 0..<5 { e.tick(dt: 1.0 / 60, reduced: false, allEdges: [(a: "a", b: "b"), (a: "b", b: "c")]) }
        #expect(e.nodes["c"] != nil)
        e.collapse("b")
        for _ in 0..<120 { e.tick(dt: 1.0 / 60, reduced: false, allEdges: [(a: "a", b: "b"), (a: "b", b: "c")]) }
        #expect(e.nodes["c"] == nil) // faded out + dropped
    }
}
