# Manage / delete tools

**Phase:** S · **Lens:** shell

## Goal (1-2 lines)
A Settings → Manage screen listing the user's tools/skills with a delete action, so removal lives in a deliberate management surface (not only buried at the bottom of the detail sheet). Reuses the existing soft-delete (`deleteTool`) and its history logging.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `UI/Settings/ManageToolsScreen.swift` — list + swipe/trailing delete, confirm dialog.
- modify `UI/Settings/SettingsSheet.swift` — add the Manage row (`NavigationLink` → `ManageToolsScreen`).
- (read, no change) `State/UniverseViewModel.swift` — `tools` (L69-71, seed minus `removedToolIDs`), `deleteTool(_:)` (L126-143), `recordAdded` for restore; `UI/Sheets/ToolDetailSection.swift:360` `canDelete(toolID:)`.

## Approach (bullet steps)
- **`userAdded` flag (locked):** add `userAdded: Bool` to `Tool` (default `false`; all seed tools `false`). The add-tool/intake flow (Phase A `A-add-tool-fab` + Phase I commit) sets `userAdded = true`. This Manage screen filters to `tool.userAdded == true` (still excludes `founder-os` via `ToolDetailSection.canDelete(toolID:)`). Requires updating the `Tool` model decode (backfill missing key → `false`) and `SeedIntegrityTests`/`KnowledgeIntegrityTests` to assert seed tools are `userAdded == false`.
- List the filtered tools flat, newest-added first using `history` order.
- Delete = `.swipeActions`/trailing `Button(role:.destructive)` → confirm dialog (mirror `ToolDetailSection.performDelete` + its confirm at L291) → `model.deleteTool(id)`. This already emits `ToolDeletion` to `deletionSink` → `recordDeleted` (history), so deletes show up in `S-history-clickable` for free.
- Removed tools section with Restore (`model.recordAdded(id)` clears it from the effective list because `tools` filters `removedToolIDs`; confirm re-add path clears the id — today `deleteTool` only inserts; restore needs a `restoreTool(_:)` or clearing `removedToolIDs`). Add `UniverseViewModel.restoreTool(_:)` if absent.
- Localize labels via `S-language-ru-en` (`manageTools`, `delete`, `restore`).

## Interface / contract (Swift signature sketch — signatures only)
```swift
struct ManageToolsScreen: View { }
extension UniverseViewModel {
    func restoreTool(_ id: String)            // clears id from removedToolIDs (+ recordAdded)
}
```

## Tests (what to assert; reference real Tests/MyAIMapTests conventions)
- Extend `ToolDeleteFlowTests`: delete via Manage path → `model.tools` excludes id, `deletionSink` logged it; `founderCoreIsNotDeletable` still holds (`canDelete("founder-os") == false`).
- New `restoreTool` test (mirror delete test): after `deleteTool` then `restoreTool`, `model.tools` contains the id again and history has both events.
- Render test for `ManageToolsScreen` (ImageRenderer, like `SettingsSheetTests`): non-nil.

## Done criteria (checklist)
- [ ] `Tool.userAdded` added (seed = false, backfill decode); Manage lists only `userAdded` tools; `founder-os` never deletable.
- [ ] Delete confirms, removes, and logs to history (visible in History timeline).
- [ ] Restore returns a removed tool; `restoreTool` added if needed.
- [ ] PR notes the `userAdded` gap pending Phase A. Tests green.

## Dependencies (other tasks)
- Needs `NavigationStack` from `S-account-settings-screen`; L10n from `S-language-ru-en`. Shares history with `S-history-clickable`. True user-added filter depends on Phase A add-tool flow.
