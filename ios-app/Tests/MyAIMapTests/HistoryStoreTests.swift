import Foundation
import Testing
@testable import MyAIMap

@Suite("HistoryStore — UserDefaults persistence")
struct HistoryStoreTests {

    private func freshDefaults() -> UserDefaults {
        let suite = "HistoryStoreTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func loadReturnsEmptyHistoryWhenNothingStored() {
        let store = HistoryStore(defaults: freshDefaults())
        #expect(store.load().events.isEmpty)
    }

    @Test func savedHistoryLoadsBack() {
        let defaults = freshDefaults()
        let store = HistoryStore(defaults: defaults)
        var history = ToolHistory()
        history.record(toolID: "figma", kind: .added)
        store.save(history)
        #expect(HistoryStore(defaults: defaults).load() == history)
    }

    @Test func corruptDataLoadsAsEmptyHistory() {
        let defaults = freshDefaults()
        defaults.set(Data("not json".utf8), forKey: HistoryStore.key)
        #expect(HistoryStore(defaults: defaults).load().events.isEmpty)
    }
}
