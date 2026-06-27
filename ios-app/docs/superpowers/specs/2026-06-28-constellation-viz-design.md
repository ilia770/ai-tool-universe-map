# Constellation Map — new 2D/3D visualization (design)

Date: 2026-06-28. Status: approved by user, ready for implementation plan.

## Why

The current 2D map is a static radial **hub-and-spoke diagram**: tap = jump-cut
focus, edges are faint near-static curves, no entrance motion, no physics, no
sense of life. Even after the recent polish it still reads as "the same diagram
as before." The 3D scene is a static orbit.

Goal: **replace the metaphor** for both 2D and 3D with something that is
animated, interactive, and practical — where **connections appearing** is the
hero moment. The map's job (per product invariants) is to explain what each tool
is, its category, why it matters, and **what it connects to**. The new design
makes "what it connects to" the centerpiece.

## Metaphor: constellation + connection tracing

- Tools are **stars**. Categories are **constellations** (soft clusters with a
  faint outline). The core (Founder OS) is the brightest central star.
- The signature interaction: **tap a star → its connections trace out** (lines
  draw on, one by one, with a light pulse traveling along each) to related
  stars, which **pop in with a spring/bounce**; unrelated stars dim.

## Connection model (what a "connection" is)

The data has a `relationIds: [String]` field on `Tool` but it is **empty for
every tool** in the current seed. So connections are resolved in three layers:

1. **Derived base (instant, always available, offline):** from each tool's real
   `category` + workflow `stage`:
   - `alternative` — same stage + same category ("what could replace this").
   - `pipeline` — tools in the next workflow stage (Research → Plan → Build →
     Ship → Review) ("what comes after").
   - `constellation` — same-category siblings (weak background grouping = the
     constellation shape).
2. **AI layer (primary, the user's explicit requirement):** the assistant
   (existing DeepSeek backend) computes **semantic** relations for a tool
   ("alternative", "works with", "feeds into"), returns related tool ids, and
   they are **cached** (persisted) into `relationIds`. On focus, the derived base
   shows instantly; when the AI result arrives it upgrades to the brighter AI
   lines. Computed **lazily on first focus**, then served from cache.
3. **Curated override (future):** if `relationIds` are ever hand-filled, they
   render as the brightest lines on top.

Connections are **typed** (alternative / pipeline / constellation / ai); type
drives line color/weight and the relation chip label. Practicality: one tap
answers "what could replace this", "what comes next in my workflow", "who's in
the same group".

### Graceful degradation
No AI response (offline / error / timeout) → the derived base is the connection
set. The feature never blocks on the network.

## Visual

**Overview (resting):** star-field. Star size scales with importance (`orbit`).
Stars grouped into category constellations with soft cluster glow + a faint
outline. Core is the brightest, central. Gentle parallax + twinkle so it breathes
(not static). Label culling: only large stars + the focused set show labels
(never ~50 at once).

**Tap a star (hero):**
1. Camera smoothly centers the star (no jump-cut).
2. Connections **trace** — lines draw from the star to related stars (draw-on,
   ~0.4–0.6s, staggered one at a time), a light pulse travels each line.
3. Related stars **bounce in** (spring scale overshoot) and brighten + nudge
   closer; unrelated stars dim (focus + context).
4. Bottom card: what it is / why / pricing + **relation chips** tagged by type
   ("alternative", "after").

**Tap empty:** connections **reverse-draw** away; return to the field.

**Navigation (practical):** search (existing) → matched star highlights and
flies in; pinch-zoom into a constellation; a workflow-stage filter strip at the
bottom.

## Animation feel
- Reveal uses **spring/bounce** (overshoot), not linear ease: connected stars
  spring in, trace lines draw elastically, the focused star bounces slightly.
  Use the existing `BrandMotion.bounce` + `PressBounce`.
- **Reduce Motion → no bounce/trace animation; instant, static reveal.**

## Architecture

**Reused (unchanged):** `UniverseMode` state machine (overview / branchFocus /
toolSelected), selection, search, bottom cards, category + tool data.

**New units (each isolated, independently testable):**
1. `ConnectionResolver` (pure logic, no UI) — `connections(for: Tool) ->
   [Connection]` from derived rules + cached AI relations + curated overrides.
   Shared by 2D and 3D. Unit-tested.
2. `RelationAI` (async service) — queries the DeepSeek backend for semantic
   relations, validates ids against the catalog, caches to the store. Feeds the
   AI layer of the resolver.
3. `ConstellationLayout` (pure math) — deterministic star positions: per-category
   clusters, collision-resolved, fits the viewport. Replaces
   `UniverseGraphLayout`. Unit-tested (positions, no-overlap at SE/iPhone/iPad).
4. `ConstellationView` (2D) — SwiftUI Canvas + node buttons: star-field + the
   animated trace (draw-on + pulse + bounce). Replaces `UniverseGraphView`.
   Node buttons stay OUTSIDE the per-frame `TimelineView` (perf contract).
5. `ConstellationScene` (3D) — RealityKit: same stars/connections in depth, same
   resolver. Built last.

## Phasing (ship the feel cheaply before the expensive 3D work)
- **Phase 1 — 2D constellation:** `ConstellationLayout` + `ConstellationView` +
  `ConnectionResolver` (derived base only). Shippable, screenshot-verified. This
  is where the user confirms the new feel.
- **Phase 2 — AI relations:** `RelationAI` async + cache, wired into the resolver
  as the primary layer over the derived base.
- **Phase 3 — 3D port:** `ConstellationScene` reusing the resolver.

Each phase is its own implementation plan.

## Testing
- Pure units (`ConnectionResolver`, `ConstellationLayout`) → unit tests:
  connection types correct, derived fallback when AI cache empty, deterministic
  positions, no star overlap at SE/iPhone/iPad widths.
- Trace/visual → UI smoke screenshots via the existing `PolishCaptureTests`
  harness (overview, focused-with-traces, search-highlight).

## Risks & mitigations
- **3D RealityKit cost/fragility** → 3D is the last phase; 2D proves the concept.
- **AI latency/reliability** → instant derived base + cache + graceful fail.
- **Perf** (many stars + traces) → traces render only on focus; ambient layer is
  cheap; node buttons outside the per-frame timeline.
- **Disk/build fragility** (this Mac runs near-full) → incremental builds, keep
  DerivedData, prune `/tmp`, monitor disk.

## Guardrails / invariants
- 2D stays the **default** renderer; 3D stays opt-in (Settings).
- Progressive disclosure — never blanket the screen with labels.
- Accessibility: Reduce Motion → instant/no animation; Reduce Transparency →
  solid surfaces.
- Honor existing invariants (core is `tools[0]` founder-os; orbit ∈ {0..3};
  link confidence ∈ [0,1]).

## Out of scope (this design)
- Hand-curating a full relation set (the AI layer + derived base cover it).
- Multiplayer / sharing / persistence beyond the relation cache.
- Replacing the navigation state machine, search, or card content.
