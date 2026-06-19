# RIGHT_RAIL_SPEC

Owner: Codex. File: `Universe/RightUniverseRail.swift` (`UniverseRailView`) and
its mount in `UniverseOverlayView.swift`. Do NOT edit map rendering, chat, or
detail here. Selection state is READ from the machine; the rail only REQUESTS a
`branchFocus` transition (`UI_STATE_MACHINE.md`).

(Supersedes the prior Agent-3 version with the exact right-edge behavior from
the 2026-06-19 feedback.)

## Prime directive
**Edge-anchored, not a panel, not a screen-dimmer.** A thin right-edge
affordance to scrub categories via long-press + vertical drag. Never a wide
sliding panel, never a heavy dim, always in sync with chips/card/map.

## Inactive state
- **Pinned to the absolute right edge** — a slim column of dots/segments, one
  per category that has a planet (`railCategories` derived from `planets`, not
  all categories — already fixed for sparse universes).
- Current category dot highlighted. Minimal visible footprint; an invisible hit
  area may extend slightly inward for the long-press, but the VISUAL stays at
  the edge.
- Does NOT cover planets, does NOT dim the screen.

## Active / drag state (long-press + vertical drag)
- **Activation:** long-press (≈0.26s) THEN drag. A plain tap or a plain drag
  (no hold) does nothing to the rail and falls through to the map (the rail must
  not swallow map pan — the known gesture-arbitration bug; keep the inactive hit
  zone edge-thin).
- On activation: light haptic; resign keyboard (forbidden: rail + open keyboard).
- **Right-aligned text picker (NOT centered):** category labels align to the
  right edge line. The list floats over a **soft, light scrim** — not a heavy
  black-out (the "too transparent / wrongly dimmed" bug = wrong scrim; keep the
  universe readable behind it). No card/capsule panel behind the text.
- **Offset hierarchy, anchored to the right edge:**
  - selected/hovered item: **largest, strongest right offset** (furthest toward
    the edge / most prominent).
  - immediate neighbors: medium size, **less** offset.
  - far items: small, faded, least offset.
  - Reads as anchored to the right edge, fanning inward.
- **Drag:** finger up/down changes the hovered category; light haptic tick per
  crossing. Scrub must be smooth (fix the index mapping in `updateHover`).
- **Release:** fly-to the hovered category (`branchFocus` via the machine), rail
  collapses to inactive. Release without moving = no-op.

## Sync with selection
- Highlight READS `mode.focusedCategory`. Planet tap, bottom chip, and rail all
  converge on the same category → rail dot, bottom chip, detail card, map
  highlight identical. Rail writes only by requesting `branchFocus` on release.

## Accessibility
- Hold-then-drag isn't VoiceOver-operable → rail stays `accessibilityHidden`;
  `CategoryRail` (bottom chips) is the accessible control. If the rail becomes
  primary, add an `accessibilityAdjustableAction`.

## Acceptance criteria
- Inactive rail at the absolute right edge, dots only, no screen dim.
- A plain map drag near the right edge pans the map (rail doesn't eat it).
- Long-press → drag scrubs; right-aligned text; selected strongest right offset, neighbors less.
- Background behind active rail is a light scrim, universe still readable.
- Haptic tick per crossing; release flies to hovered category.
- Rail dot ⇄ bottom chip ⇄ detail card ⇄ map highlight always match.

## Manual QA
1. Inactive: dots pinned right edge, screen not dimmed.
2. Quick drag from right edge → map orbits (rail ignores it).
3. Long-press → hold → right-aligned picker, selected furthest right.
4. Drag up/down → haptic ticks, smooth; release → fly-to + collapse.
5. Switch via chip → rail dot updates; switch via rail → chip + card update.
