# UI_STATE_MACHINE — navigation & overlay state

Status: **SPEC + current-reality audit.** Implementation notes to be appended
by the State Machine agent after the refactor lands.

## Goal
One source of truth for navigation. Eliminate desync between the 3D map,
bottom chips, right rail, and the detail card. Make impossible visual states
unrepresentable.

## Global vs local state (important)
Not everything belongs in the global machine. Over-centralizing input focus
is itself a bug source.

**Global (single source of truth — the navigation machine):**
- `selectedCategory` (`ToolCategoryId`)
- `selectedTool` (`String` tool id)
- `universeMode` — overview / branchFocus / toolSelected / detail / chatOpen
- `isChatOpen` — derived from `universeMode == .chatOpen`
- `isRailActive` — rail drag in progress (transient navigation input)

**Local (per-view, must NOT flip global visuals):**
- `isInputFocused` (`@FocusState` in `SearchDock`) — keyboard/layout only.
- `attachmentState` (none / menu-open / attached) — local to `SearchDock`.

Rule: a local state may *request* a navigation transition (e.g. focusing the
input opens chat) but may never directly drive global dimming/blur. The
"input focus blacks out the universe" bug is exactly a local state wrongly
driving a global visual. Fix by decoupling, not by hoisting input into the
global machine.

## Current reality (as audited, pre-refactor)
- `universeMode` lives as `@State` in `UniverseMapView` (`UniverseMode` enum).
- `selectedCategory`/`selectedTool` live in `viewModel.selection`
  (`UniverseSelection`).
- They are kept in sync **manually**: `UniverseMapView.selectCategory` /
  `focusToolFromMap` mutate `mode`, and separately call
  `model.selectCategory` / `model.focusTool` which mutate `selection`.
- Sheet presentation uses extra booleans: `detailPresented`,
  `accountPresented`, `addToolPresented`.
- Most derived visibility already funnels through `UniverseMode` (good):
  `showsSatellites`, `showsToolAnchor`, `showsToolLabels`, `showsPlanetLabels`,
  `mapOpacity`, `mapBlurRadius`, `dimOpacity`, `orbitOpacityMultiplier`.

→ The enum is already a near-complete machine. The fix is to make
`selectedCategory`/`selectedTool` **derive from `universeMode`** (or make the
model own `universeMode` too), so there is exactly one writer.

## Target model

`UniverseMode` is the single navigation state. `selectedCategory` and
`selectedTool` are computed from it (`focusedCategory`, `selectedToolID`
already exist on the enum). Whoever owns `universeMode` owns navigation.
Recommended owner: `UniverseViewModel` (so model + view share one value and
the view stops holding a parallel copy). Detail/account/add-tool sheets derive
their booleans from `universeMode` instead of independent flags.

### State variables (single writer each)
| Variable | Type | Owner | Notes |
|---|---|---|---|
| `universeMode` | `UniverseMode` | model | the machine |
| `selectedCategory` | `ToolCategoryId` | derived | `universeMode.focusedCategory` |
| `selectedTool` | `String?` | derived | `universeMode.selectedToolID` |
| `isChatOpen` | `Bool` | derived | `if case .chatOpen` |
| `isDetailOpen` | `Bool` | derived | `if case .detail` |
| `isRailActive` | `Bool` | rail gesture | transient; not a mode |
| `isInputFocused` | `Bool` | `SearchDock` local | layout only |
| `attachmentState` | enum | `SearchDock` local | none/menu/attached |

## Allowed transitions
```
overview        → branchFocus(cat)         (tap/scroll into a category)
branchFocus     → toolSelected(cat, tool)  (tap a satellite)
toolSelected    → detail(cat, tool)        (tap again / open card)
any non-detail  → chatOpen(prevCtx)        (focus input / open chat)
chatOpen        → previous map mode         (dismiss chat)
any map mode    → railActive               (begin rail drag)  [transient]
railActive      → branchFocus(cat)          (release on a category)
detail          → previous map mode         (dismiss sheet)
```
`isInputFocused` is a secondary input state layered on the current map mode;
it must not replace `universeMode`.

## Forbidden (impossible) states — must be unrepresentable
- `detail` and `chat` both primary at once → they are distinct enum cases, so
  only one can be active. Sheets must derive from the case, not independent
  booleans that can both be true.
- Input focused causing a full-black/empty universe → input focus may dim
  *slightly* (atmospheric) but the map stays visible. Global dim/blur is a
  function of `universeMode` ONLY (`mapOpacity`, `mapBlurRadius`, `dimOpacity`).
- Rail active while keyboard layout is broken → entering `railActive` must
  resign first responder / not coexist with an open keyboard.
- Duplicated Add-tool / Attach-files controls → these actions live in exactly
  one place per state (see `INPUT_CHAT_SPEC.md`).
- Detail card showing a tool that is not the map-selected tool → the card
  reads `selectedTool` from the same machine the map renders from.

## Layering (primary overlay) rules
Exactly one *primary* overlay at a time, in this z-priority:
`detail` sheet > `chat` panel > tool anchor/labels > rail > map.
`detail` and `chat` are mutually exclusive primary overlays.

## Acceptance criteria (for the State Machine task)
- selected branch/tool consistent across map, bottom card, bottom chips, rail.
- focusing input does not black out the app.
- chat/detail mutually exclusive as primary overlays.
- no duplicate Add-tool / Attach-files due to state conflict.
- code compiles; tests green (xcresult `passedTests`).

## Implementation notes (append after refactor)
_(empty — fill in: what changed, which owner now holds `universeMode`, how the
view reads it, migration of the sheet booleans.)_

## Changed files / QA done / Remaining issues
_(empty)_
