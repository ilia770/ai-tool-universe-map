import Foundation

/// The only `UserDefaults` touch-point for tool history. Keeps `ToolHistory`
/// pure: this helper owns encode/decode + the storage key, and degrades to an
/// empty log on missing or corrupt data (never throws into the view-model).
struct HistoryStore {
    static let key = "com.myaimap.toolHistory.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ToolHistory {
        guard let data = defaults.data(forKey: Self.key),
              let history = try? JSONDecoder().decode(ToolHistory.self, from: data)
        else { return ToolHistory() }
        return history
    }

    func save(_ history: ToolHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
