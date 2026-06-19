# CHAT_INPUT_SPEC

Owner: Codex. Files: `UI/Search/SearchDock.swift` (input + composer + chat
panel) and the chat bubble views it hosts. Supersedes the chat parts of the
older `INPUT_CHAT_SPEC.md`. Do NOT edit the universe scene, rail, or the
`UniverseMode` dim contract values (read them, don't change them).

## State contract (read-only from the machine)
Chat presentation derives from `UniverseMode` (`UI_STATE_MACHINE.md`):
- `mapOpacity` 0.7 / `dimOpacity` 0.18 in `.chatOpen` — chat is a **secondary
  input layer, never a takeover**. Focusing the input must NOT black out the
  universe. The current "wrong darkening on focus" bug = something overriding
  these values on first-responder; fix the override, keep the contract.
- `isChatOpen` toggling is owned by `setChatOpen(_:)` in `UniverseMapView`; the
  dock REQUESTS open/close via `onChatActivityChange`, it does not mutate mode.

## Message bubbles
- **User message:** bubble with **content-fit width** via auto-layout
  (`fixedSize(horizontal: false, vertical: true)` + `frame(maxWidth:` ~78% of
  panel, `alignment: .trailing)`). No fixed width, no full-width stretch, no
  excess L/R space — padding symmetric inside the bubble (12–14pt h, 8–10pt v),
  corner radius ~18, aligned to the **trailing** edge.
- **Assistant message:** NO bubble — structured text on the panel surface,
  full markdown (tables, lists, bold), readable line spacing. Renders the
  `AssistantReply.chips` below/inline per `CHAT_AI_SPEC.md`.
- Alignment: user trailing, assistant leading. The chat panel keeps a slight
  fill so transparent text never stacks illegibly.

## Input field / composer
- Field spans dock width minus side paddings; the "narrower" feel comes from
  padding, not a fixed small width.
- **Focus:** only adjusts composer/keyboard layout. Universe stays atmospheric
  (mode contract above). Tap outside the field resigns focus.
- **Plus / Send (single control, right of field):**
  - empty field, no attachment → **plus** (opens attach menu / add affordance).
  - text OR attachment present → **send** (up-arrow), enabled.
  - disabled send is visibly inert (never an enabled-looking no-op).
  - sending clears text and attachment.

## Attachments
- **Attach control (left of field):** single paperclip. States:
  - empty → paperclip.
  - menu open → menu with **Files** and **Photo** (icons), anchored ABOVE the
    input, dismiss on outside tap, never covering chat text.
  - attached → file/photo pill with remove (x); remove only when an attachment exists.
- **No duplicate controls:** "Add tool" and "Attach files" each appear at most
  once at a time. The current duplication is a state bug — affordances must be
  derived from ONE state, not two overlapping views.

## Collapse / expand
- Collapse → panel minimizes (keeps a restore affordance), universe returns to
  its prior navigable mode.
- **Expand/reopen must restore the same conversation + scroll position.** The
  "reopen doesn't work" bug = collapse tears down state or the restore control
  is dead. Collapse is a visibility toggle over persisted conversation state
  (`assistantMessages` in `UniverseViewModel`), not a reset.

## Acceptance criteria
- User bubble width hugs its text (1 word = small bubble; long message wraps, ≤~78% width).
- Focusing input never darkens the universe beyond the `.chatOpen` contract.
- Plus↔Send swap correct for every (text, attachment) combination.
- Attach menu opens above input, dismisses on outside tap; no duplicate add/attach controls.
- Collapse then expand restores exact prior messages + scroll.
- Markdown tables/lists/bold render in assistant messages; chips tappable.

## Manual QA
1. Send "hi" → tiny right-aligned bubble. Send a paragraph → wraps, ≤78% width.
2. Focus field → universe stays visible (light scrim only), not black.
3. Empty field shows plus; type → enabled send; send → clears.
4. Tap paperclip → Files/Photo menu above input → attach → pill+remove → remove resets.
5. Confirm one "Add tool" and one "Attach files" max on screen.
6. Collapse mid-conversation → reopen → same messages + position.
