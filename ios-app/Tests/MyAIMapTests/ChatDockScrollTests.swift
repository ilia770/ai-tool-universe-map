import Testing
@testable import MyAIMap

/// Task 9a — the scroll-to-bottom anchor key must change on BOTH a new turn
/// AND last-turn content growth (answer/cards arriving after the row mounts).
/// Root cause was `onChange(of: turns.map(\.id))` firing only on count change,
/// so the answer/cards growing the last row never re-triggered the scroll.
@Suite("ChatDock.scrollAnchorKey")
struct ChatDockScrollTests {

    @Test func scrollKeyChangesOnContentGrowth() {
        let a: [ChatTurn] = [ChatTurn(id: 1, q: "hi", answer: "", matchIds: [])]
        let b: [ChatTurn] = [ChatTurn(id: 1, q: "hi", answer: "full answer", matchIds: ["x"])]
        #expect(ChatDock.scrollAnchorKey(turns: a) != ChatDock.scrollAnchorKey(turns: b))
    }

    @Test func scrollKeyChangesOnNewTurn() {
        let a: [ChatTurn] = [ChatTurn(id: 1, q: "hi", answer: "x", matchIds: [])]
        let b = a + [ChatTurn(id: 2, q: "again", answer: "y", matchIds: [])]
        #expect(ChatDock.scrollAnchorKey(turns: a) != ChatDock.scrollAnchorKey(turns: b))
    }

    @Test func scrollKeyStableForSameTurns() {
        let a: [ChatTurn] = [ChatTurn(id: 1, q: "hi", answer: "x", matchIds: ["y"])]
        #expect(ChatDock.scrollAnchorKey(turns: a) == ChatDock.scrollAnchorKey(turns: a))
    }
}
