import Foundation
import Observation

/// Cross-cutting, persisted app chrome settings. Separate from
/// `UniverseViewModel` (which owns transient universe selection) because
/// these survive launches and are unrelated to the 3D scene. Injected
/// via `.environment(...)` alongside the model, mirroring the
/// "one observable per concern" decision.
@MainActor
@Observable
final class AppSettings {

    /// First-launch default: follow the device's preferred languages,
    /// Russian if any is Russian, else English.
    static var defaultLanguage: AppLanguage {
        AppLanguage.from(localeIdentifiers: Locale.preferredLanguages)
    }

    private enum Key {
        static let language = "settings.language"
        static let visualization = "settings.visualization"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }

    var visualizationStyle: VisualizationStyle {
        didSet { defaults.set(visualizationStyle.rawValue, forKey: Key.visualization) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.language = defaults.string(forKey: Key.language)
            .flatMap(AppLanguage.init(rawValue:)) ?? AppSettings.defaultLanguage
        self.visualizationStyle = defaults.string(forKey: Key.visualization)
            .flatMap(VisualizationStyle.init(rawValue:)) ?? .galaxy
    }

    /// Restore shipping defaults. Used by the Settings "Reset all data"
    /// row. (No tool/history data persists yet, so this only clears
    /// chrome prefs today; the row's scope grows with later parts.)
    func reset() {
        language = AppSettings.defaultLanguage
        visualizationStyle = .galaxy
    }

    /// A portable snapshot of user prefs as pretty JSON, for the
    /// "Export data" share action.
    func exportJSON() throws -> Data {
        let snapshot: [String: String] = [
            "language": language.rawValue,
            "visualization": visualizationStyle.rawValue,
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }
}
