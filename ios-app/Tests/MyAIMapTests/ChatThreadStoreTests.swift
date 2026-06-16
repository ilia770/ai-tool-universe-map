import Foundation
import Testing
@testable import MyAIMap

@Suite("ChatThreadStore — persisted conversation thread")
@MainActor
struct ChatThreadStoreTests {

    /// Isolated defaults per test so persistence assertions don't leak.
    private func makeDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "chat.test.\(UUID().uuidString)")!
        return d
    }

    private let liveIds: Set<String> = ["neon", "figma"]

    @Test func startsEmpty() {
        let store = ChatThreadStore(defaults: makeDefaults(), liveToolIds: liveIds)
        #expect(store.turns.isEmpty)
    }

    @Test func appendAssignsIncreasingIds() {
        let store = ChatThreadStore(defaults: makeDefaults(), liveToolIds: liveIds)
        store.append(query: "a", answer: "x", matchIds: ["neon"])
        store.append(query: "b", answer: "y", matchIds: ["figma"])
        #expect(store.turns.map(\.id) == [1, 2])
    }

    @Test func appendDropsStaleMatchIds() {
        let store = ChatThreadStore(defaults: makeDefaults(), liveToolIds: liveIds)
        store.append(query: "q", answer: "a", matchIds: ["neon", "ghost"])
        #expect(store.turns.first?.matchIds == ["neon"])
    }

    @Test func persistsAndReloads() {
        let defaults = makeDefaults()
        let a = ChatThreadStore(defaults: defaults, liveToolIds: liveIds)
        a.append(query: "build a database", answer: "Neon.", matchIds: ["neon"])
        let b = ChatThreadStore(defaults: defaults, liveToolIds: liveIds)
        #expect(b.turns.count == 1)
        #expect(b.turns.first?.q == "build a database")
        #expect(b.turns.first?.matchIds == ["neon"])
    }

    @Test func clearIsNonDestructiveUntilCommitted() {
        // Web parity: dismiss collapses; clear() empties + persists empty.
        let defaults = makeDefaults()
        let store = ChatThreadStore(defaults: defaults, liveToolIds: liveIds)
        store.append(query: "q", answer: "a", matchIds: [])
        store.clear()
        #expect(store.turns.isEmpty)
        let reloaded = ChatThreadStore(defaults: defaults, liveToolIds: liveIds)
        #expect(reloaded.turns.isEmpty)
    }

    @Test func capsStoredTurns() {
        let store = ChatThreadStore(defaults: makeDefaults(), liveToolIds: liveIds)
        for i in 0..<(ChatThreadStore.maxStoredTurns + 5) {
            store.append(query: "q\(i)", answer: "a", matchIds: [])
        }
        #expect(store.turns.count == ChatThreadStore.maxStoredTurns)
    }
}
