# INPUT_CHAT_SPEC

> **Historical/target-state warning — 2026-07-16.** The source-verified
> **Current baseline status** section below is the current contract. Earlier
> agent reports and prescriptive sections are retained as dated context and do
> not establish live behavior when they conflict with that baseline.

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
- Menu open → inline menu listing Files and Photo (above the input).
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
- Trailing button is Send when input is focused, has text, or has an
  attachment. It is Add-tool only when the composer is fully idle.
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

### Historical Agent 2 — chat / input / attachment fix (superseded where noted)

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
- menu open → the then-current `Menu` listed Files and Photo above the dock.
  It was later replaced by the custom inline popover described in the current
  baseline below.
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

### Agent 2b — Founder OS chat context decision (landed)

**Product decision.** Fresh overview opens a general chat, even though the
selection projection defaults to `founder-os` for card parity. If the user
explicitly selects a core tool (`founder-os` or `openswarm`) before opening
chat, chat preserves that `.core` tool context and dismissing chat can restore
the explicit core selection.

**Implementation.** `UniverseMode.chatContext(...)` centralizes the rule so
`UniverseMapView` no longer hard-codes `founder-os` as "no tool". The helper
uses the explicit mode-selected tool to distinguish real core-tool selection
from the overview projection fallback.

**Changed files**
- `Universe/UniverseMode.swift` — added `chatContext(...)` helper.
- `Universe/UniverseMapView.swift` — routes chat-open transitions through the
  helper.
- `Tests/MyAIMapTests/UniverseModeTests.swift` — 3 tests for general overview,
  explicit Founder OS, and explicit core-satellite chat context.

**QA done**
- `npm run ios:verify` — build + build-for-testing succeeded.
- `xcodebuild ... -only-testing:MyAIMapTests ... test-without-building` —
  124 Swift tests / 16 suites passed, result bundle `/tmp/aimap-unit.xcresult`.
- `xcodebuild ... -only-testing:MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates ... test-without-building`
  — UI smoke passed on iPhone 17 Pro, result bundle `/tmp/aimap-ui.xcresult`.

**Remaining issues**
- `rail-edge-swallows-map-pan` still needs manual gesture arbitration QA.
- `scene-rebuild-on-opacity` remains a risky performance refactor and was not
  touched.

### Agent 2c — bubble layout, collapse/expand, inline attachment menu (landed)

**Message layout.** User messages now align trailing and use natural-width
`ViewThatFits` bubbles: short Russian/English text stays compact, while long
text wraps inside a max width of 80% of the available phone width. Assistant
messages align leading and are capped separately so short
answers do not become huge full-width blocks, while structured tables/chips can
still use readable width.

**SUPERSEDED collapse claim.** This record described keeping chat active while
collapsed. Current `ComposerLogic.keepsChatActive` deliberately ignores
collapsed content, so collapsing normally emits inactive chat activity and
restores the map mode; see the current baseline below.

**Attachment menu.** The SwiftUI `Menu` was replaced by a custom inline
popover rendered above the composer row. The trigger stays a paperclip. Files
and Photo are explicit rows; Remove appears only when attached. The popover
dismisses on selection, remove, send, and focus loss/outside tap.

**Send / plus behavior.** The trailing button is Send whenever the composer is
focused, has text, or has an attachment. It is the Add-tool plus only when the
composer is idle. Attachment-only send now creates a compact "Attached file" /
"Attached photo" user message instead of becoming a no-op.

**Changed files**
- `UI/Search/SearchCore.swift` — added pure `ComposerLogic` rules for send
  button visibility, attachment-only outgoing message text, collapsed-chat
  activity, and bubble max-width ratio.
- `UI/Search/SearchDock.swift` — compact user/assistant message layout; inline
  attachment popover; collapse/reopen state fix; attachment-only submit; stable
  send-vs-plus trailing button behavior.
