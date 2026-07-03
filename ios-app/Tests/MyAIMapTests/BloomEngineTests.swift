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

    // Diamond + tail: a↔b, a↔c, b↔c, b↔d, d↔e.
    // Seed a reveals {a,b,c}; expanding b must introduce only d (c already revealed).
    private func diamond() -> BloomEngine {
        let adj = [
            "a": ["b", "c"],
            "b": ["a", "c", "d"],
            "c": ["a", "b"],
            "d": ["b", "e"],
            "e": ["d"],
        ]
        return BloomEngine(adjacency: adj, seedID: "a")
    }

    @Test func initialFocusIsSeed() {
        let e = diamond()
        #expect(e.focusID == "a")
        #expect(e.revealed == ["a", "b", "c"]) // seed + direct neighbours only
    }

    @Test func expandIntroducesOnlyHiddenNeighbours() {
        let e = diamond()
        let before = e.revealed
        e.expand("b") // b's neighbours a, c already revealed — only d is hidden
        #expect(e.stack.last?.parent == "b")
        #expect(e.stack.last?.introduced == ["d"])
        #expect(e.revealed == before.union(["d"]))
    }

    @Test func expandWithNoHiddenNeighboursIsNoOp() {
        let e = diamond()
        let before = e.revealed
        e.expand("c") // c's neighbours a, b already revealed
        #expect(e.breadcrumb == ["a"])
        #expect(e.revealed == before)
        #expect(e.focusID == "a") // focus untouched by the no-op
    }

    @Test func expandUnrevealedNodeIsNoOp() {
        let e = diamond()
        let before = e.revealed
        e.expand("e") // e is still hidden — cannot expand it
        #expect(e.breadcrumb == ["a"])
        #expect(e.revealed == before)
    }

    @Test func collapseAtRootIsNoOp() {
        let e = diamond()
        e.collapse("a")   // seed step is never removable
        e.collapseLast()  // nothing above the seed step
        #expect(e.breadcrumb == ["a"])
        #expect(e.revealed == ["a", "b", "c"])
        #expect(e.focusID == "a")
    }

    @Test func collapseRestoresPriorRevealedExactly() {
        let e = diamond()
        let initial = e.revealed
        e.expand("b")
        let afterB = e.revealed
        e.expand("d")
        #expect(e.revealed == afterB.union(["e"]))
        e.collapse("d")
        #expect(e.revealed == afterB)
        #expect(e.focusID == "b")
        e.collapse("b")
        #expect(e.revealed == initial)
        #expect(e.focusID == "a")
    }

    @Test func collapsingMidStackDropsDescendantSteps() {
        let e = diamond()
        e.expand("b")
        e.expand("d") // stack: [a, b, d]
        e.collapse("b") // removes b AND its descendant d in one truncate
        #expect(e.breadcrumb == ["a"])
        #expect(e.revealed == ["a", "b", "c"])
    }

    @Test func collapseToBeyondStackDepthIsNoOp() {
        let e = diamond()
        e.expand("b") // stack: [a, b]
        e.collapseTo(stepCount: 5)
        #expect(e.breadcrumb == ["a", "b"])
        #expect(e.revealed.contains("d"))
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
