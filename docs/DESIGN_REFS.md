# Design references

Sources we are deliberately cribbing from. Each entry lists what we
want to import into either the existing web app or the upcoming
SwiftUI port — never both blindly.

## Obsidian 3D graph renderer (April 2026)

D'Arcy Norman's experimental 3D graph for Obsidian — Three.js + WebGL
routed through Metal on macOS — is the closest analog to where we want
to go visually.

- **Force-directed layout**: `d3-force-3d` simulation inside the
  animation loop. Nodes self-organise instead of sitting on a
  hand-tuned orbit. Today our pockets use a Fibonacci-sphere
  distribution; a force step would let related tools cluster.
- **Instanced rendering**: one GPU draw call regardless of vault
  size. Worth importing for our `ToolNode` set — they share three
  `SphereGeometry`s already (post-F2), instanced meshes is the
  next step.
- **Additive bloom**: brightens dense clusters automatically.
  Postprocessing already in the dep list
  (`@react-three/postprocessing`), not wired in yet.
- **Procedural nebula background**: animated gas clouds. Our
  `GalaxyDust` is close but static.
- **Curved Bezier edges at convergence**: edges go from straight
  lines to gentle curves once the layout has settled. Looks
  alive instead of mechanical. We already use
  `QuadraticBezierLine`, so this is a polish tweak.

**Action item:** add a "force-directed" lens mode that runs the
simulation for 2–3 seconds after pocket open, then snaps to a
relaxed layout. Keep the existing Fibonacci layout as the fallback.

## Apple frameworks landscape — WWDC25 → 2026

| Was | Now | Notes |
| --- | --- | --- |
| SceneKit | **RealityKit** | SceneKit officially deprecated at WWDC25. Existing apps still run, no new features. New default: RealityKit + `RealityView` in SwiftUI. |
| `.scn` proprietary | **`.usd`** (Universal Scene Description) | Pixar / industry standard; opens in Reality Composer Pro. |
| Node-based | **ECS** (Entity Component System) | Different mental model — entities + components instead of a node tree. The R3F scene graph maps cleanly to entities. |
| iOS/macOS only | iOS, iPadOS, macOS, **visionOS**, tvOS | Same code on Apple Vision Pro. Worth keeping in mind for the future. |

**Action item:** SwiftUI port targets RealityKit, not SceneKit. The
data model and layout math port; the rendering layer is a clean
rewrite.

## Mobbin reference patterns

Mobbin doesn't index "3D knowledge graph" specifically, but it has
4 100+ navigation / map flows and 2 600+ chart screens.

For our iPhone overlay we want to study:

- **Apple Maps / Google Maps** — bottom-sheet behaviour, drag
  affordances, three detent stops (compact / mid / expanded).
- **ChatGPT iOS** — input bar above the keyboard, attachment
  affordances, history sheet from the top-left.
- **Linear iOS** — command palette feel and the way it dims the
  underlying view without losing context.
- **Things 3** — keyboard shortcut affordances (the small
  semi-transparent overlays).

**Action item:** when the SwiftUI port hits Phase 2, do a Mobbin
session through these four apps and capture the specific gestures
worth lifting. Save the notes to `docs/DESIGN_REFS_MOBBIN.md`.

## Top-app patterns we already do well

- Cosmic field depth ✅ (`Scene` + `StarField` + `GalaxyDust`).
- Selective labels ✅ (only selected / hover / connected).
- Layered Escape ✅ (pocket first, then dialog) — keep this in the
  iOS port via a single chevron button + drag-down.

## Where the React app should still grow before the iOS port starts

Anything visible here is fair game to also reshape the web build:

1. **Force-directed pocket option** (Obsidian-style).
2. **Bloom postprocessing pass** for selected node + active pocket.
3. **Animated edge convergence** — straight → Bezier as graph
   settles.
4. **Instanced ToolNode meshes** — perf win that also unlocks larger
   universes.

Each of these is a small, isolated PR. None blocks the iOS port.
