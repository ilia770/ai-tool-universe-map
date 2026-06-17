# Account / Settings screen IA

**Phase:** S · **Lens:** shell

## Goal (1-2 lines)
Make `SettingsSheet` the single Account/Settings hub that hosts every shell section without burying any: Visualization, Language, History, Manage tools, Anthropic API key, About. Order by frequency-of-use so the daily features (History, Manage) are above the fold, not under About.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- modify `UI/Settings/SettingsSheet.swift` — already has `visualizationSection`, `languageSection`, `historySection`, `dataSection`, `aboutSection`. Re-order the `VStack` (L21-28) and add navigation destinations + the API-key + manage-tools rows.
- modify `State/L10n.swift` — add `manageTools(_:)`, `apiKey(_:)`, `account(_:)` strings (RU+EN).

## Approach (bullet steps)
- Section order top→bottom: Account/profile header → Visualization → Language → **History** (clickable, `S-history-clickable`) → **Manage tools** (`S-manage-delete-tools`) → **Anthropic API key** (`S-keychain-api-key`) → Data (export/reset) → About.
- Convert the `ScrollView`+`VStack` into a `NavigationStack` so History and Manage push their own screens (the design says "tapping history opens that tool's window" — see `S-history-clickable` for the dismiss-then-focus handoff; Manage pushes an in-sheet list).
- Each new entry is a glass row matching `historySection`'s recipe (`liquidGlass(in: RoundedRectangle(16))`, chevron, `PressableButtonStyle`). Do NOT add disabled/dead rows — a row with no destination violates the "no dead button" rule (review NEW-6); gate each behind its sibling task landing.
- Keep `.presentationDetents([.medium, .large])` from `UniverseScreen.swift:73`; `NavigationStack` lives inside the sheet.

## Interface / contract (Swift signature sketch — signatures only)
```swift
struct SettingsSheet: View {                 // gains NavigationStack root
    private var accountHeader: some View
    private var historyRow: some View         // NavigationLink → HistoryScreen
    private var manageToolsRow: some View     // NavigationLink → ManageToolsScreen
    private var apiKeyRow: some View          // NavigationLink → APIKeyScreen
}
```

## Tests (what to assert; reference real Tests/MyAIMapTests conventions)
- Extend `SettingsSheetTests.swift`: `rendersNonNil` still passes with the new IA; render at `.medium` size and assert non-nil.
- `L10nTests.bothLanguagesCoverEveryKey` — add the new keys (`manageTools`, `apiKey`, `account`) to the loop; `ruAndEnDiffer` sample one new key.

## Done criteria (checklist)
- [ ] All six sections reachable from one Settings hub; History + Manage above About.
- [ ] No dead rows: every row has a real destination/action.
- [ ] Glass material consistent with existing rows; detents unchanged.
- [ ] L10n covers new keys in RU + EN; tests green.

## Dependencies (other tasks)
- Hosts `S-language-ru-en`, `S-history-clickable`, `S-manage-delete-tools`, `S-keychain-api-key`. Opened by `S-top-bar-account-circle`. Land destination tasks before exposing their rows.
