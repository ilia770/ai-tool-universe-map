# LIQUID_GLASS_VISUAL_SPEC

Owner domain: the shared visual language for all floating UI chrome — the
Apple "Liquid Glass" direction across the app. This spec defines the five
canonical component styles (card, button, chip, floating panel, input) and
maps each to the existing `glassSurface` helper + Brand tokens. It is a
visual-standardization spec, not a behavior spec.

Files in scope (visual treatment only):
`UI/Effects/LiquidGlass.swift`, `UI/Theme/Brand*.swift`,
`UI/Search/SearchDock.swift`, plus any view that paints a card / button /
chip / floating panel / input surface. Behavior, layout logic, and copy stay
with each feature's own spec (e.g. `CHAT_AI_SPEC.md`, `INPUT_CHAT_SPEC.md`,
`CHAT_INPUT_SPEC.md`, `DETAIL_SCREEN_SPEC.md`, `RIGHT_RAIL_SPEC.md`).

Cross-refs: `CHAT_INPUT_SPEC.md` (input dock + attachments, applies the
"input" style below), `CHAT_AI_SPEC.md` (assistant message content + copy
feedback).

---

## Prime directive

Apple Liquid Glass. The interface is **mostly black / white / gray**. Color
is an accent reserved for **active state and tiny highlights only** — a
selected chip, a send affordance, a focused field's caret/tint, a status dot.
Color is never a surface fill.

Five rules, applied everywhere:

1. **No solid color panels.** No strong filled cyan / blue / green / violet /
   pink / teal panels anywhere in the main flow. Surfaces are translucent
   material + blur (glass) or near-neutral solid (`glassSolid` / white-alpha),
   never a saturated brand fill.
2. **Translucent material, not paint.** Floating chrome uses
   `glassSurface(...)` (system glass / `.ultraThinMaterial`). Reading surfaces
   use neutral `glassSolid` or low-alpha white. Tint, if any, is a *whisper*
   (≤ ~0.12 alpha) passed to glass, not a `Color.fill(0.30)` background.
3. **Soft edges + depth.** A floating component reads through: background blur
   + subtle gradient transparency + a very soft border/highlight (hairline,
   `BrandColor.stroke`) + one soft shadow. The system owns the glass edge on
   iOS 26 — do not add a manual stroke on top of native glass.
4. **Content is layered, not boxed.** Prefer one floating surface with clear
   internal spacing over many nested bordered boxes. Avoid box-in-box-in-box.
5. **No visual noise.** One shadow per floating layer, one hairline, no
   competing glows, no double-lensing (never nest `glassSurface` inside
   `glassSurface`).

This restates and tightens the existing HIG contract in
`LiquidGlass.swift`: *glass belongs to the floating navigation/control layer;
content (bubbles, cards, sheet bodies, backgrounds) stays solid/material.*
The correction this spec adds: content surfaces must be **neutral** solid, not
**accent-tinted** solid.

---

## Token vocabulary (the only allowed inputs)

Surfaces:
- `BrandColor.void` — app background behind the canvas.
- `BrandColor.glass` / `BrandColor.glassSolid` — neutral glass backing /
  Reduce-Transparency + reading-surface fill.
- `BrandColor.card` (`white 0.06`), `BrandColor.muted` (`white 0.035`) —
  neutral low-alpha content fills.
- `BrandColor.stroke` (`white 0.10`), `BrandColor.strokeStrong` (`white 0.18`)
  — the only borders.

Text: `textPrimary` / `textSecondary` / `textMuted`.

Accent: `model.selectedCategoryModel.color` (or `BrandColor.core`) — **active
state and tiny highlights only**.

Radii: `BrandRadius.glassControl` (22, composer), `.glassButton` (16),
`.card` (18), `.nested` (12), `.node` (8), `.pill` (999).

