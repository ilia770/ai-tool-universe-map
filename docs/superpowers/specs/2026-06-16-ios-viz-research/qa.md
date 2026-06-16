# QA / Tester — Bug Punch List

iOS "My AI Map" — read-only audit of UI/chat/gesture/label/reduce-motion behavior. Findings prioritized P0 (broken / user-reported) → P3 (polish). Every item is grounded in `file:line`.

---

## P0 — Reported broken, confirmed in code

### 1. Chat does NOT scroll to bottom on new message — ROOT CAUSE FOUND
`ChatDock.swift:76-81` and `ChatDock.swift:122-127` (UniverseScreen).

The scroll-to-bottom `onChange` exists and is wired correctly *in isolation*, but it can never fire on a fresh ask because of a **mount/visibility race**:

- `submit()` (`ChatDock.swift:213-227`) appends a turn, then sets `collapsed = false`.
- The `ScrollViewReader`/`ScrollView` only exists when `showThread` is true (`ChatDock.swift:31, 37-43`). `showThread = !collapsed && !thread.turns.isEmpty`.
- On the **first** ask, `thread.turns` goes empty→1 in the same tick the `ScrollView` first appears. The `.onChange(of: thread.turns.map(\.id))` (`:76`) is attached *inside* the just-created `ScrollViewReader`; SwiftUI does not deliver an `onChange` for a value that changed in the same render pass the view was inserted, so `scrollTo(last)` never runs. Subsequent asks land mid-list and the new turn renders below the fold.
- Compounding it: the answer + match cards for a turn render *after* layout, growing the row's height *after* `scrollTo` already ran, so even when `onChange` fires it anchors to a height that is then exceeded.

Fixes to verify: (a) move the scroll trigger to also run `.onAppear` of the `ScrollView`/last row and after an async hop (`Task { @MainActor in ... }` / `DispatchQueue.main.async`) so it runs post-layout; (b) anchor `scrollTo(last, anchor: .bottom)` on `thread.turns.count` AND on a layout-settled signal; (c) consider keeping the `ScrollView` mounted (hidden) so the reader is stable. Repro: open chat with empty thread, send first query → list stays at top.

### 2. ChatDock is removed from the tree the moment a tool opens — chat scroll/state churn
`UniverseScreen.swift:122-127` + `:17-19`.

`ChatDock` is only in the hierarchy when `!isPanelActive`, and `isPanelActive = sheetDetent != .height(118)`. Tapping any match card calls `model.focusTool` (`ChatDock.swift:239-245`) which does NOT expand the sheet by itself — but any later sheet drag past the peek detent unmounts `ChatDock` entirely, destroying `@State` (`text`, `collapsed`, `peekId`). Because `chatThread` is owned by `UniverseScreen` (`:9`) the turns survive, but the composer's draft text and scroll position are lost. Verify: type a half-finished query, drag the detail sheet up, drag back down → draft gone.

### 3. "Some buttons don't work" — dead buttons confirmed

- **Settings → History row is a no-op.** `SettingsSheet.swift:158-160`: button body only fires `BrandHaptics.fire(.light)`; comment at `:156-157` admits "History destination ships in a later product-v2 part." It renders a `chevron.right` (`:165`) implying navigation that never happens. User taps, feels a haptic, nothing opens → reads as broken.
- **ClarityMenu is referenced but never mounted.** `UniverseScreen.swift:114-119`: comment says it's hidden "until the renderer honors clarityMode." File exists (`UI/Sheets/ClarityMenu.swift`) but is dead. Confirm no stray entry point elsewhere.
- **Double-tap on a node is identical to single-tap.** `UniverseView.swift:299-308, 374-376`: `handleDoubleTap` just calls `handleTap`. The "fly-to" is implied by the comment but there's no distinct behavior; a user double-tapping expecting a zoom gets the same select. Not strictly broken but mismatches the documented intent.

---

## P1 — Gesture conflicts & high-impact jank

### 4. Empty-space double-tap-to-reset missing; tap gestures may swallow camera drag start
`UniverseView.swift:302-338`. Two `SpatialTapGesture` (count 2, count 1) are `.gesture` (high priority) while drag/pinch are `.simultaneousGesture`. A slow tap-drag on a node: the `targetedToAnyEntity` tap competes with the orbit `DragGesture(minimumDistance: 10)`. Verify on-device that starting a drag *on an orb* still orbits the camera rather than being eaten by the tap recognizer (likely it selects the tool AND orbits). Also confirm a quick double-tap on a node doesn't fire BOTH the double and single handlers (both call `onToolSelect`, so two haptics + redundant state set).

