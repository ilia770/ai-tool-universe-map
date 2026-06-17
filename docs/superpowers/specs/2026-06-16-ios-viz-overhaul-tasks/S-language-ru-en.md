# Language RU / EN toggle

**Phase:** S · **Lens:** shell

## Goal (1-2 lines)
Wire a real RU/EN toggle through `L10n` so every shell string flips live and persists. The control exists in `SettingsSheet.languageSection`; this task makes the rest of the new shell surfaces actually localized (today only Settings/account labels are) and audits for hard-coded English.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- modify `State/L10n.swift` — add the strings the new shell surfaces need: `manageTools`, `apiKey`, `account`, `historyAdded`, `historyRemoved`, `delete`, `restore`, `save`, `apiKeyHelp`, `noToolsAdded`, `recentlyAdded` (RU+EN).
- modify `UI/Search/HistoryStrip.swift` — replace hard-coded `"Recently added"` (L37) and English `accessibilityLabel`/context-menu `"Open"/"Restore"/"Remove"` strings (L16-18, L79-93) with `L10n` calls; thread `settings.language` in via `@Environment(AppSettings.self)`.
- (Existing, no change) `State/AppLanguage.swift`, `State/AppSettings.swift` — `language` already persists via `didSet`; picker already binds to it.

## Approach (bullet steps)
- `AppLanguage` (en/ru) + `AppSettings.language` + `didSet` persistence already exist — do NOT rebuild. This task is the string-coverage + live-flip audit.
- Grep the shell surfaces (`HistoryStrip`, new `S-history-clickable`/`S-manage-delete-tools`/`S-keychain-api-key` screens) for string literals and route each through an `L10n.<key>(language)` func.
- Confirm live flip: because views read `settings.language` (an `@Observable`), flipping the picker re-renders. Add a `@ScaledMetric`-safe check that RU strings (longer) don't clip — `.minimumScaleFactor`/`lineLimit` where tight.
- Default language = `AppSettings.defaultLanguage` (RU if device prefers RU) — unchanged.

## Interface / contract (Swift signature sketch — signatures only)
```swift
enum L10n {
    static func manageTools(_ l: AppLanguage) -> String
    static func apiKey(_ l: AppLanguage) -> String
    static func recentlyAdded(_ l: AppLanguage) -> String
    static func restore(_ l: AppLanguage) -> String
    // …one func per key, both cases
}
```

## Tests (what to assert; reference real Tests/MyAIMapTests conventions)
- Extend `L10nTests.bothLanguagesCoverEveryKey` loop with every new key (non-empty for `.en` and `.ru`).
- Extend `L10nTests.ruAndEnDiffer` with `recentlyAdded`/`manageTools` (RU ≠ EN).
- `AppSettingsTests.persistsLanguageAcrossInstances` already covers persistence — keep it green.

## Done criteria (checklist)
- [ ] No hard-coded English on any shell surface (History strip + new screens).
- [ ] Picker flips all of them live, no relaunch.
- [ ] Every new L10n key non-empty + distinct across RU/EN; tests green.
- [ ] RU strings don't clip on the narrowest detent.

## Dependencies (other tasks)
- Consumed by `S-account-settings-screen`, `S-history-clickable`, `S-manage-delete-tools`, `S-keychain-api-key` (they call the new keys). Build the keys here, reference them there.
