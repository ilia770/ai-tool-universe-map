# iOS Viz Overhaul + App-Quality — Design

**Date:** 2026-06-16 · **Branch:** feat/product-v2 · **Direction:** A (Overlay-Native Universe, user-approved)
**Research:** `docs/superpowers/specs/2026-06-16-ios-viz-research/` (6 lenses + SYNTHESIS)

## Goal

Make the iOS "My AI Map" a top-tier Apple app: a legible, premium cosmic universe that structures AI
tools and lets the user find the right one fast. Fix the "looks terrible" 3D map (giant 3D text, crude
orbs, invisible connections) and the app-quality bugs (chat scroll, dead buttons, black launch, missing +).

## Root cause (why it looks broken)

The map renders an information graph inside a world-space 3D engine: labels are extruded 3D meshes sized
in **meters** (no badge, no stroke, balloon on zoom), connection lines are world-thickness boxes
(sub-pixel at distance, detach from nodes when a pocket opens), orbs are dark untessellated lumps that
snap instead of ease. Legibility cannot be fixed inside that model — it must move to screen space.

## Architecture — Overlay-Native Universe

Two cooperating layers:

1. **RealityKit backdrop (ambient only):** starfield, nebula depth, subtle parallax/drift tied to the
   camera. No tool text / lines / orbs in world space anymore. Keeps the volumetric "space" brand feel.
2. **Screen-space overlay (SwiftUI + Canvas):** draws orbs, connection edges, and labels. Node world
   positions (from the existing `UniverseLayout` math) are projected to screen points; camera
   orbit/zoom drives a parallax transform so the overlay still reads as 3D depth. This layer owns all
   legibility.

### Components (each one responsibility, testable)

- `UniverseProjection` (pure): maps a node's 3D layout position + camera state → 2D screen point + depth
  scale + parallax offset. Unit-tested (no RealityKit).
- `NodeBadge` (SwiftUI view): fixed-size **glass pill** — dark translucent plate, 1px stroke/outline,
  subtle glow, Dynamic Type label, optional brand icon. Readable over any background. Press 0.96 + haptic.
- `ConnectionCanvas` (Canvas): anti-aliased edges between projected node points; opacity by
  depth × relationship confidence; always attached to live node points (fixes pocket detach). Tappable
  edge → reason ("connected because").
- `OrbLayer`: light glowing discs (radial-gradient core + halo aura), size hierarchy core > category >
  tool, single palette from the category color system. Eased entrance/scale.
- `DeclutterRule` (pure): overview shows category badges + hub nodes only; opening a pocket reveals that
  category's tool badges; distance-fade for the rest. Unit-tested.
- `UniverseMotion`: ease-out-expo, frame-rate-independent (1−exp(−k·dt)); honors Reduce Motion.

### Visualization switcher (settings)

`VisualizationStyle` (stubbed in P1) becomes a real switcher over **our finalist layouts**, all rendered
through the overlay engine (layout differs, render path shared):
- **A** Connected Mind (force-directed graph) — default
- **K** Bloom (progressive reveal)
- **N** 3D Force (true orbit/parallax depth) — **explicitly included**
- **O** Neural Universe (hero hybrid)

Each style = a layout strategy feeding `UniverseProjection`. Settings → Visualization picker switches live
(persisted via `AppSettings`). Galaxy/legacy retained as a fallback option.

## App-quality fixes (same pass)

1. **Chat scroll-to-bottom:** ChatDock auto-scrolls to the newest turn on send/answer (ScrollViewReader).
2. **Chat composer persistence:** composer stays reachable; when a tool sheet opens it yields gracefully
   (per the existing no-active-panel gate) instead of vanishing mid-conversation.
3. **Black cold-launch:** show a branded loading/empty state until the RealityKit scene + overlay are
   ready (no black frame).
4. **Dead buttons:** wire Settings→History tab (reuse `HistoryChipModel`/`history.events`); make
   double-tap distinct from single-tap; audit every tap target for a real action.
5. **"+" Add-Tool FAB:** liquid-glass circular FAB → AddToolSheet (intake intelligence already in code).

## Preserved (already in feat/product-v2)

Account/settings (RU/EN), history, tool delete, intake intelligence (posthog→analytics,
not-found→ask-for-link, confirm-giants, dynamic categories), pinpoint relationships + "connected
because", rich tool detail (killer features/pricing/pros-cons/who-uses), chat/QueryEngine (depth fix is
a separate in-flight task). This overhaul is a render-layer replacement + bug fixes on top.

## Testing

- Pure units tested headless: `UniverseProjection`, `DeclutterRule`, `UniverseMotion`, layout strategies
  per style, edge opacity math.
- View behavior: ChatDock scroll, FAB presents sheet, settings switches style + persists.
- Gate: web npm (unchanged) + iOS xcodebuild on ClaudeGate. Swift 6.0 compat (no isolated-conformance).
- Visual quality verified by simulator screenshots (overview + pocket + each viz style + chat).

## Out of scope

Web playground viz (already shipped); new tools/data; backend. Three.js is web-only — not used on iOS.