Spacing: `BrandSpacing.*` (4-pt base grid; the named `sm=10` token is the only
compact-control exception). Motion: `BrandMotion.*`.

Helper: `glassSurface(in:tint:interactive:)` — the single entry point. `tint`
is optional and must stay ≤ ~0.12 alpha when used.

---

## The five canonical styles

### 1. Card (content surface — reading, not chrome)

Examples: tool detail card, chat transcript panel, assistant tool-summary
table, settings rows.

- Background: `BrandColor.glassSolid` (or `BrandColor.card` over the canvas)
  in a `RoundedRectangle(cornerRadius: BrandRadius.card.value, .continuous)`.
- Border: one hairline `BrandColor.stroke` (0.5pt). Never accent-colored.
- Depth: one soft shadow, `black.opacity(0.30–0.34)`, radius ~16, y ~8.
- **Not glass** (it is content), and **never accent-tinted**.
- Accent appears only as a tiny inline highlight: a category dot, a label
  color on one word — not the card fill.

### 2. Button (floating control — chrome)

Two variants:

- **Glass icon button** (collapse, header chips, secondary actions):
  `glassSurface(in: Circle()/RoundedRectangle(BrandRadius.glassButton),
  interactive: true)`, no manual stroke on iOS 26, glyph in
  `textSecondary`/`white`. Tint omitted or ≤ 0.12.
- **Primary action button** (Send, Add tool): the one place a solid accent
  fill is allowed, because it *is* the active affordance — a filled
  `Circle()` in the category accent with a `black`-on-accent glyph, hairline
  `white 0.18` overlay, and a soft accent shadow. Disabled state drops to
  neutral `white 0.08` fill + `white 0.34` glyph (no color).

Press feedback: `GlassControlButtonStyle`. Native interactive glass owns the
visual response on iOS 26; iOS 18–25 falls back to a restrained 0.97 scale and
0.90 opacity response. Reduce Motion and `-uitestStatic` suppress scaling and
native interactive-glass motion. Haptics have one owner per control.

### 3. Chip (small selectable token)

Examples: category chips, inline action chips, attachment pill.

- Idle: neutral `BrandColor.muted` / `white 0.05–0.08` fill in a `Capsule()`,
  hairline `stroke`, `textSecondary` label.
- Active/selected: bump fill to `white 0.12` **or** apply a *whisper* accent
  (≤ 0.12) — and color the label/icon with the accent. The accent lives on the
  text/icon and the subtle highlight, not as a saturated capsule fill.
- Never a `accent.opacity(0.24–0.30)` capsule (that is the current
  over-filled pattern — see Corrections).
- Shared inline chips use `BrandColor.card` + `BrandColor.stroke`, horizontal
  padding `BrandSpacing.m`, vertical padding `BrandSpacing.s`, and a 44pt
  minimum hit target. `ToolChip` reuses this chrome and keeps category color
  on its logo only.

### 4. Floating panel (transient chrome over content)

Examples: attachment menu popover, any menu/HUD that floats above the input.

- Background: `glassSurface(in: RoundedRectangle(BrandRadius.nested/.card),
  interactive: true)` — translucent + blurred so the content behind shows
  through. Optional ≤ 0.12 tint; otherwise neutral.
- Depth: one soft shadow (`black 0.30–0.34`, radius ~16, y ~8) to lift it off
  the layer below.
- No accent-tinted backing plate, no second border. Internal items are neutral
  rows that highlight on selection (style 3).

### 5. Input (the composer field — chrome)

Examples: the Ask AI Universe composer.

- A single `glassSurface(in: Capsule(), interactive: true)` capsule. **No**
  accent `tint`. **No** extra `black.opacity` backing plate behind the glass.
- One soft shadow for float (`black ~0.26`, radius ~14, y ~8).
- Accent appears only as the text `tint` (caret/selection) while focused —
  never as the capsule fill or border.
- Full treatment + states live in `CHAT_INPUT_SPEC.md`.