- `Tests/MyAIMapTests/ComposerLogicTests.swift` — added rule coverage for
  send/plus visibility, outgoing message text, collapsed chat activity, and
  bubble width ratio.

**QA done**
- `git diff --check` clean.
- `npm run ios:verify` passed outside sandbox: `TEST BUILD SUCCEEDED`.
- XcodeBuildMCP `MyAIMapTests` passed on iPhone 17 Pro:
  `passedTests = 145`, `failedTests = 0`.
- Direct UI smoke passed on iPhone 17 Pro:
  `UniverseUISmokeTests/testCaptureKeyStates`, 1 test, 0 failures. It covered
  input focus, attachment menu, Files selection, and attached pill screenshots.

**Remaining issues**
- Manual device QA is still needed for keyboard/safe-area feel and visual bubble
  compactness on small iPhone and iPad sizes; automated smoke confirms the
  state path but does not judge final visual density.

### Codex follow-up - measured dock width and chat lifecycle (2026-06-21)

**Parent-driven chat visibility.** `SearchDock` now receives `isChatOpen` from
the overlay. Conversation content and the collapsed transcript pill render only
while the global navigation machine is in chat mode. Leaving chat clears focus,
closes the attachment menu, and collapses the transcript without duplicating or
leaking old assistant text behind the visible card.

**Bubble sizing.** User and assistant bubble widths are computed from the
measured dock width instead of `UIScreen.main.bounds`. Short user messages stay
compact and trailing; long Russian/English messages wrap inside the measured
chat panel.

**Attachment anchoring.** Tapping inside the transcript or reopening the
collapsed pill closes the attachment popover, so the Photo/Files menu stays
anchored to the composer instead of floating over unrelated content.

**QA done**
- Manual simulator checks covered: input focus with keyboard, attachment menu,
  attachment menu over keyboard, short general chat send, collapse/reopen path.
- Unit and UI smoke gates passed in the stabilization run (see
  `QA_REGRESSION_CHECKLIST.md` follow-up).

---

## Current baseline status — 2026-07-16

This addendum distinguishes source-confirmed behavior from historical run
records above.

### Input ownership and visible states

| Concern | Current owner | Confirmed behavior |
| --- | --- | --- |
| Text/query | `UniverseViewModel.assistantQuery` | shared model text; `SearchDock` binds the composer. |
| Focus / keyboard | `SearchDock.fieldFocused` | local/transient; it can request in-map `UniverseMode.chatOpen`. |
| Transcript | `UniverseViewModel.assistantMessages` | shared between map dock and root `ChatScreen`, but not persisted. |
| Collapse/menu/attachment | local `SearchDock` state | one floating lane shows menu **or** attachment preview. Collapsing clears focus/menu; unless a staged attachment remains, the activity callback restores normal map mode while the local **Show chat** pill can remain. |
| Attachment contents | none | photo bytes may be read locally for size and file resource metadata for preview; no attachment bytes are transmitted to the assistant, which says it cannot inspect them. |

### Two distinct chat surfaces

1. **Root Chat:** `RootShell.surface == .chat` mounts full-screen `ChatScreen`.
   Its Map return moves to root map and resets map mode to overview.
2. **In-map chat:** `SearchDock` is mounted by `UniverseOverlayView`; activity
   may enter `UniverseMode.chatOpen`, where the map remains atmospheric. Its
   normal close path is an activity/blur/collapse callback, which restores a
   context-derived map mode. The canvas does not close it because map gestures
   are disabled while chat is open.

These surfaces share model transcript/query but not focus, collapse, scroll,
or exact navigation restoration state. Do not merge them casually.

### Runtime verification still needed

- actual keyboard/safe-area behavior on small iPhone, iPad, and hardware
  keyboards;
- PhotosPicker/FileImporter cancellation/reselection on device;
- map tap hit testing after dock collapse/attachment menu close;
- visual native-glass behavior on iOS 26 and Reduce Motion/Transparency modes.
