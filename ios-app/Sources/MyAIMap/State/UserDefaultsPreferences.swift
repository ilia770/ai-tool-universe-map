import Foundation

/// Small non-catalog settings kept in UserDefaults. They deliberately retain
/// their v1 keys, so moving the catalog to Application Support does not reset
/// haptics, onboarding, or the local placeholder subscription state.
@MainActor
struct UserDefaultsPreferences {
    struct Snapshot: Equatable, Sendable {
        var hapticsEnabled: Bool
        var hasSeenOnboarding: Bool
        var subscription: SubscriptionState
    }

    enum Key {
        static let hapticsEnabled = "universe.hapticsEnabled.v1"
        static let hasSeenOnboarding = "universe.hasSeenOnboarding.v1"
        static let subscription = "universe.subscription.v1"
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        defaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
    }

    func load() -> Snapshot {
        Snapshot(
            hapticsEnabled: defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? true,
            hasSeenOnboarding: defaults.bool(forKey: Key.hasSeenOnboarding),
            subscription: decodeSubscription() ?? .free
        )
    }

    func save(_ snapshot: Snapshot) {
        defaults.set(snapshot.hapticsEnabled, forKey: Key.hapticsEnabled)
        defaults.set(snapshot.hasSeenOnboarding, forKey: Key.hasSeenOnboarding)
        guard let data = try? encoder.encode(snapshot.subscription) else { return }
        defaults.set(data, forKey: Key.subscription)
    }

    private func decodeSubscription() -> SubscriptionState? {
        guard let data = defaults.data(forKey: Key.subscription) else { return nil }
        return try? decoder.decode(SubscriptionState.self, from: data)
    }
}
