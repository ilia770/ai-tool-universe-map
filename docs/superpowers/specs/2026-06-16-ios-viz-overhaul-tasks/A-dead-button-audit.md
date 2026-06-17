# Dead-button audit + double-tap distinction

**Phase:** A · **Lens:** app-quality

## Goal (1-2 lines)
Every tap target performs a real action: wire Settings→History to a real destination, make double-tap distinct from single-tap, and sweep all controls for no-op handlers (HIG: no dead controls).

## Repro / symptom (grounded in real code)
- **Settings → History is a no-op.** `SettingsSheet.swift:153-176`: the button body only fires `BrandHaptics.fire(.light)` (`:159`); the comment (`:156-157`) admits the destination "ships in a later product-v2 part," yet it renders a `chevron.right` (`:165`) promising navigation → reads as broken (QA #3).
- **Double-tap == single-tap.** `UniverseView.swift:374-376`: `handleDoubleTap` just calls `handleTap`; the comment (`:365-373`) admits the distinct fly-to is deferred. A quick double-tap can fire BOTH the `count:2` and `count:1` recognizers → two haptics + redundant `onToolSelect` (QA #4).
- **ClarityMenu is dead.** `UniverseScreen.swift:114-119`: intentionally not mounted; file `UI/Sheets/ClarityMenu.swift` exists but is unreachable (QA #3). Confirm no stray entry point.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- Modify `UI/Settings/SettingsSheet.swift` (History row → real destination; reuse `HistoryChipModel` + `model.recentHistory`).
- Modify `Universe/UniverseView.swift` (`handleDoubleTap` distinct from `handleTap`; guard against double-fire).
- (Audit only — no required change) `UI/Sheets/ClarityMenu.swift`, `UI/Sheets/CategoryRail.swift`, `UI/Search/SearchDock.swift`, header `AccountButton`.

## Approach (bullet steps)
- History: present a History list (`NavigationStack` push or `.sheet`) built from `model.recentHistory.map(HistoryChipModel.init)` (same model `HistoryStrip.swift:6-19` uses); tapping a row calls `model.focusTool(id)` and dismisses Settings — turning the chevron's promise into a real navigation.
- Double-tap: give it distinct behavior — single-tap selects (`handleTap`), double-tap on a node = closer fly-to/focus (route through a distinct focus path) and double-tap on empty space = reset to `.core`. Suppress the trailing single-tap so only one haptic/select fires.
- ClarityMenu: confirm it stays hidden (no half-wired control) OR remove the dead import; document the decision inline. Do not ship a visible no-op.
- Audit pass: grep for `BrandHaptics.fire` handlers with no state effect; each must navigate, mutate, or be removed.

## Interface / contract
```swift
struct HistoryListView: View { let onOpen: (String) -> Void } // rows from HistoryChipModel
```

## Tests (Tests/MyAIMapTests conventions)
- Reuse `HistoryStripModelTests.swift` / `ToolHistoryTests.swift` conventions: assert `HistoryChipModel.title`/`accessibilityLabel` resolve for the History list rows.
- `HistoryListTests` (ImageRenderer like `SettingsSheetTests.swift`): renders non-nil; empty-history shows an empty state; non-empty shows N rows == `recentHistory.count`.
- Double-tap: extend `UniverseSelectionTests.swift`/`UniverseViewModelTests.swift` to assert the focus path a double-tap routes to differs from plain select (e.g. distinct camera/focus call), and a single select fires one state change.

## Done criteria (checklist)
- [ ] Settings→History opens a real, populated list; tapping a row opens that tool.
- [ ] Double-tap a node ≠ single-tap (distinct fly-to); empty-space double-tap resets.
- [ ] No double haptic / double select on a quick double-tap.
- [ ] No remaining visible control with a no-op handler (ClarityMenu hidden or wired).

## Dependencies (other tasks)
- Phase S history-clickable (shares the History destination; align so they don't both build separate list views).
