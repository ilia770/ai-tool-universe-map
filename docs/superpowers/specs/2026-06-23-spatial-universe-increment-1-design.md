# Spatial Universe — Increment 1: Spatial Spine (Design)

Date: 2026-06-23
Status: Design — awaiting user review
Scope: iOS app (`ios-app/`), `.spatial3D` render path only

## North star

A living galaxy of AI tools. Suns are categories, planets are tools, deep
silent space between. The camera flies; only what you look at speaks. Near-zero
noise until the user asks for depth.

Target emotion: "this feels like the future." References: Apple HIG, Linear,
Obsidian Graph View, Solar Walk 2, Arc Browser.

## Locked decisions

1. **Track A — evolve.** Rebuild the existing RealityKit scene incrementally
   toward the bar. The 2D graph (`renderMode == .graph2D`) stays the default and
   stays shippable; it is not touched by this work. The 3D path becomes default
   only when it clears the quality bar (a later decision, not this increment).
2. **Hybrid navigation.** Tap-to-fly is the spine (always recoverable); local
   free-orbit around the focused system; soft-snap to a neighbor sun when you
   drift toward it; tap empty space steps up one level.
3. **Galaxy of solar systems.** Each category is a sun (emissive sphere + a real
   scene light). Each tool is a planet orbiting its sun. Same underlying
   data — categories and tools are unchanged; only their spatial representation
   is restyled.

## Roadmap (this increment is #1 of 3)

- **Increment 1 — Spatial spine (this spec):** object-model reskin, hybrid
  camera/nav state machine, selected-only reveal, chrome cut to near-zero.
  Composition + camera + reveal only.
- **Increment 2 — Atmosphere & material:** deep-black skybox depth, volumetric
  light cast by suns, glass detail panel, parallax, premium materials.
- **Increment 3 — Motion & detail panel:** physical/instantaneous motion pass,
  the single selected-planet glass panel, minimal typography, negative space.

Each increment gets its own spec → plan → build cycle.

## Increment 1 — detailed design

### Object model (reskin, not rebuild)

- **Sun** = category body. Emissive sphere that also emits scene light. The 8
  categories become 8 suns — the galaxy.
- **Planet** = tool. A solid orbiting body (today's "satellite"), promoted to a
  first-class planet visual.
- **Overview shows only suns.** Tool-planets are hidden in overview and appear
  only after the user enters a sun. This keeps the overview silent (principles
  5 + 6).

Affected files (expected): `Universe/PlanetEntityFactory.swift` (sun vs planet
materials/emission), `Universe/UniverseSceneController.swift` (light per sun,
hide tool-planets in overview), `Universe/Entities/*` (body geometry).

### Camera / navigation state machine

Maps onto the existing `UniverseMode` cases — no new mode enum.

| State | Scene | Camera | Reveal |
| --- | --- | --- | --- |
| `overview` | all suns; tool-planets hidden | wide galaxy frame | only the centered sun speaks |
| `branchFocus` (sun focus) | one sun + its tool-planets orbiting; neighbor suns dimmed | fly + frame the system; **free-orbit enabled** | sun name only |
| `toolSelected` (tool focus) | one tool-planet framed + highlighted | fly + frame the planet | planet name + one-line teaser |
| `detail` | held | held | glass panel, full info |

Transitions:

- Tap empty space → step **up** one level (`toolSelected` → `branchFocus` →
  `overview`). The user is never trapped.
- While free-orbiting a sun, drifting toward a neighbor sun **soft-snaps** focus
  to that neighbor.
- Existing tap-to-fly framing in `CameraRigController` is reused; free-orbit and
  soft-snap are the new motion logic.

Affected files (expected): `Universe/CameraRigController.swift`,
`Universe/UniverseGestureController.swift`, `Universe/UniverseRealityView.swift`,
`Universe/UniverseMapView.swift` (transition wiring).

### Reveal & chrome cut (principle 6 — near-zero noise)

- **Labels:** only the focused sun and the focused tool-planet render a label.
  All distant bodies are silent (no label, dimmed). Tightens the existing
  `shouldShowLabel` logic in `UniverseOverlayView.swift`.
- **Overview:** only the centered sun shows a label (locked default — not "no
  labels at all").
- **Chrome in 3D:** hide the category rail and the bottom planet info card — the
  suns *are* the navigation. Keep exactly two pieces of chrome: the collapsed
  Ask-AI dock (locked default — it earns its place) and the selected glass
  panel.

Affected files (expected): `Universe/UniverseOverlayView.swift` (gate rail +
info card on `renderMode == .spatial3D`).

### Selection

The focused body (sun or tool-planet) gets an obvious highlight: scale bump +
glow + the only lit label. Reuses `mode.isPrimaryPlanet` / opacity modulation
already in `UniverseMode` and `UniverseSceneController`.

## Scope boundaries (hard)

- Only the `.spatial3D` render path changes. The 2D graph stays default and
  untouched.
- No new product features. No data-model change — suns and planets are the same
  categories and tools, restyled.
- Atmosphere/material polish (skybox, volumetric light quality, glass panel
  styling) is **Increment 2**, explicitly out of scope here.

## Success criteria

- Entering 3D shows a galaxy of silent suns that reads in ~5 seconds; what is
  tappable is obvious.
- Tap a sun → camera flies, the system blooms, you can free-orbit it.
- Tap a tool-planet → it frames + highlights; tap again → glass detail.
- Tapping empty space repeatedly walks back up to overview. Never stuck.
- Distant planets stay silent. Chrome is near-zero (Ask-AI dock + selected panel
  only).
- 2D graph behavior is unchanged; `npm run ios:verify` build + unit + UI-smoke
  stay green.

## Risks / open questions

- Free-orbit + soft-snap is the only genuinely new motion logic; needs care to
  stay "physical and expensive" without overshoot or motion sickness. Honor
  `accessibilityReduceMotion`.
- Promoting many tool-planets per sun could re-introduce noise inside a focused
  system; cap visible orbiting planets or scale by distance if it crowds.
