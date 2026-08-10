# LAYERING_AND_NAVIGATION_SPEC

> **Historical/mixed-state notice — 2026-07-16.** This document predates the
> current 2D renderer. Use `ARCHITECTURE.md`, `NAVIGATION_SPEC.md`,
> `INTERACTION_SPEC.md`, and `DESIGN_SYSTEM.md` as the current contract.

Z-order (layering) and navigation rules for the iOS app (SwiftUI, iOS 26).

Defines a single, strict stacking order for every floating element over the
map, and the navigation contract between the four primary destinations
(Map / Ask AI / Add Tool / Settings). It is implementation-pointed: it names
the real files and symbols that must enforce these rules.

---

## 1. Strict z-order (bottom → top)

Every overlay element must occupy exactly one of these layers. Lower numbers
render behind higher numbers. Nothing should sit ambiguously between two
layers or span them.

| # | Layer | What lives here |
| --- | --- | --- |
| 0 | **Background map / graph** | `UniverseGraphView` (2D) or `UniverseRealityView` (3D) in `UniverseMapView.universeStack`; plus the dim scrim `Color.black.opacity(mode.dimOpacity)`. Receives all map taps. |
| 1 | **Selected-object labels** | Planet/tool floating labels + leader lines in `UniverseOverlayView` (`labelLayer`, `toolAnchorLayer`, `toolLabelLayer`). Must be `.allowsHitTesting(false)` — they are read-only annotations. |
| 2 | **Selected-object card** | `PlanetInfoCard` (bottom card) and the iPad trailing `inspectorPanel`. |
| 3 | **Chat panel (if open)** | The `SearchDock` conversation panel / collapsed pill (`conversationPanel`, `collapsedConversationPill`). |
| 4 | **Attachment preview / menu** | `SearchDock.attachmentMenuPopover` + selected-attachment pill. Already `.zIndex(2)` *within* the dock; must stay above the transcript but below the input row's own affordances. |
| 5 | **Input dock** | The `SearchDock` composer row (`composerRow` / `composer`). Always reachable; never covered by the transcript or chips. |
| 6 | **Bottom chips / nav** | `CategoryRail` (bottom category chips) and the top `RootSurfaceSwitch` (Map / Ask-about-this pill) and `topChrome` (visualization control + account). |
| 7 | **Modal sheets** | `.sheet`-presented surfaces: `AddToolSheet`, `AccountSettingsSheet`, `RootSheet` (detail). These cover everything by definition. |

### Rules
- **R1 — Labels never intercept touches.** Every node in layer 1 keeps
  `.allowsHitTesting(false)` (already true in `UniverseOverlayView`). A map
  tap must reach layer 0.
- **R2 — One detail surface at a time.** On compact width, detail is the
  bottom `.sheet` (`RootSheet`); on regular width it is the trailing
  `inspectorPanel`. Never both. (Today `UniverseMapView` already branches on
  `isCompact`.)
- **R3 — Chat above card, below input.** When chat is open the conversation
  panel (layer 3) sits above the selected-object card (layer 2) but the
  composer (layer 5) is always the frontmost non-modal, non-chip element.
- **R4 — Sheets are terminal.** While any `.sheet` is up, the map and all
  overlays are non-interactive behind it (except the explicitly enabled
  detail `presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.72)))`).
- **R5 — No invisible interceptors.** No full-screen transparent view may sit
  above layer 0 with hit-testing enabled when chat is collapsed (see §3.4).
  The rail readability gradient in `UniverseOverlayView` is already correctly
  `.allowsHitTesting(false)` and constrained to a trailing strip — keep it so.

---

## 2. Navigation model: four destinations

The app has four primary destinations. The user must always be able to tell
which they are in and how to reach the others.

| Destination | Current entry point | Surface / presentation |
| --- | --- | --- |
| **Map** | `RootSurfaceSwitch` "Map" pill (`RootShell`) | `surface = .universe` (`UniverseScreen` → `UniverseMapView`) |
| **Ask AI** | `RootSurfaceSwitch` "Ask about this" (in universe) / default chat surface | `surface = .chat` (`ChatScreen`) |
| **Add Tool** | `presentAddTool()` from chat, overlay, or detail | `.sheet` → `AddToolSheet` |
| **Settings** | account avatar (`ChatTopBar`, `topChrome`, visualization control) | `.sheet` → `AccountSettingsSheet` |

### 2.1 Current switch behavior (RootShell)
- `RootShell` owns `@State surface: RootSurface` (`.chat` | `.universe`) and
  swaps between `ChatScreen` and `UniverseScreen` inside a `ZStack` with the
  `diveTransition`.
