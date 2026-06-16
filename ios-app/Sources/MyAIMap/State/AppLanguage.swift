import Foundation

/// App display language. The product ships RU/EN only; the picker in
/// Settings flips this live and `AppSettings` persists it. Distinct from
/// the device locale — a Russian-locale user may prefer the English UI.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en
    case ru

    var id: String { rawValue }

    /// Native-name label for the picker ("English" / "Русский").
    var displayName: String {
        switch self {
        case .en: "English"
        case .ru: "Русский"
        }
    }

    /// Two-letter chip label for the compact toggle ("EN" / "RU").
    var shortLabel: String { rawValue.uppercased() }

    /// Best language for a preferred-locale list (e.g.
    /// `Locale.preferredLanguages`). Russian wins if any preferred
    /// identifier is Russian; everything else falls back to English.
    static func from(localeIdentifiers identifiers: [String]) -> AppLanguage {
        for id in identifiers where id.lowercased().hasPrefix("ru") {
            return .ru
        }
        return .en
    }
}
