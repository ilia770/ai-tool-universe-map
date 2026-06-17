import Foundation

/// Lightweight RU/EN string table. Pure functions keyed by
/// `AppLanguage` — no `.strings` catalog, because the app must flip
/// language live (the picker mutates `AppSettings.language`, which
/// re-publishes through `@Observable`) and stay unit-testable headless.
/// Add a new UI string by adding one static func with both cases.
enum L10n {
    static func settingsTitle(_ l: AppLanguage) -> String {
        switch l { case .en: "Settings"; case .ru: "Настройки" }
    }
    static func visualizationStyle(_ l: AppLanguage) -> String {
        switch l { case .en: "Visualization"; case .ru: "Визуализация" }
    }
    static func language(_ l: AppLanguage) -> String {
        switch l { case .en: "Language"; case .ru: "Язык" }
    }
    static func history(_ l: AppLanguage) -> String {
        switch l { case .en: "History"; case .ru: "История" }
    }
    static func dataManagement(_ l: AppLanguage) -> String {
        switch l { case .en: "Data"; case .ru: "Данные" }
    }
    static func exportData(_ l: AppLanguage) -> String {
        switch l { case .en: "Export data"; case .ru: "Экспорт данных" }
    }
    static func resetData(_ l: AppLanguage) -> String {
        switch l { case .en: "Reset all data"; case .ru: "Сбросить данные" }
    }
    static func about(_ l: AppLanguage) -> String {
        switch l { case .en: "About"; case .ru: "О приложении" }
    }
    static func version(_ l: AppLanguage) -> String {
        switch l { case .en: "Version"; case .ru: "Версия" }
    }
    static func done(_ l: AppLanguage) -> String {
        switch l { case .en: "Done"; case .ru: "Готово" }
    }
    static func accountAccessibilityLabel(_ l: AppLanguage) -> String {
        switch l { case .en: "Account and settings"; case .ru: "Аккаунт и настройки" }
    }
    static func apiKey(_ l: AppLanguage) -> String {
        switch l { case .en: "Anthropic API key"; case .ru: "Ключ API Anthropic" }
    }
    static func apiKeyHelp(_ l: AppLanguage) -> String {
        switch l {
        case .en: "Paste your Anthropic API key above. It is stored only in the device Keychain and never leaves your device."
        case .ru: "Вставьте ключ API Anthropic. Он хранится только в Keychain устройства и никуда не передаётся."
        }
    }
    static func save(_ l: AppLanguage) -> String {
        switch l { case .en: "Save"; case .ru: "Сохранить" }
    }
    static func delete(_ l: AppLanguage) -> String {
        switch l { case .en: "Delete key"; case .ru: "Удалить ключ" }
    }
    static func account(_ l: AppLanguage) -> String {
        switch l { case .en: "Account"; case .ru: "Аккаунт" }
    }
    static func manageTools(_ l: AppLanguage) -> String {
        switch l { case .en: "Manage tools"; case .ru: "Управление инструментами" }
    }
}