- The surface switch chrome (`RootSurfaceSwitch`) is pinned via
  `.safeAreaInset(edge: .top)`. In `.universe` it shows **Ask about this**
  (→ `askAboutSelection()` → `showChat()`) and a **Map** pill. In `.chat`
  only the Map pill shows.
- The Map pill is always enabled. Empty/low-tool maps are valid destinations
  and explain themselves through first-run / empty-state copy.

### 2.2 Gaps in current behavior
1. **Chat must keep its clear "back to map" control at the surface level.**
   From the `.chat` surface the Map pill is the always-enabled return path; do
   not reintroduce any tool-count gate.
2. **Two different "chat" concepts.** There is (a) the full `.chat` *surface*
   (`ChatScreen`) and (b) the in-map `SearchDock` chat panel with its own
   `conversationCollapsed` state. Collapse semantics differ between them,
   which is confusing: collapsing the in-map panel returns to the map, but
   the `.chat` surface has no equivalent collapse-to-map button.
3. **"Current destination" is not always obvious.** The switch only shows
   one or two pills; there is no persistent indicator of which of the four
   destinations is active.

---

## 3. Required behavior

### 3.1 Obvious switching between all four destinations
- The user can always reach Map, Ask AI, Add Tool, and Settings within one
  tap from the primary chrome. Map and Ask AI are surface toggles in
  `RootSurfaceSwitch`; Add Tool and Settings are sheets reachable from both
  surfaces (chat: `ChatTopBar` + composer; map: `topChrome` + composer).
- The active destination must be visually distinct (selected/filled state in
  the switch). From `.chat`, the chat side reads as selected; from
  `.universe`, the Map pill reads as selected.

### 3.2 Map reachable from chat without the 3-tool trap
- The Map pill must **not** be the only return path while disabled. Either:
  - (a) make the Map pill always enabled (an empty/low-tool map shows the
    empty-state card per FIRST_RUN_SPEC), keeping any "add more tools for a
    richer map" idea as messaging, not a hard lock; **or**
  - (b) add an always-enabled "Map" / back control so the user can leave
    chat at any time.
- Recommended: (a). The empty map is a valid, informative destination.

### 3.3 Chat must have a clear collapse button that returns to the map
- The in-map `SearchDock` already has a correct collapse affordance: the
  `conversationHeader` chevron-down (accessibilityLabel "Collapse chat",
  sets `conversationCollapsed = true`) and the `collapsedConversationPill`
  ("Show chat", chevron-up) to reopen. Keep this.
- The full `.chat` **surface** must gain an equally clear, single control
  that returns to the map: a labelled back/collapse button in `ChatTopBar`
  (or the surface switch) that calls `showUniverse()`. It must:
  - be always visible and always enabled (never gated by tool count);
  - land cleanly on the map surface (no half-state — see R-collapse below);
  - use a clear glyph + accessibility label (e.g. "Back to map").

### 3.4 No broken half-state; reopening chat works
- **R-collapse:** Collapsing/closing chat must end in exactly one stable
  state: either the map surface (chat surface dismissed) or the collapsed
  in-map pill. There must be no intermediate where the composer is gone, the
  transcript is gone, but a transparent layer still intercepts map taps.
- The existing `SearchDock.onChange(of: isChatOpen)` resets `fieldFocused`,
  `attachmentMenuOpen`, and `conversationCollapsed = true` when chat closes.
  The collapsed "Show chat" pill may remain visible as a small affordance, but
  it must not keep `UniverseMode.chatOpen` active or block map gestures.
- **Reopening:** from the collapsed pill ("Show chat") or by returning to the
  `.chat` surface, the previous transcript must still be present
  (`model.assistantMessages` is the single source of truth and is not cleared
  on collapse). Verify reopen restores scroll-to-latest.
- **No invisible interceptor (R5):** when chat is collapsed on the map, no
  full-screen hit-testing view may remain. Audit any overlay added for chat
  to ensure it is removed or `.allowsHitTesting(false)` when
  `!showsConversation`. Map empty-space taps (`handleEmptySpaceTap` in
  `UniverseMapView`) must reach the map and, when chat is open, close it via
  `restoreNavigationMode`.

