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

    // Tapping a revealed node with no hidden neighbours (and not an expanded
    // parent) falls to the focus-only branch of `tap`: move focus, touch nothing else.
    @Test func tapRevealedLeafOnlyMovesFocus() {
        let e = diamond()
        let before = e.revealed // {a, b, c}; c's neighbours a,b already revealed
        e.tap("c")
        #expect(e.focusID == "c")
        #expect(e.breadcrumb == ["a"]) // no new stack step pushed
        #expect(e.revealed == before) // nothing revealed or hidden
    }

    // collapseTo clamps a below-1 step count up to the root step — the stack
    // keeps exactly the seed step and never empties.
    @Test func collapseToBelowOneClampsToRootStep() {
        let e = diamond()
        e.expand("b") // stack: [a, b]
        e.collapseTo(stepCount: 0)
        #expect(e.breadcrumb == ["a"])
        #expect(!e.revealed.contains("d"))
        #expect(e.focusID == "a")
        #expect(e.stack.count == 1) // seed step survives, stack not empty
    }

    // reset() after deep expansion returns stack, focus, and revealed to the
    // exact initial (post-init) state.
    @Test func resetRestoresInitialState() {
        let e = diamond()
        e.expand("b")
        e.expand("d") // deep: stack [a, b, d], e revealed
        e.reset()
        #expect(e.breadcrumb == ["a"])
        #expect(e.revealed == ["a", "b", "c"])
        #expect(e.focusID == "a")
    }

    // visibleEdges drops any edge whose endpoint is mid-collapse. After collapse("b")
    // node c is flagged collapsing (still present as a node) so edge b–c is filtered
    // out while a–b, both live, stays visible.
    // MARK: - Settle detection (WS6.2)

    // Diamond edges matching diamond()'s adjacency (undirected).
    private func diamondEdges() -> [(a: String, b: String)] {
        [(a: "a", b: "b"), (a: "a", b: "c"), (a: "b", b: "c"), (a: "b", b: "d"), (a: "d", b: "e")]
    }

    // Tick until the sim reports rest (hard cap guards against a non-converging bug).
    private func settle(_ e: BloomEngine, _ edges: [(a: String, b: String)]) {
        var n = 0
        while !e.isSettled && n < 20000 {
            e.tick(dt: 1.0 / 60, reduced: false, allEdges: edges)
            n += 1
        }
    }

    // With no input the sim reaches rest and then stops moving nodes entirely —
    // a settled tick is a no-op, so successive positions are bit-identical.
    @Test func settlesAtRestAndFreezesPositions() {
        let e = diamond()
        let edges = diamondEdges()
        settle(e, edges)
        #expect(e.isSettled)
        let before = e.nodes.mapValues { ($0.x, $0.y) }
        e.tick(dt: 1.0 / 60, reduced: false, allEdges: edges)
        for (id, p) in before {
            #expect(abs(e.nodes[id]!.x - p.0) < 1e-9)
            #expect(abs(e.nodes[id]!.y - p.1) < 1e-9)
        }
    }

    // Resume-on-mutation: expand must wake the sim and the next tick advances
    // state (the newly introduced node ramps its appear in).
    @Test func expandClearsSettledAndResumes() {
        let e = diamond()
        let edges = diamondEdges()
        settle(e, edges)
        #expect(e.isSettled)
        e.expand("b") // introduces d
        #expect(!e.isSettled)
        #expect(e.nodes["d"] != nil)
        let appear0 = e.nodes["d"]!.appear
        e.tick(dt: 1.0 / 60, reduced: false, allEdges: edges)
        #expect(e.nodes["d"]!.appear > appear0) // new node springing in → sim advanced
    }

    // Resume-on-mutation: collapse must wake the sim and the next tick advances
    // the fade-out of the collapsed node.
    @Test func collapseClearsSettledAndResumes() {
        let e = diamond()
        let edges = diamondEdges()
        e.expand("b") // reveal d
        settle(e, edges)
        #expect(e.isSettled)
        e.collapse("b") // d begins collapsing
        #expect(!e.isSettled)
        let appear0 = e.nodes["d"]!.appear
        e.tick(dt: 1.0 / 60, reduced: false, allEdges: edges)
        #expect(e.nodes["d"] == nil || e.nodes["d"]!.appear < appear0) // fading out
    }

    // Resume-on-mutation: a focus-only tap must wake the sim so the camera can
    // ease toward the new focus on the next tick.
    @Test func tapFocusChangeClearsSettledAndResumes() {
        let e = diamond()
        let edges = diamondEdges()
        settle(e, edges)
        #expect(e.isSettled)
        #expect(e.focusID == "a")
        let cx0 = e.camX, cy0 = e.camY
        e.tap("c") // leaf, no hidden, not expanded → focus-only branch
        #expect(e.focusID == "c")
        #expect(!e.isSettled)
        e.tick(dt: 1.0 / 60, reduced: false, allEdges: edges)
        #expect(abs(e.camX - cx0) > 1e-6 || abs(e.camY - cy0) > 1e-6) // camera moved toward new focus
    }

    // Resume-on-mutation: reset must wake the sim; nodes dropped by the reset are
    // still collapsing on the next tick, so the sim stays unsettled while resolving.
    @Test func resetClearsSettledAndResumes() {
        let e = diamond()
        let edges = diamondEdges()
        e.expand("b"); e.expand("d") // deep
        settle(e, edges)
        #expect(e.isSettled)
        e.reset()
        #expect(!e.isSettled)
        #expect(e.revealed == ["a", "b", "c"])
        e.tick(dt: 1.0 / 60, reduced: false, allEdges: edges)
        #expect(!e.isSettled) // d/e still fading out
    }

    // Regression: a hub with many neighbours seeds every neighbour coincident at
    // the same point, so unbounded repulsion (18000/d2, d2→0) once flung the graph
    // to ±100k on the very first ticks — the off-screen "degenerate column" bug.
    // The distance floor must keep positions in plausible space from tick 1.
    @Test func simStaysBoundedFromCoincidentSeed() {
        var adj: [String: [String]] = ["hub": (0..<11).map { "n\($0)" }]
        for i in 0..<11 { adj["n\(i)"] = ["hub"] }
        let e = BloomEngine(adjacency: adj, seedID: "hub")
        let edges = BloomAdjacency.edges(from: adj)
        for _ in 0..<6 { e.tick(dt: 1.0 / 60, reduced: false, allEdges: edges) }
        let maxAbs = e.nodes.values.map { max(abs($0.x), abs($0.y)) }.max() ?? 0
        #expect(maxAbs < 5000, "sim blew up to \(maxAbs)")
    }

    @Test func visibleEdgesExcludeCollapsingEndpoints() {
        let e = chain()
        let edges = [(a: "a", b: "b"), (a: "b", b: "c")]
        e.expand("b") // reveals c; both edges now live
        #expect(e.visibleEdges(edges).count == 2)
        e.collapse("b") // c is now mid-collapse but still a node
        let vis = e.visibleEdges(edges)
        #expect(vis.contains { $0.a == "a" && $0.b == "b" })
        #expect(!vis.contains { $0.a == "c" || $0.b == "c" })
    }
}
