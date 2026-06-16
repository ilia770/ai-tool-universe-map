import Foundation
import Testing
@testable import MyAIMap

@Suite("ToolHistory — pure event log")
struct ToolHistoryTests {

    @Test func recordingAddedAppendsAnEvent() {
        var history = ToolHistory()
        history.record(toolID: "figma", kind: .added)
        #expect(history.events.count == 1)
        #expect(history.events[0].toolID == "figma")
        #expect(history.events[0].kind == .added)
    }

    @Test func recentsAreMostRecentFirstAndCapped() {
        // Web parity: tools.filter(userAdded).slice(-6).reverse().
        var history = ToolHistory()
        for i in 0..<8 { history.record(toolID: "tool-\(i)", kind: .added) }
        let recents = history.recents(limit: 6)
        #expect(recents.count == 6)
        #expect(recents.first?.toolID == "tool-7")
        #expect(recents.last?.toolID == "tool-2")
    }

    @Test func recentsCollapseRepeatedToolToItsLatestEvent() {
        // A tool added then deleted shows once, with the latest (deleted) kind.
        var history = ToolHistory()
        history.record(toolID: "figma", kind: .added)
        history.record(toolID: "midjourney", kind: .added)
        history.record(toolID: "figma", kind: .deleted)
        let recents = history.recents(limit: 6)
        #expect(recents.map(\.toolID) == ["figma", "midjourney"])
        #expect(recents.first?.kind == .deleted)
    }

    @Test func roundTripsThroughCodable() throws {
        var history = ToolHistory()
        history.record(toolID: "figma", kind: .added)
        let data = try JSONEncoder().encode(history)
        let decoded = try JSONDecoder().decode(ToolHistory.self, from: data)
        #expect(decoded.events == history.events)
    }
}
