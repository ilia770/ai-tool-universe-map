# iOS Viz Overhaul + App-Quality + Intelligence — Design

**Date:** 2026-06-16 (updated 2026-06-17) · **Branch:** feat/product-v2
**Direction:** A (Overlay-Native Universe, user-approved)
**Research:** `docs/superpowers/specs/2026-06-16-ios-viz-research/` (6 lenses + SYNTHESIS)
**Per-task specs:** `docs/superpowers/specs/2026-06-16-ios-viz-overhaul-tasks/`

## Goal

Make the iOS "My AI Map" a top-tier Apple app: a legible, premium cosmic universe that structures AI
tools and lets the user find the right one fast. Fix the "looks terrible" 3D map (giant 3D text, crude
orbs, invisible connections) and the app-quality bugs (chat scroll, dead buttons, black launch, missing +).
Add a Claude-backed intelligence layer that classifies, connects, and converses with real judgment.

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

### Render components (each one responsibility, testable)

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

## Intelligence layer (Claude API) — NEW

A single `IntelligenceService` backed by the Claude API gives the map real judgment instead of brittle
rules. **Key handling:** the user pastes their own Anthropic API key in Settings; it is stored in the
**Keychain** and never bundled (App Store-safe, no backend now). All calls degrade gracefully when no
key is set (offline rule fallback + a "add key for smart features" nudge).

Four jobs, each its own task + spec:

- `identifyTool(query | url)` → `{ category, description, pricing, killerFeatures, prosCons, whoUses,
  confidence }`. **Refuses to hallucinate:** when it cannot identify a service it returns a not-found
  result → UI says "couldn't identify — paste a link," never invents a fake tool.
- `inferConnections(tool, existingMap)` → **pinpoint** edges, each with a reason + confidence. Not
  blanket: a giant like Google does NOT connect to everything — only real relations (e.g. its Chrome
  extensions, its SDKs). Fixes the "posthog landed in social" class of error.
- `placeCategory(tool, categories)` → slot into the correct existing branch (posthog → analytics), or
  **propose a new, well-named category** when nothing fits — instead of forcing a wrong bucket.
- `chatCreate(prompt, map)` → conversational "I want to build X" → suggests a stack/tools and can add
  them to the map. This is the discoverable in-app assistant.

**Guards (discrete tasks):**
- Giant/ambiguous confirm: adding `instagram`, `google`, etc. triggers an "are you sure / which one?"
  step before committing.
- Unknown → ask-for-link instead of guessing.
- Low confidence → clarify with the user rather than silently mis-filing.

## App shell / top bar — NEW

- **Top bar:** remove the app title, the app icon, and the "Research → …" text. Replace with a single
  **account circle (avatar)** top-right. Tapping it opens the Account/Settings screen.
- **Account/Settings screen** contains:
  - **Visualization switcher** — A / K / N / O live preview.
  - **Language** — RU / EN.
  - **History (clickable)** — added/removed tools timeline; tapping an item opens that tool's window.
  - **Manage / delete tools** — list of user-added tools/skills with delete.
  - Account/profile, **Anthropic API key** field (Keychain), About.

## App-quality fixes (same pass)

1. **Chat scroll-to-bottom:** ChatDock auto-scrolls to the newest turn on send/answer (ScrollViewReader).
2. **Chat discoverability:** an obvious, persistent entry point to the assistant (the "ask / create"
   affordance) so the user can always find where to talk to it.
3. **Chat composer persistence:** composer stays reachable; when a tool sheet opens it yields gracefully
   (per the existing no-active-panel gate) instead of vanishing mid-conversation.
4. **Black cold-launch:** show a branded loading/empty state until the RealityKit scene + overlay are
   ready (no black frame).
5. **Dead buttons:** wire Settings→History tab (reuse `HistoryChipModel`/`history.events`); make
   double-tap distinct from single-tap; audit every tap target for a real action.
6. **"+" Add-Tool FAB:** liquid-glass circular FAB → AddToolSheet (intake intelligence already in code).

## Preserved (already in feat/product-v2)

Account/settings (RU/EN), history, tool delete, intake intelligence, pinpoint relationships + "connected
because", rich tool detail (killer features/pricing/pros-cons/who-uses), chat/QueryEngine. The
intelligence layer above upgrades the existing rule-based intake to Claude-backed judgment; this overhaul
is a render-layer replacement + shell redesign + intelligence upgrade + bug fixes on top.

## Task decomposition (each → its own MD in `…-tasks/`)

**Phase R — Render/viz:** projection · node-badge · connection-canvas · orb-layer · declutter ·
motion · viz-switcher.
**Phase A — App quality:** chat-scroll · chat-discoverability · composer-persistence · black-launch ·
dead-button-audit · add-tool-fab.
**Phase S — Shell:** top-bar-account-circle · account-settings-screen · language-ru-en ·
history-clickable · manage-delete-tools · keychain-api-key.
**Phase I — Intelligence:** intelligence-service-core · identify-tool · infer-connections ·
place-category · chat-create · guards.

## Testing

- Pure units tested headless: `UniverseProjection`, `DeclutterRule`, `UniverseMotion`, layout strategies
  per style, edge opacity math, `IntelligenceService` request/response mapping (mocked Claude).
- View behavior: ChatDock scroll, FAB presents sheet, settings switches style + persists, account circle
  opens settings, history tap opens tool, delete removes tool.
- Intelligence: identify refuses unknowns, connections stay pinpoint (no blanket giant links), category
  fallback proposes new category — all against recorded/mocked Claude responses.
- Gate: web npm (unchanged) + iOS xcodebuild on ClaudeGate. Swift 6.0 compat (no isolated-conformance).
- Visual quality verified by simulator screenshots (overview + pocket + each viz style + chat + settings).

## Out of scope

Web playground viz (already shipped); new seed data; production backend/proxy (user-paste key for now).
Three.js is web-only — not used on iOS.
