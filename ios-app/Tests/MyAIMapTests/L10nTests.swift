import Testing
@testable import MyAIMap

@Suite("Localization layer")
struct L10nTests {

    @Test func bothLanguagesCoverEveryKey() {
        for language in AppLanguage.allCases {
            #expect(!L10n.settingsTitle(language).isEmpty)
            #expect(!L10n.visualizationStyle(language).isEmpty)
            #expect(!L10n.language(language).isEmpty)
            #expect(!L10n.history(language).isEmpty)
            #expect(!L10n.dataManagement(language).isEmpty)
            #expect(!L10n.exportData(language).isEmpty)
            #expect(!L10n.resetData(language).isEmpty)
            #expect(!L10n.about(language).isEmpty)
            #expect(!L10n.accountAccessibilityLabel(language).isEmpty)
            #expect(!L10n.done(language).isEmpty)
        }
    }

    @Test func ruAndEnDiffer() {
        // A representative sampling: the two languages must not be the
        // same string (catches a copy-paste that left RU == EN).
        #expect(L10n.settingsTitle(.ru) != L10n.settingsTitle(.en))
        #expect(L10n.history(.ru) != L10n.history(.en))
    }

    @Test func systemDefaultPrefersRussianForRuLocale() {
        #expect(AppLanguage.from(localeIdentifiers: ["ru-RU", "en"]) == .ru)
        #expect(AppLanguage.from(localeIdentifiers: ["en-US"]) == .en)
        #expect(AppLanguage.from(localeIdentifiers: []) == .en)
    }
}
