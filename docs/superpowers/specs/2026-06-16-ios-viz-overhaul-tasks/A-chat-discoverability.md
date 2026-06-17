# Persistent assistant entry point

**Phase:** A · **Lens:** app-quality

## Goal (1-2 lines)
A user can always find where to "ask / create" with the map. The assistant affordance is visible and obvious even when collapsed or hidden behind a tool window.

## Repro / symptom (grounded in real code)
- `ChatDock` is only in the tree when `!isPanelActive` (`UniverseScreen.swift:122-127`), and `isPanelActive = sheetDetent != .height(118)` (`:17-19`). Open any tool (which can later expand the sheet) and the entire composer vanishes — there is no re-entry affordance, so the assistant becomes undiscoverable mid-session (QA #2, design A-quality §2).
- When collapsed (`ChatDock.collapsed = true`, set on swipe-down `:260`), only the composer capsule remains; the example-query empty state (`:156-177`) is unreachable dead code because `showThread` requires `!turns.isEmpty` (QA #21) — so a returning user gets no "ask the map" prompt cue.
- There is no labeled, glanceable "Ask / Create" control; the composer placeholder "Ask the map…" (`:183`) is the only hint and it disappears with the dock.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- Modify `Universe/UniverseScreen.swift` (add a persistent assistant affordance that survives `isPanelActive`).
- Modify `UI/Chat/ChatDock.swift` (expose a collapsed "pill" entry that re-expands the thread/composer; reach the example-query cues).

## Approach (bullet steps)
- Always render a minimal **assistant pill** (glass capsule, `sparkles`/`text.bubble` glyph + "Ask the map") pinned bottom even when `isPanelActive`, so the entry point never disappears. Tapping it dismisses/peeks the detail sheet enough to reveal the composer (drop `sheetDetent` to `.height(118)`).
- When the thread is empty and composer focused, surface the `exampleQueries` chips (currently orphaned `:161-176`) as a discoverable prompt strip so first-run users see what to type.
- Keep one source of truth: reuse `sheetDetent`/`isPanelActive` rather than adding a parallel flag.
- Accessibility label via `L10n` (RU/EN) consistent with `AccountButton` (`UniverseScreen.swift:224`).

## Interface / contract
```swift
struct AssistantPill: View { let action: () -> Void } // glass capsule, BouncyIconButtonStyle
```

## Tests (Tests/MyAIMapTests conventions)
- `AssistantDiscoverabilityTests` (ImageRenderer like `SettingsSheetTests.swift`): `UniverseScreen` renders the assistant affordance non-nil with `isPanelActive == true` (seed an expanded detent).
- Assert `ChatDock` empty-state example chips are reachable: with an empty `ChatThreadStore`, focusing the composer exposes `exampleQueries` (render non-nil + chip count == 3).
- Reuse `AccessibilityLabelTests.swift` pattern to assert the pill has a non-empty RU and EN label.

## Done criteria (checklist)
- [ ] Assistant entry point is visible with a tool window open.
- [ ] Tapping it reveals the composer (sheet yields, dock returns).
- [ ] Empty thread shows example-query cues (no dead code path).
- [ ] Labeled for VoiceOver in RU and EN.

## Dependencies (other tasks)
- A-composer-persistence (both fix the `isPanelActive` unmount; land together).
