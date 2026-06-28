import Foundation

/// Persists AI-resolved relations so the network is hit at most once per tool.
/// Backed by `UserDefaults` as a `[toolID: [relatedID]]` JSON map. Injectable
/// store for tests. `@unchecked Sendable`: it is immutable and `UserDefaults`
/// is itself thread-safe, so the `shared` singleton is safe to share.
struct RelationCache: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "constellation.aiRelations.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static let shared = RelationCache()

    private func load() -> [String: [String]] {
        guard let data = defaults.data(forKey: key),
              let map = try? JSONDecoder().decode([String: [String]].self, from: data) else { return [:] }
        return map
    }

    func relatedIDs(for toolID: String) -> [String]? {
        load()[toolID]
    }

    func store(_ ids: [String], for toolID: String) {
        var map = load()
        map[toolID] = ids
        if let data = try? JSONEncoder().encode(map) {
            defaults.set(data, forKey: key)
        }
    }
}
