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
    private let categoriesKey = "universe.customCategories.v1"
    private let hiddenKey = "universe.hiddenToolIDs.v1"
    private let renderModeKey = "universe.renderMode.v1"
    private let hapticsEnabledKey = "universe.hapticsEnabled.v1"
    private let hasSeenOnboardingKey = "universe.hasSeenOnboarding.v1"
    private let subscriptionKey = "universe.subscription.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static let standard = UniverseStore()

    func load() -> (tools: [Tool], customCategories: [ToolCategory], hidden: Set<String>, renderMode: UniverseRenderMode, hapticsEnabled: Bool, hasSeenOnboarding: Bool, subscription: SubscriptionState) {
        let tools = decode([Tool].self, key: toolsKey) ?? []
        let customCategories = decode([ToolCategory].self, key: categoriesKey) ?? []
        let hidden = decode([String].self, key: hiddenKey) ?? []
        let renderMode = defaults.string(forKey: renderModeKey)
            .flatMap(UniverseRenderMode.init(rawValue:))
            ?? .graph2D
        let hapticsEnabled = defaults.object(forKey: hapticsEnabledKey) as? Bool ?? true
        // Absent key → true first run. Default false so the onboarding overlay shows.
        let hasSeenOnboarding = defaults.bool(forKey: hasSeenOnboardingKey)
        let subscription = decode(SubscriptionState.self, key: subscriptionKey) ?? .free
        return (tools, customCategories, Set(hidden), renderMode, hapticsEnabled, hasSeenOnboarding, subscription)
    }

    func save(tools: [Tool], customCategories: [ToolCategory], hidden: Set<String>, renderMode: UniverseRenderMode, hapticsEnabled: Bool, hasSeenOnboarding: Bool, subscription: SubscriptionState) {
        encode(tools, key: toolsKey)
        encode(customCategories, key: categoriesKey)
        encode(Array(hidden).sorted(), key: hiddenKey)
        defaults.set(renderMode.rawValue, forKey: renderModeKey)
        defaults.set(hapticsEnabled, forKey: hapticsEnabledKey)
        defaults.set(hasSeenOnboarding, forKey: hasSeenOnboardingKey)
        encode(subscription, key: subscriptionKey)
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