### 5. ChatDock swipe-down vs ScrollView scroll conflict
`ChatDock.swift:40-41, 249-269`. The thread `ScrollView` has `.gesture(dismissDrag)` (a `DragGesture(minimumDistance: 12)`) attached to the *same* view as the scroll content. A downward drag inside a scrollable thread will fight the scroll: SwiftUI gives `.gesture` priority over the scroll, so scrolling up-from-top or any downward pan risks collapsing the thread instead of scrolling. Should be `.simultaneousGesture` with a guard (only collapse when already at scroll-top), or move the drag to a drag-handle. Verify: scroll a long thread downward → it collapses unexpectedly.

### 6. Match-card long-press peek vs button tap race
`ChatDock.swift:147-153`. `PressableButtonStyle` (tap = open tool) plus `.onLongPressGesture(0.42s)` (peek). `onLongPressGesture` on a `Button` can cancel the button's tap or vice-versa; on slower presses the user may trigger neither cleanly. Same pattern works in `ToolDetailSection.swift:212-217` but there it's `.simultaneousGesture(LongPressGesture)` — inconsistent. Standardize and verify both peek and open fire reliably.

### 7. Related-tools long-press uses `nil` gesture ternary — fragile
`ToolDetailSection.swift:212-217`: `.simultaneousGesture(edge == nil ? nil : LongPressGesture...)`. Passing `nil` to `simultaneousGesture` is legal but the chip with `edge == nil` then has no long-press; ensure tap still works for both and the `nil` branch doesn't change hit-testing.

---

## P2 — Label sizing, materials, visual correctness (matches "looks terrible")

### 8. Category labels are GIGANTIC — world-space font size, no distance scaling
`UniverseView.swift:636, 695-703`. `labelFontSize = 0.8` is in **meters** (generateText sizes in world units, per the comment `:635`). At the overview camera distance these are huge slabs of extruded 3D text. There is NO billboard distance-scaling on category labels (unlike tool labels which at least fade). This is almost certainly the "text labels are GIGANTIC." Fix: shrink dramatically and/or add a distance-compensating scale so on-screen text size is constant.

### 9. No outline / stroke / darkened badge backing on labels (user explicitly asked)
`UniverseView.swift:653-674, 695-725`. Labels are bare `generateText` meshes with `UnlitMaterial` (white for tools `:662`, category color for categories `:705`). There is no stroke, no contrasting outline, no darkened plate behind the glyphs — so over bright orbs/stars they're illegible. User specifically requested "crisp outline/stroke + tidy darkened badge backing." Currently absent entirely.

### 10. Extruded 3D text reads as "crude/crooked"
`UniverseView.swift:654-661, 696-703`. `extrusionDepth: 0.01` 3D text billboarded toward camera shows its extruded sides at any non-head-on angle → crooked, chunky look. A flat textured quad / SwiftUI-rendered label texture would look crisp. Tie-in with #8/#9.

### 11. Connection lines barely visible / messy — confirmed
`UniverseView.swift:141-148, 166-173`. Tool→category links are `opacity: 0.22, thickness: 0.012`; inferred links `0.12–0.62`. These are thin `UnlitMaterial` boxes. The comment at `:134-140` admits links are **static** and do NOT follow pocket re-layout — so when a pocket opens, lines no longer reach their nodes (the "messy" report). Either redraw links on pocket open or hide intra-category links while pocketed.

### 12. Tool orbs look "crooked/crude"
`UniverseView.swift:727-750, 863-887`. Orbs are `generateSphere` with PBR; selected gets clearcoat. No mesh issue per se, but `emissiveIntensity` ramps (`:877-879`) plus the dim logic can make non-selected pocketed orbs near-black (`darken 0.85`, emissive `0.06` at `:870, :879`) → muddy. Verify orbs aren't washing out or going flat-black at overview distance.

### 13. Founder halo at radius 1.2 may visually swallow nearby category content
`UniverseView.swift:757, 779`. `founderHaloRadius = 1.2` with breathing ±0.06. Confirm it doesn't overlap the innermost orbit nodes as a translucent blob.

---

## P2 — Reduce-Motion gaps

