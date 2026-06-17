# Anthropic API key (Keychain)

**Phase:** S · **Lens:** shell

## Goal (1-2 lines)
A Settings field where the user pastes their own Anthropic API key, stored in the **Keychain** (never UserDefaults, never bundled). Phase I's `IntelligenceService` reads it; absence degrades gracefully to the offline rule fallback with an "add key for smart features" nudge.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `State/APIKeyStore.swift` — thin Keychain wrapper (`SecItem*`) for one secret; the only Keychain touch-point, mirroring how `HistoryStore` is the only UserDefaults touch-point for history.
- create `UI/Settings/APIKeyScreen.swift` — secure paste/clear field + help text + masked status.
- modify `UI/Settings/SettingsSheet.swift` — add the API-key row (`NavigationLink` → `APIKeyScreen`).
- modify `State/L10n.swift` — `apiKey`, `apiKeyHelp`, `save`, `delete` (RU+EN) — coordinate with `S-language-ru-en`.

## Approach (bullet steps)
- `APIKeyStore`: `kSecClassGenericPassword`, fixed `account`/`service` (`com.myaimap.anthropicAPIKey`), `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Methods: `save(_:)` (upsert), `read()`, `delete()`. No async needed; keep pure-ish and headless-testable by injecting the service name.
- Never log or export the key: ensure `AppSettings.exportJSON()` (L52-60) does NOT include it; add a test asserting the export payload has no key field.
- `APIKeyScreen`: `SecureField`/paste-only; show masked `sk-ant-…••••` when set, "Add key" when empty; Save + Clear buttons with confirm on clear. Help line links the value to smart features.
- Provide a read-only accessor Phase I consumes: `APIKeyStore.read()` returns `String?`; document that `nil` → offline fallback + nudge (the nudge UI is Phase I/A, not this task).
- App Store safety: no secret key in `.env`/Info.plist; this is user-paste only. State that explicitly in the PR.

## Interface / contract (Swift signature sketch — signatures only)
```swift
struct APIKeyStore {
    init(service: String = "com.myaimap.anthropicAPIKey")
    func save(_ key: String) throws
    func read() -> String?
    func delete()
    var hasKey: Bool { get }
}
struct APIKeyScreen: View { }
```

## Tests (what to assert; reference real Tests/MyAIMapTests conventions)
- New `APIKeyStoreTests.swift` (Keychain is available in the test host): `save` then `read` round-trips; `delete` then `read == nil`; `hasKey` reflects state. Use a unique per-test `service` string (like `freshDefaults()` suite-name pattern in `AppSettingsTests`) and `delete()` in teardown so tests don't leak Keychain items.
- Extend `AppSettingsTests.exportProducesNonEmptyJSON`: assert exported JSON contains no `apiKey`/`sk-ant` substring (secret never leaves the device via export).
- `L10nTests` loop covers `apiKey`/`apiKeyHelp`/`save`.

## Done criteria (checklist)
- [ ] Key stored in Keychain only; round-trip + delete tested; teardown cleans items.
- [ ] Key never in UserDefaults, export JSON, or bundle; export-exclusion test passes.
- [ ] Field masks the key; empty state nudges; `read()` ready for Phase I.
- [ ] L10n RU+EN; tests green.

## Dependencies (other tasks)
- Row hosted by `S-account-settings-screen`; L10n from `S-language-ru-en`. Produces the key Phase I `intelligence-service-core` consumes (downstream, not a blocker here).