---

## Current state → required (corrections to remove over-color / over-fill)

These are the concrete spots in `UI/Search/SearchDock.swift` (the most
glass-dense surface, and the reference implementation for the styles above)
that violate the direction today. Each must move from a saturated/heavy fill
to the corrected neutral-glass treatment.

| # | Where (file:symbol) | Current (over-colored / over-filled) | Required (corrected) |
|---|---|---|---|
| C1 | `composer` (`SearchDock.swift` ~L214–220) | `glassSurface(tint: accent.opacity(0.5))` **plus** a `black.opacity(0.12)` backing capsule behind it | Input style 5: `glassSurface(in: Capsule(), interactive: true)` with **no tint** and **no black backing**; accent only as the field's text `tint`. (Detailed in `CHAT_INPUT_SPEC.md`.) |
| C2 | `userBubbleContent` (~L530–545) | User bubble filled `accent.opacity(0.30)` | Neutral content surface: `white 0.06–0.08` fill (or `glassSolid`) + hairline `stroke`. No accent fill on the bubble. Speaker is conveyed by alignment + neutral tone, not a colored panel. |
| C3 | `attachmentMenuPopover` (~L272–281) | `black.opacity(0.30)` backing plate **under** a `glassSurface(tint: accent.opacity(0.34))` | Floating-panel style 4: single `glassSurface(interactive: true)`, **no** black backing plate, tint dropped or ≤ 0.12. |
| C4 | `attachmentPill` (~L365–368) | `accent.opacity(0.28)` capsule fill | Chip style 3: neutral `white 0.08` capsule + hairline; accent only on the icon/label. (See `CHAT_INPUT_SPEC.md` for the floating-preview replacement.) |
| C5 | `attachmentMenuItem` selected (~L302) | `white 0.12` selected / `0.055` idle — acceptable; keep, but selected may instead carry a ≤ 0.12 accent *highlight* on the label only | Keep neutral; if signalling selection, color the label/icon, not a heavier plate. |
| C6 | `toolAccessButton` / `missingToolButton` chips (~L680, ~L715) | `accent.opacity(0.24–0.30)` capsule fills | Chip style 3: neutral capsule + hairline; accent on icon/label only. |
| C7 | `tableHeader` / `tableRow` (~L601, L633) | `white 0.045` over `black 0.42` table — neutral, acceptable | Keep. Ensure it reads as one card (style 1), not nested boxes; single hairline around the whole table. |
| C8 | `resultRow` dot glow (~L751–754) | category dot + soft glow — this is the *correct* use of accent (tiny highlight) | Keep as the reference for "accent = tiny highlight". |

General sweep beyond SearchDock (apply same rule): any surface using
`someAccent.opacity(0.2–0.5)` as a `.background(...)` fill is a violation —
replace with neutral glass/solid + hairline, and move the accent onto an
icon, label word, dot, or ≤ 0.12 glass tint.

---

## Acceptance criteria

A build satisfies this spec when **all** hold in the main flow (universe map,
chat dock, attachment menu, tool cards):

1. **No heavy colored filled panels remain.** No surface uses a brand/category
   color at > ~0.12 alpha as a background fill. (Grep aid: search for
   `.opacity(0.` on `.background(` lines carrying a category/brand color and
   confirm each is ≤ 0.12 or converted to neutral.)
2. **Input has clean Apple-like glass:** the composer is a single glass capsule
   with no accent tint, no black backing plate, and no strange glowing outline;
   accent shows only as the focused caret tint.
3. **Floating components** (composer, attachment menu, header buttons, collapsed
   pill) each read as: background blur + subtle gradient transparency + one soft
   hairline/highlight + one soft shadow. No double-lensing, no second border.
4. **Content surfaces** (chat bubbles, transcript, tables, cards) are neutral
   (`glassSolid` / white-alpha) with a single hairline — never accent-tinted.
