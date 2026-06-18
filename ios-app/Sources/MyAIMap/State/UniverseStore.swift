import Foundation

/// Local persistence for the user-built universe.
///
/// The product model is "start empty, build your own universe": the user's
/// added tools and the ids they've hidden are the only persisted state. The
/// seed (`UniverseSeed`) is NOT persisted — it is sample data the user can
/// load on demand, never the default.
@MainActor
struct UniverseStore {
    private let defaults: UserDefaults
    private let toolsKey = "universe.customTools.v1"
    private let hiddenKey = "universe.hiddenToolIDs.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static let standard = UniverseStore()

    func load() -> (tools: [Tool], hidden: Set<String>) {
        let tools = decode([Tool].self, key: toolsKey) ?? []
        let hidden = decode([String].self, key: hiddenKey) ?? []
        return (tools, Set(hidden))
    }

    func save(tools: [Tool], hidden: Set<String>) {
        encode(tools, key: toolsKey)
        encode(Array(hidden).sorted(), key: hiddenKey)
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
