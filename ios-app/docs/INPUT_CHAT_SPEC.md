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
_(append per task)_