### 14. Several animations bypass the reduce-motion gate
- `UniverseScreen.swift:185-187` `selectCategory` uses raw `withAnimation(BrandMotion.flow)` (NOT `BrandMotion.resolved`). Same at `:196-198` `focusToolFromMap`, `HistoryStrip.swift:106-108`, `PocketReadout.swift:18-20`, `SearchDock.swift:136, 145`, `ToolDetailSection.swift:331, 353`. These ignore `accessibilityReduceMotion`. `BrandMotion.resolved` exists precisely for this (`BrandMotion.swift:23-25`) and is used inconsistently (ChatDock/SettingsSheet do gate). A reduce-motion user still gets spring/smooth camera+UI animation.
- `RealityView` selection pulse / founder halo / shell breathing DO check `reduceMotion` (good), but the SwiftUI overlay layer is the gap.

### 15. `contentTransition(.opacity)` not gated
`ToolDetailSection.swift:75, 81`. Tool name/summary cross-fades have no reduce-motion guard.

---

## P3 — Edge / empty states & smaller bugs

### 16. ChatDock composer can be covered by keyboard
`ChatDock.swift:181-205`. The composer sits in a `GeometryReader` VStack pinned bottom (`:46`); on focus the keyboard rises. There's no explicit `.ignoresSafeArea(.keyboard)` management visible, and `UniverseScreen` embeds ChatDock inside a `VStack` over the canvas with `.padding(.bottom, 10)`. Verify the composer rides above the keyboard and the thread isn't clipped to a sliver when keyboard + 1/3-screen cap combine on small devices (SE).

### 17. Thread cap (1/3 screen) + keyboard on small screens
`ChatDock.swift:27, 39`. `maxThreadFraction = 1/3`. On iPhone SE with keyboard up, 1/3 of remaining height may be ~80pt — thread becomes unusable. Verify minimum usable height.

### 18. Match card resolves tool every render via linear scan
`ChatDock.swift:103`, `HistoryStrip.swift:13`, `SearchDock`/`ToolDetailSection` similar. `UniverseSeed.tools.first(where:)` is O(n) per card per render. With 49 tools × multiple turns it's cheap now but is repeated work on every scroll frame inside `ForEach` — watch for scroll jank on long threads. Not a correctness bug.

### 19. Search results card has no reduce-motion gate and uses `.move` transition
`SearchDock.swift:29-33`. `brandAnimation` IS reduce-motion-aware (good), but the inner `.transition(.move(edge:.top))` (`:30`) is not conditioned — confirm it's still acceptable under reduce-motion.

### 20. Settings reset confirmationDialog has no Cancel
`SettingsSheet.swift:39-48`. Only a destructive "Reset" button; relies on the implicit dialog dismiss. Compare to `ToolDetailSection.swift:294` which adds an explicit `.cancel`. Minor inconsistency; verify the reset dialog is dismissible.

### 21. Empty-state of ChatDock thread is unreachable dead code
`ChatDock.swift:59-60, 156-177`. `threadScroll` only renders when `showThread` (which requires `!thread.turns.isEmpty`), so the `if thread.turns.isEmpty { emptyState }` branch at `:59` can never execute. The example-query chips in `emptyState` (`:161-176`) are therefore never shown — likely a regression from the visibility gate. Verify the example queries are reachable (they appear to be orphaned).

### 22. iPad: ChatDock environment + always-visible panel
`UniverseScreen.swift:47-67, 122-127`. On regular width the detail is an always-visible side panel, but `isPanelActive` still gates ChatDock on `sheetDetent` which is iPhone-only state. On iPad `sheetDetent` never changes from `.height(118)` so `isPanelActive` is always false → ChatDock always shows even though the "panel is active" semantics differ. Verify ChatDock placement on iPad isn't fighting the side panel.

---

## Quick verification checklist (device)
1. Send first chat message from empty thread → must scroll to bottom (#1).
2. Send 5+ messages → newest fully visible, anchored bottom (#1).
3. Type draft, expand+collapse detail sheet → draft preserved? (#2).
4. Tap Settings → History → expect navigation, currently nothing (#3).
5. Scroll long chat thread downward → must NOT collapse (#5).
6. Long-press a match card → peek; tap → open. Both reliable? (#6).
7. Overview screen → category labels readable size, not giant slabs (#8).
8. Labels over bright orbs → legible with backing/outline? (currently no) (#9).
9. Open a pocket → connection lines still reach nodes? (currently no) (#11).
10. Enable Reduce Motion → category switch / camera focus should not spring (#14).
