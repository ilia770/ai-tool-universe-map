import Testing
import Foundation
@testable import MyAIMap

@Suite("App settings store")
@MainActor
struct AppSettingsTests {

    private func freshDefaults() -> UserDefaults {
        let suite = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func persistsLanguageAcrossInstances() {
        let defaults = freshDefaults()
        let a = AppSettings(defaults: defaults)
        a.language = .ru
        // A new instance over the same store reads the saved value.
        let b = AppSettings(defaults: defaults)
        #expect(b.language == .ru)
    }

    @Test func persistsVisualizationStyle() {
        let defaults = freshDefaults()
        let a = AppSettings(defaults: defaults)
        a.visualizationStyle = .force3D
        let b = AppSettings(defaults: defaults)
        #expect(b.visualizationStyle == .force3D)
    }

    @Test func resetRestoresDefaults() {
        let defaults = freshDefaults()
        let s = AppSettings(defaults: defaults)
        s.language = .ru
        s.visualizationStyle = .force3D
        s.reset()
        #expect(s.language == AppSettings.defaultLanguage)
        #expect(s.visualizationStyle == .galaxy)
    }

    @Test func exportProducesNonEmptyJSON() throws {
        let defaults = freshDefaults()
        let s = AppSettings(defaults: defaults)
        s.language = .ru
        let data = try s.exportJSON()
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"language\""))
        #expect(json.contains("ru"))
    }
}