### 3.5 Current state always visually obvious
- The primary chrome must always communicate the active destination: filled
  vs outline pill in `RootSurfaceSwitch`, and the chat surface must look
  distinct from the map surface (it already uses `ChatTheme.background` vs the
  map's black). Keep a persistent, legible "where am I" cue.

---

## 4. Affected files

- `Sources/MyAIMap/RootShell.swift` — owns `surface`, `RootSurfaceSwitch`,
  the chat⇄universe transition, and the Add Tool / Account sheets. Enforce
  §3.1 (active-state styling), §3.2 (un-gate or add an always-enabled Map
  return), and host the surface-level collapse/back control for §3.3.
- `Sources/MyAIMap/UI/Search/ChatScreen.swift` — `ChatTopBar` must gain the
  always-visible "Back to map" control (§3.3); ChatScreen embeds the
  `SearchDock` composer (layer 5).
- `Sources/MyAIMap/UI/Search/SearchDock.swift` — owns the in-map chat panel,
  collapse header (`conversationHeader` chevron-down), `collapsedConversationPill`,
  attachment menu (layer 4), and composer (layer 5). Enforce the chat/dock
  internal z-order (R3) and the `onChange(of: isChatOpen)` reset (§3.4).
- `Sources/MyAIMap/Universe/UniverseMapView.swift` — `universeStack` defines
  layers 0–6 over the map; `handleEmptySpaceTap` / `setChatOpen` /
  `restoreNavigationMode` govern map-tap routing when chat is open (§3.4, R5).
- `Sources/MyAIMap/Universe/UniverseOverlayView.swift` — labels (layer 1,
  `allowsHitTesting(false)`), `PlanetInfoCard` (layer 2), rail + chrome
  (layer 6), rail readability gradient (must stay `allowsHitTesting(false)`,
  R5).
- `Sources/MyAIMap/docs/UI_STATE_MACHINE.md` — `UniverseMode` is the single
  source of truth for map navigation (overview/branchFocus/toolSelected/
  detail/chatOpen); keep layering decisions consistent with it.

---

## 5. Acceptance criteria

1. **Strict z-order holds.** In every state (overview, tool selected, chat
   open, attachment menu open, sheet up), each floating element renders in its
   assigned layer; no element overlaps a higher layer it should sit behind.
2. **Labels never block the map.** Tapping on or near a floating label hits
   the map node/empty space beneath it, not the label.
3. **Four destinations, one tap each.** From any non-modal state the user can
   reach Map, Ask AI, Add Tool, and Settings in a single tap, and the active
   destination is visually obvious.
4. **No 3-tool trap.** From the chat surface the user can return to the map at
   any time, regardless of tool count.
5. **Clear chat collapse.** The chat (both the in-map panel and the chat
   surface) has an obvious, labelled control that returns to the map and lands
   in a clean, fully-interactive map state.
6. **Reopen works.** After collapsing/closing chat and reopening it, the prior
   conversation is intact and scrolled to the latest turn.
7. **No invisible interceptor.** With chat collapsed, tapping anywhere on the
   map interacts with the map (selects/deselects nodes, pans) — no dead taps
   caused by a leftover transparent overlay.
8. **Sheets are terminal & dismiss cleanly.** Opening Add Tool or Settings
   covers the map; dismissing returns to the exact prior surface and state
   (no residual dim, no stranded selection).

---

## 6. Implementation update - 2026-06-22

The current stabilization pass keeps the map-first launch from
`FIRST_RUN_SPEC.md` and adds the missing Liquid Glass navigation continuity:

- `RootShell.RootSurfaceSwitch` uses shared morph IDs for the Map / Ask AI
  route controls and the selected-tool context chip, with neutral glass styling.
- `UniverseOverlayView.topChrome` wraps the mode pill and profile button in one
  glass container so the top navigation layer behaves like a single control
  surface.
- `SearchDock` gives the Collapse Chat and Show Chat affordances a shared morph
  identity and keeps the transcript resumable.
- `ComposerLogic.keepsChatActive` no longer treats
  `isCollapsedWithContent == true` as an active chat state. Collapsed chat keeps
  the transcript resumable through the small "Show chat" pill, but releases the
  map from `UniverseMode.chatOpen`, so map taps and pans are not blocked by an
  invisible chat layer.
- `AddToolSheet` and `AccountSettingsSheet` toolbar actions use matching glass
  chrome, preserving the same navigation language in modal states.

Verification on 2026-06-22:

- `MyAIMapTests/ComposerLogicTests`: 25 passed, 0 failed.
- `bash scripts/ios-verify.sh --run-tests --device-id
  EAC2C682-5C38-44DB-8FEC-034E296E8EEA`: 263 passed in 32 suites, 0 failed.
- `MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates`: 1 passed, 0
  failed.
