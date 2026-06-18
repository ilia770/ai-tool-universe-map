# INPUT_CHAT_SPEC

Owner domain: the bottom AI assistant dock. File: `UI/Search/SearchDock.swift`
(plus `UI/Search/SearchCore.swift`, `UniverseAssistantCore.swift` for logic).
Do NOT edit the universe map rendering or the rail here. Touch detail only if
chat presentation conflicts with it.

## Input focus (the black-screen bug)
- Focusing the input must NOT switch the app to a black/empty screen.
- Focus adjusts input/chat layout only. The universe may dim *slightly* and
  stay atmospheric; it must remain visible.
- Global dim/blur is a function of `universeMode` only (`mapOpacity`,
  `mapBlurRadius`, `dimOpacity`). Input focus is local state and must not
  drive those. Decouple — do not hoist focus into the global machine.

## Attachment button (single control, three states)
- Empty → paperclip icon.
- Menu open → menu listing Files and Photo (above the input).
- Attached → a small file/photo pill indicator.
- "Remove attachment" available ONLY when an attachment exists.
- No random flipping between plus / file / paperclip. The trailing button is a
  separate control (Send / Add tool), not the attachment icon.

## Attachment menu
- Appears ABOVE the input.
- Does not cover the chat text awkwardly.
- Dismisses on outside tap.
- Does not stay open after send or after removing the attachment.

## Chat panel
- No duplicated "Add tool" / "Attach files" controls. Each action appears once
  per screen state. (Known bug: access actions can render both in the composer
  and inside an assistant message — dedupe by state.)
- Chat card stays readable (Dynamic Type respected — already converted to
  semantic styles + `@ScaledMetric` in `MarkdownMessageText`).
- Collapse/expand is consistent (`conversationCollapsed`).

## Send / plus button
- Trailing button is Send when input is focused, Add-tool otherwise.
- Send disabled when there is no text AND no attachment; enabled when either
  exists. Clear icon state.
- Successful send clears the text (`clearComposer`).

## State boundary
Focusing the input REQUESTS `chatOpen(prevContext)` via the machine; it does
not set a second copy of mode. `isInputFocused` and `attachmentState` are
local to `SearchDock`.

## Manual QA steps
1. Tap input → keyboard rises, universe dims slightly but is visible (no black).
2. Tap attachment → menu appears above input, over nothing important.
3. Pick Files → icon becomes a file pill; Remove appears.
4. Tap Remove → returns to paperclip; menu not stuck open.
5. Type text → Send enables; clear text + no attachment → Send disables.
6. Send → text clears, menu closed, chat readable.
7. Confirm only ONE Add-tool and ONE Attach-files control on screen at a time.

## Changed files / QA done / Remaining issues

### Agent 2 — chat / input / attachment fix (landed)

**Single home for access actions (de-dup rule).** Attach and Add-tool live in
exactly one place: the composer. Attach = the paperclip menu (left of the
field). Add-tool = the trailing `+` button (shown when the field is not
focused). Assistant messages that need access (`needsAccessActions`) no longer
render their own "Add tool" / "Attach files" buttons — they only show a text
hint pointing at the composer controls. This guarantees the same action never
appears twice on screen.

**Attachment control = single control, three states.**
- empty → paperclip glyph (`ComposerLogic.attachmentTriggerIcon` is always
  `"paperclip"` — the glyph no longer flips to file/photo).
- menu open → the `Menu` lists Files and Photo, opening above the dock (it sits
  at the screen bottom, so SwiftUI opens it upward); auto-dismisses on outside
  tap and on selection (never stuck after send/remove).
- attached → a separate file/photo pill (`attachmentPill`) is the only attached
  indicator. "Remove attachment" appears only when attached (in the menu and by
  tapping the pill).
The trailing Send / Add-tool button is a separate control.

**Send enablement.** `trailingActionButton` (send) now uses `canSend`
(`ComposerLogic.canSend(hasText:hasAttachment:)` = text OR attachment).
Disabled only when there is no text AND no attachment.

**Send clears text.** `submit()` → `model.askAssistant()` sets
`assistantQuery = ""`, then clears the attachment and resigns focus. Verified.

**Safe area.** `SearchDock` adds no `ignoresSafeArea`; it is placed by
`UniverseOverlayView` inside a safe-area-respecting `VStack`, so the composer
respects the safe area / home indicator. No change needed at the dock boundary.

**State boundary respected.** `fieldFocused` (`@FocusState`) and
`selectedAttachment` stay local to `SearchDock`; no global map dimming added.
Single source of truth (`model.universeMode`) untouched.

**Changed files**
- `UI/Search/SearchCore.swift` — added pure `ComposerLogic` (canSend,
  attachmentTriggerIcon, showsRemoveAttachment, rendersInMessageAccessButtons).
- `UI/Search/SearchDock.swift` — `canSend` send-enablement; paperclip-only
  attachment trigger glyph; removed duplicate in-message access buttons (and the
  now-orphaned `accessActionLabel`); de-dup hint text.
- `Tests/MyAIMapTests/ComposerLogicTests.swift` — 9 new tests for the rules.

**QA done**
- `xcodegen generate` clean.
- `xcodebuild test` → BUILD/TEST SUCCEEDED on iPhone 17 sim.
- xcresult: `passedTests` 88 (79 baseline + 9 new), `failedTests` 0.

**Remaining issues**
- Visual/simulator QA from `QA_REGRESSION_CHECKLIST.md` (menu placement above
  input on small devices, keyboard interactions) not yet run on-device.
- `chatOpen`-on-bare-focus question (lighter composer state vs full chat) noted
  by Agent 1 is unchanged here; out of this task's scope.
