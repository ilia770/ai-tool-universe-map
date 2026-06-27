# COMPONENT AUDIT — token discipline + Dynamic Type

Source: 4 parallel read-only review agents over every UI component group
(2026-06-28). Standard enforced: `BrandSpacing` (4px grid, no inline magic
paddings), `BrandRadius` (no inline corner radii), `BrandTypography` (named,
Dynamic-Type-aware styles).

**Triage philosophy:** the screens already read cleanly at default text size
(verified by simulator captures). Most findings below are *internal* (magic
numbers) or *accessibility-scaling* (fixed `.system(size:)` fonts that don't
grow at large Dynamic Type). Blindly snapping tuned optical values to the 4px
grid risks regressing the glass look for invisible gains — so the padding/radius
grid-snap is queued as a **deliberate, value-preserving pass** (map each literal
to a token of the *same* value, or ≤1px), not a blind rewrite. The genuine
visible / accessibility wins are fixed immediately (see "Fixed" at bottom).

## A. Fixed-size fonts that ignore Dynamic Type (accessibility — real)
Content text that won't grow at large accessibility sizes (worst first):
- `AddToolSheet.swift:628-629` — name-requirement hint 10/11pt fixed (the only
  guidance on the Name field; invisible next to AX body text). **← fix now**
- `CategoryRail.swift:48` — category chip label `.system(size:12)` (primary nav
  filter; clips at large type). **← fix now**
- `BranchChip.swift:19` — `.system(size:12)` chip.
- `AccountSettingsSheet.swift:75` — close glyph `.system(size:13)`.
- `AddToolSheet.swift:288,375` — icon glyphs `.system(size:12/18)` (decorative,
  inside fixed frames — lower priority, frame anchors the tap target).
- `SearchDock.swift` 338/404/421/447/475/569/574/610/851/879 and
  `ChatScreen.swift` 250/324/330/348/517/571/659 — composer icon glyphs in
  fixed-frame buttons (decorative; frames keep 44pt targets).
- `UniverseGraphView.swift:986,991,1010,1048-1052` — graph node label/subtitle
  fixed sizes (capped by layout; lowest priority).

## B. Inline corner radii not in BrandRadius (value-preserving tokenize)
- `LiquidGlassSheet.swift:13` presentationCornerRadius 42
- `LiquidGlassCard.swift:14` default cornerRadius 28
- `ChatScreen.swift:357,359` starter card 14; `:440` user bubble 20
- `SearchDock.swift:367` attach popover 20; `:699,702` user bubble 19
- `SpatialRevealCard.swift:41` 26
- `UniverseOverlayView.swift:714` notice 20; `UniverseGraphView.swift:1017` label 9
→ Sibling inconsistency worth unifying: user bubble is 19 (SearchDock) vs 20
  (ChatScreen) — same element, different curvature. **← fix now via a token.**

## C. Off-grid magic-number paddings/spacings (queued grid-snap, value-preserving)
Recurring off-grid values and sites:
- `10`: LiquidGlassToast:20, LiquidGlassButton:26, ChatScreen:104/112,
  PlanetInfoCard:70, UniverseOverlayView:714/923 → candidate token `sm = 10`.
- `9`/`5`: ToolDetailSection badge 219/599; ToolAnchorBadge 922; ActionChip 12.
- `14`/`18`: PlanetInfoCard:69, SpatialRevealCard:39-40, ChatScreen:168-170.
- `6`/`7`/`3`: CategoryRail:36/42, SearchDock:314/362, ToolDetailSection:332.
- `RootSheet.swift:25-27`: 20/22/28 sheet wrapper insets.
- `RightUniverseRail.swift:25,289-311`: rowSpacing 31, font/row literals → extract
  a `UniverseRailMetrics` enum.

**Recommended approach for C (when scheduled):** add named tokens for the
recurring values (`BrandSpacing.sm = 10`, badge tokens) preserving pixels, then
replace literals — verify a screenshot diff per screen shows no movement.

## Fixed in this pass
(see commit) — A: AddTool hint + CategoryRail chip → Dynamic Type. B: user-bubble
radius unified via `BrandRadius.bubble`.
