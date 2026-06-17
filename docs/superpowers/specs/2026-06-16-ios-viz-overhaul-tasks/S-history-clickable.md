# History — clickable timeline

**Phase:** S · **Lens:** shell

## Goal (1-2 lines)
Turn the dead Settings → History row into a real added/removed timeline where tapping an item dismisses Settings and opens that tool's window (`focusTool`). Make history actionable, not decorative — today `SettingsSheet.historySection` "fires feedback only" (L153-176).

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `UI/Settings/HistoryScreen.swift` — full vertical timeline list (the `historySection` row navigates here).
- modify `UI/Settings/SettingsSheet.swift` — replace the no-op `historySection` button (L158-160) with a `NavigationLink` to `HistoryScreen` (needs the `NavigationStack` from `S-account-settings-screen`).
- modify `UI/Search/HistoryStrip.swift` — reuse `HistoryChipModel` (L6-19) for row title/`isDeleted`/accessibility; lift it to its own file if both surfaces import it.
- (read) `State/UniverseViewModel.swift` — `recentHistory`/`history.recents` (L102-106), `focusTool(_:)` (L148-155).

## Approach (bullet steps)
- `HistoryScreen` lists `model.history.recents(limit:)` (raise limit, e.g. 30, for a full timeline vs the strip's 6) newest-first via `HistoryChipModel`; group/badge by `event.kind` (added vs deleted) with `historyAdded`/`historyRemoved` L10n + relative `event.timestamp` (`RelativeDateTimeFormatter`).
- Tap handoff: row tap must (1) `dismiss()` the Settings sheet, then (2) `model.focusTool(event.toolID)` so the tool window opens on the map. Order matters — focusing under a presented sheet hides the result. Pass the dismiss + a `focus: (String)->Void` closure from `UniverseScreen` (set `settingsPresented = false` then `focusToolFromMap(id)`), mirroring `HistoryStrip.openTool` (L100-109).
- Deleted-tool rows: if `removedToolIDs` contains the id, offer Restore (`model.recordAdded` then focus) — parity with the strip's context menu (L81-94). A deleted tool can't be focused until restored; guard `focusTool` returns false.
- Empty state: `noToolsAdded` L10n when `recents` is empty (no add flow yet means it can be empty — don't show a broken list).

## Interface / contract (Swift signature sketch — signatures only)
```swift
struct HistoryScreen: View {
    let onOpen: (_ toolID: String) -> Void   // dismiss-then-focus, owned by UniverseScreen
}
struct HistoryRowModel: Identifiable {        // or reuse HistoryChipModel
    var title: String; var isDeleted: Bool; var timestamp: Date
}
```

## Tests (what to assert; reference real Tests/MyAIMapTests conventions)
- Extend `HistoryStripModelTests`/new `HistoryScreenTests`: `HistoryChipModel(event:).title` resolves seed name and falls back to id; `isDeleted` maps `.deleted`.
- View-model behavior (mirror `ToolDeleteFlowTests`): record `.added` for `figma`, assert `focusTool("figma") == true` and selection updates; record `.deleted`, assert a deleted id still has a Restore path (`recordAdded` then `focusTool` true).
- `recents(limit:)` ordering already covered by `ToolHistoryTests` — keep green.

## Done criteria (checklist)
- [ ] History row pushes a real timeline; added/removed visually distinct with timestamps.
- [ ] Tapping an item closes Settings and opens that tool's window (verified order).
- [ ] Deleted items offer Restore; empty state localized.
- [ ] Tests green.

## Dependencies (other tasks)
- Needs `NavigationStack` from `S-account-settings-screen`; L10n keys from `S-language-ru-en`. Reuses existing `ToolHistory`/`HistoryStore`/`focusTool` (no new state model).
