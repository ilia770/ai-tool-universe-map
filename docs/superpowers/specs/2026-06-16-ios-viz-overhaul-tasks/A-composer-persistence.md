# Composer persistence across tool sheets

**Phase:** A · **Lens:** app-quality

## Goal (1-2 lines)
The chat composer stays reachable through a conversation: when a tool sheet opens it yields gracefully (per the no-active-panel gate) without destroying draft text or scroll position.

## Repro / symptom (grounded in real code)
- `ChatDock` is conditionally mounted: `if !isPanelActive { ChatDock() … }` (`UniverseScreen.swift:122-127`). The moment `sheetDetent != .height(118)` (`:17-19`), the whole view is removed from the tree, destroying its `@State` — `text` (draft), `collapsed`, `peekId`, `dragOffset` (`ChatDock.swift:20-23`) (QA #2).
- `chatThread` turns survive (owned by `UniverseScreen.swift:9` and persisted via `ChatThreadStore`), but the **in-progress composer draft is lost**. Repro: type a half query, drag the detail sheet past peek, drag back → draft gone.
- Tapping a match card (`ChatDock.open` → `model.focusTool`, `:239-245`) does not itself expand the sheet, but any later drag past peek unmounts the dock — fragile coupling of composer lifetime to an unrelated sheet detent.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- Modify `Universe/UniverseScreen.swift` (stop unmounting `ChatDock`; hide via opacity/offset or move draft ownership up).
- Modify `UI/Chat/ChatDock.swift` (lift `text`/`collapsed` draft to an injected store OR bind from parent so it survives visibility toggles).

## Approach (bullet steps)
- Replace the conditional **mount** with a conditional **visibility**: keep `ChatDock` in the tree always, drive `.opacity`/`.allowsHitTesting`/`.offset` off `isPanelActive` so SwiftUI preserves its `@State` (drafts, scroll). Yields visually when a panel is active without destroying state.
- If keeping it mounted is undesirable for layout, lift the draft `text` into a small `@Observable ChatComposerDraft` injected via `.environment` (mirrors `ChatThreadStore` ownership in `UniverseScreen.swift:9`) so it persists across remounts.
- Preserve the existing web-parity gate semantics ("FindBar hides when a tool window opens") — the dock is non-interactive/blurred when `isPanelActive`, just not deallocated.
- Keep Reduce-Motion gating via `.brandAnimation`/`BrandMotion.resolved`.

## Interface / contract
```swift
@MainActor @Observable final class ChatComposerDraft { var text: String = ""; var collapsed = false }
```

## Tests (Tests/MyAIMapTests conventions)
- `ChatComposerDraftTests` (pure, like `ChatThreadStoreTests.swift`): draft mutations survive independent of thread; default empty.
- ImageRenderer test (like `SettingsSheetTests.swift`): `UniverseScreen` with `isPanelActive == true` still renders the dock (non-nil) but as non-interactive.
- Reuse `ChatThreadStoreTests.persistsAndReloads` to confirm turns are unaffected by this change.

## Done criteria (checklist)
- [ ] Type draft → expand+collapse detail sheet → draft preserved.
- [ ] Scroll position / peek state survive a sheet detent change.
- [ ] Dock is visually subdued + non-interactive while a panel is active (gate preserved).
- [ ] No double source of truth for "panel active".

## Dependencies (other tasks)
- A-chat-discoverability (shared `isPanelActive` rework); A-chat-scroll (shares `threadScroll` mount logic).
