# Add-Tool "+" FAB → AddToolSheet

**Phase:** A · **Lens:** app-quality

## Goal (1-2 lines)
A liquid-glass circular "+" FAB on the canvas opens an AddToolSheet, giving users the obvious way to add a tool/skill to the map (the intake intelligence already exists in code).

## Repro / symptom (grounded in real code)
- There is **no add-tool affordance** on iOS. Grep for `AddTool`/`FAB`/`intake` in `Sources/MyAIMap` returns only haptic `classifySuccess` patterns (`CoreHapticsEngine.swift:21,96,137`) and a `ShimmerLoader` comment ("while the Liquid Glass intake field is classifying", `:4`) — i.e. the classify haptic + loading state were built for an intake flow that has no UI entry point. Design A-quality §6 calls this out: "'+' Add-Tool FAB → AddToolSheet (intake intelligence already in code)."
- The canvas chrome (`UniverseScreen.canvas`, `:83-138`) has header / SearchDock / HistoryStrip / PocketReadout / ChatDock / CategoryRail but no "+". `UniverseViewModel` exposes `recordAdded(_:)` (`UniverseViewModel.swift:163`) used today only by HistoryStrip "Restore" — there is no creation path that feeds it new tools.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- Create `UI/Sheets/AddToolSheet.swift` (intake field + classify → confirm → add).
- Create `UI/Chrome/AddToolFAB.swift` (circular glass "+").
- Modify `Universe/UniverseScreen.swift` (mount the FAB; present `AddToolSheet`; route the result to `model.recordAdded`).

## Approach (bullet steps)
- FAB: circular `liquidGlass(in: Circle())` "+" using `BouncyIconButtonStyle` + tint `model.selectedCategoryModel.color` (one family with `AccountButton`, `UniverseScreen.swift:206-226`). Pin bottom-trailing, clear of the CategoryRail/ChatDock; respect safe area + the `.padding(.bottom, 118)` sheet detent (`:132`).
- Sheet: a Liquid-Glass intake `TextField` (URL or name); on submit run the existing classifier path, show the `ShimmerLoader`/`ProgressOrb` while classifying, fire `classifySuccess` haptic on landing (`CoreHapticsEngine.swift`).
- On confirm, the committed tool is created with `userAdded = true` (flag added in `S-manage-delete-tools`); then call `model.recordAdded(toolId)` and `model.focusTool(toolId)` so it lands in History + opens and appears in Settings → Manage. Present via `.sheet` mirroring the `SettingsSheet` recipe (`UniverseScreen.swift:71-76`).
- Accessibility label via `L10n` (RU/EN), like `AccountButton`.

## Interface / contract
```swift
struct AddToolFAB: View { let action: () -> Void }
struct AddToolSheet: View { let onAdded: (String) -> Void }
```

## Tests (Tests/MyAIMapTests conventions)
- `AddToolFABTests` (ImageRenderer like `SettingsSheetTests.swift`): FAB renders non-nil; carries RU/EN a11y label (reuse `AccessibilityLabelTests.swift`).
- `AddToolSheetTests`: renders non-nil; submitting a recognized query yields a tool id → `onAdded` invoked; an unrecognized query surfaces the "couldn't identify" state (no fake tool), consistent with the intelligence guards in the design.
- Reuse `ToolHistoryTests.swift` to assert an added tool appears in `recents()` after `recordAdded`.

## Done criteria (checklist)
- [ ] Visible "+" FAB on the canvas, glass-styled, not overlapping rail/chat.
- [ ] Tapping opens AddToolSheet.
- [ ] Adding a tool records it in History and focuses it on the map.
- [ ] Unknown input does not invent a tool.
- [ ] VoiceOver labels in RU and EN.

## Dependencies (other tasks)
- Phase I identify-tool (the real classifier the sheet calls); Phase S manage-delete-tools (the add/remove pair). FAB can ship against the existing rule-based intake first.