5. **Accent is active-state / tiny-highlight only:** send button (active),
   focused field tint, selected-chip label/icon, status dots. Removing all
   accent would leave a coherent black/white/gray interface with no broken
   "missing fill" boxes.
6. Reduce Transparency still yields legible opaque surfaces via the existing
   `glassSurface` fallback; Reduce Motion respected via `BrandMotion`.

---

## Out of scope

- Component behavior, layout logic, focus/keyboard handling, copy.
- Backend / assistant answer content (`CHAT_AI_SPEC.md`).
- The 2D/3D universe rendering material (separate visualization spec).

## Implementation note — map slice 2026-07-15

The first 2D-first map slice applied this spec inside the Universe Map domain:
`PlanetInfoCard` no longer uses raw `.ultraThinMaterial` plus category-colored
stroke/fill; it now routes through `glassSurface`, neutral chip fill, token
spacing, and capped accent highlights. Constellation nodes are graph content,
so they deliberately use neutral solid fills, restrained category overlays,
and hairline rings rather than Liquid Glass. Native glass stays on floating
navigation/input chrome.

## Changed files / QA done / Remaining issues — DS.1 2026-07-15

### Changed files

- `UI/Theme/BrandMotion.swift` centralizes Reduce Motion and `-uitestStatic`
  resolution for animations and press scale.
- `UI/Effects/PressBounce.swift` adds the native-aware
  `GlassControlButtonStyle` fallback policy.
- `UI/Effects/LiquidGlass.swift` suppresses native interactive-glass motion
  when motion is disabled.
- Shared glass/chip primitives now use token spacing, neutral tint/fills, and
  44pt minimum targets where the primitive owns the target.
- `BrandTokensTests.swift` and `HitAreaTests.swift` cover the shared policy.

### QA done

- `git diff --check` passed.
- `bash scripts/ios-verify.sh --test-build-only` passed after each review fix;
  final result: `** TEST BUILD SUCCEEDED **`.
- Independent spec review: `SPEC APPROVED`.
- Independent code-quality review: `CODE QUALITY APPROVED`.

### Remaining issues

- CoreSimulator recovery is complete on `AIMapGate`; a clean app-only product
  now installs and launches. DS.0 still needs SE/iPad and non-overview captures.
- Raw materials, off-grid spacing, saturated accents, and sub-44pt controls in
  feature surfaces remain assigned to DS.3–DS.8.
- Final branch/tool node hierarchy and bounce strength remain
  `NEED USER'S EYE` in DS.2.

## Changed files / QA done / Remaining issues — DS.2 overview 2026-07-15

### Changed files

- `UniverseConstellationView.swift` puts branch names inside their node
  footprints, removes overlapping caption capsules, and treats graph nodes as
  solid content rather than glass chrome.
- `GlassMorphCluster.swift` applies native glass to the selected padded label
  itself, preserving label sharpness and the travelling morph identity.
- `RootShell.swift` gives each route option an explicit selected/unselected
  foreground style inside the glass hierarchy.
- `UniverseConstellationLayoutTests.swift` guards pairwise overview footprints
  against overlap at the iPhone reference size.

### QA done

- Generic app-only simulator build: `BUILD SUCCEEDED`.
- Bundle audit: 26 MB, `arm64 + x86_64`, valid deep signature, no `.xctest`,
  `XCTest.framework`, or `XCUIAutomation.framework` payload.
- `AIMapGate` install + launch succeeded; stable iPhone 16 Pro overview confirms
  eight readable branch nodes and a sharp active Map glass segment.
- Focused Swift Testing suite: 5 tests passed, `TEST SUCCEEDED`.

### Remaining issues

- Capture branch focus and selected-tool states before closing DS.2.
- Tune bounce only with a live non-static run; final strength remains a visual
  judgement rather than a blind constant change.
- Complete DS.0 on SE-class and iPad layouts before claiming responsive parity.
