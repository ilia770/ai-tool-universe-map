import Foundation
import Testing
@testable import MyAIMap

@Suite("RelationCache — persisted AI relations")
struct RelationCacheTests {

    private func freshCache() -> RelationCache {
        let suite = "relationcache.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return RelationCache(defaults: defaults)
    }

    @Test func missReturnsNil() {
        let cache = freshCache()
        #expect(cache.relatedIDs(for: "a") == nil)
    }

    @Test func storesAndReadsBack() {
        let cache = freshCache()
        cache.store(["b", "c"], for: "a")
        #expect(cache.relatedIDs(for: "a") == ["b", "c"])
    }

    @Test func overwritesExisting() {
        let cache = freshCache()
        cache.store(["b"], for: "a")
        cache.store(["c", "d"], for: "a")
        #expect(cache.relatedIDs(for: "a") == ["c", "d"])
    }

    @Test func emptyStoredIsNotAMiss() {
        let cache = freshCache()
        cache.store([], for: "a")
        #expect(cache.relatedIDs(for: "a") == []) // distinguishes "resolved to nothing" from "never fetched"
    }
}
