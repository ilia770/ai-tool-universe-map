# iOS Viz Research — LENS: Rendering-tech options

Graphics-engineer evaluation of the rendering stack for "My AI Map". Scope: the 3D
universe in `Sources/MyAIMap/Universe/*`. Goal: premium / 60fps / lightweight, and
serve "see the structure, then find a tool fast".

---

## TL;DR recommendation

**Keep RealityKit only for ambient/background depth (or drop it). Render the GRAPH
ITSELF in a 2.5D SwiftUI Canvas / SpriteKit force layout — flat, label-first, à la
the web finalist A (BrainGraph / Obsidian).**

This is option **(d) with a thin slice of (e)**: a 2D force-graph that owns nodes,
edges and labels, optionally composited over a slow RealityKit/Metal starfield for
cosmic depth. It is the single change that fixes every "looks terrible" symptom at
once and is the cheapest path to App-Store-grade legibility at 60fps.

Why not "keep refining RealityKit": the current problems are not polish bugs, they
are structural consequences of using a 3D world-space renderer for what is
fundamentally a 2D information graph (see root-cause analysis below). Refining it
means re-implementing screen-space text, screen-space line AA, and a screen-space
LOD/label-collision system on top of RealityKit — i.e. fighting the framework. A
2.5D canvas gives all three for free.

---

## Root cause of the current "looks terrible" symptoms

The complaints map 1:1 to RealityKit-in-world-space limitations:

- **Labels are GIGANTIC / inconsistent.** `UniverseView.makeCategoryLabel` /
  `makeToolLabel` use `MeshResource.generateText`, which sizes text in **meters**
  (`labelFontSize = 0.8`, `toolLabelFontSize = 0.32`). World-space text has no
  fixed pixel size — it scales with camera distance and FOV, so it reads huge at
  one zoom and unreadable at another. There is no crisp stroke/outline available
  on extruded `generateText`, and the requested "tidy darkened badge backing" is
  impossible on a 3D text mesh. The hand-tuned `labelInset` / `labelLift` /
  `ToolLabelFade` near/far ramp (UniverseView.swift:636-693, ToolLabelFade.swift)
  are all workarounds for the absence of screen-space text. In a 2D/2.5D renderer
  text is just a `Text`/`CATextLayer` at a fixed point size with a `.stroke` and a
  rounded glass badge — exactly what was asked.

- **Orbs look crooked / crude.** Spheres are real PBR meshes lit by a code-built
  key/fill/IBL rig (UniverseView.swift:210-242, CosmicEnvironmentTexture). Low
  segment counts plus uneven lighting plus perspective foreshortening at the edges
  of a narrow portrait FOV make them read as lumpy/tilted. A 2.5D node is a radial
  gradient + halo sprite that is always perfectly round and identically lit.

- **Connection lines barely visible / messy.** Links are thin 1×1×1 boxes
  (`linkMesh`, `makeLink`, LinkGeometry) with `UnlitMaterial` transparency at
  opacity 0.012–0.62. World-space "tube" lines have no anti-aliasing, depth-fight
  with nodes, and shrink to sub-pixel width at distance — hence "barely visible."
  The code even documents that pocket links don't follow re-layout
  (UniverseView.swift:133-148). Canvas/SpriteKit gives true 1–2px AA strokes with
  gradients and additive blend that read crisply at any zoom.

- **Structure is hard to read.** The cosmic ring layout
  (`UniverseLayout.categoryPosition` with `sin(angle*1.7)` vertical jitter) trades
  legibility for "space" aesthetics. A force/cluster layout in a plane makes
  category clusters and cross-links obvious — directly serving "structure then
  find fast."

These are framework-shaped problems, not tuning problems.

---

## Option-by-option

### (a) Keep RealityKit, refine — NOT recommended as the primary graph renderer
- Legibility: poor by default; requires reimplementing screen-space text + a
  label-collision/LOD system RealityKit does not provide.
- Labels: worst case. `generateText` is meter-sized, no stroke, no badge. The only
  fix is to overlay SwiftUI/`Html`-style labels positioned by projecting each
  node to screen space every frame — which means you've already left RealityKit
  for the part users actually read.
- Perf: heaviest. PBR + IBL + per-transition `PhysicallyBasedMaterial`
  reallocation (flagged in `applyLayout`, UniverseView.swift:464-521), plus three
  ambient shells (Skybox/StarField/GalaxyDust). 49 nodes is trivial geometry; the
  cost is all material/lighting/text, none of which serves legibility.
- Dev cost: high and ongoing — you keep fighting world-space text/lines.
- Verdict: a 3D world engine for a 2D information graph. Wrong tool. Its one real
  asset is ambient depth, which it can keep providing as a background layer.

### (b) SceneKit — not recommended
- Same world-space text/line problems as RealityKit (`SCNText` is meter-sized too).
- Older, less aligned with SwiftUI; billboard constraints and gestures are more
  manual. No legibility win over RealityKit; loses RealityKit's ECS/material story.
- Only reason to pick it would be finer per-node control, which 2.5D gives more
  cheaply. Skip.

### (c) Metal / custom — overkill now, keep as escape hatch
- Best ceiling (instanced quads for nodes/halos, a single AA line shader, SDF text
  atlas → thousands of nodes at 120fps, true bloom). This is literally how the web
  finalists O/N draw (instanced billboard glows, SDF `troika`/drei `Text`).
- Dev cost: very high; you hand-build text layout, hit-testing, gestures, glass.
- Verdict: not justified for 49 (even a few hundred) nodes. Revisit only if the
  dataset grows 10–100x or you want signature GPU bloom. A 2.5D Canvas/SpriteKit
  build is forward-compatible: the same layout + interaction model later drops onto
  a Metal node renderer if needed.

### (d) 2.5D force-graph in SwiftUI Canvas or SpriteKit — RECOMMENDED
- Legibility: the whole point. Flat plane = category clusters and cross-links are
  immediately readable; this is the layout of finalist **A (BrainGraph)**, the web
  default, and the one users describe as the "connected mind."
- Labels: solved natively. SwiftUI `Text` with `.font(.system(size:weight:))`,
  `.stroke`/`.shadow` for the crisp outline, over a `.ultraThinMaterial` /
  darkened rounded-rect badge — the exact ask. Fixed pixel size; never "gigantic."
  Add a screen-space label-collision pass (show selected + neighbours + hovered,
  hide the rest) — mirrors BrainGraph's `showLabel` tiering and Bloom's progressive
  reveal.
- Lines: crisp AA strokes with per-edge gradient + additive glow; pulse via a
  cheap `TimelineView`/`SKAction`. No depth-fighting, always visible.
- Perf: trivial. 49 nodes + ~150 edges is nothing for Canvas; SpriteKit instances
  sprites on the GPU. Easy 60/120fps, tiny binary, low memory — "lightweight."
- Dev cost: moderate, mostly layout + interaction (which already exist as pure math
  in `UniverseLayout` and as ported logic in `RelationshipIntelligence`). The web
  `relax()` spring solver in BrainGraph ports almost verbatim to Swift.
- Canvas vs SpriteKit: start with **SwiftUI Canvas + TimelineView** — pure SwiftUI,
  trivial liquid-glass/gesture/haptic integration with the existing
  `UI/Effects/*` and `UI/Haptics/*`, and the label-as-SwiftUI-view story is
  seamless. Move to SpriteKit only if node count or particle ambition outgrows
  Canvas's per-frame draw budget.

### (e) Hybrid: 2D graph + subtle RealityKit/Metal depth — RECOMMENDED as the final form
- Keep a slow parallax starfield / faint nebula as a **background layer only**
  (the existing `StarFieldEntity` / `GalaxyDustEntity` / `SkyboxEntity` can be
  reused behind a `RealityView` or rendered as a cheap Canvas gradient + sprite
  field). The interactive graph (nodes, edges, labels, hit-testing) lives entirely
  in the 2.5D layer on top.
- Gives the cosmic premium feel the brand wants without paying the world-space
  text/line tax for the content users must read. This is essentially what O
  (NeuralUniverse) and A (BrainGraph) both do — a glowy ambient field behind a
  legible graph — and is the recommended end state. Ship (d) first; layer the
  ambient depth back in as polish.

---

## How the web finalists inform this

- **A · BrainGraph (Obsidian / force-directed, the default):** flat 2.5D plane,
  spring `relax()` layout, neighbour-depth dimming (selected / neighbour / 2nd-deg
  / dimmed), labels + round brand badges shown only on highlighted nodes, glass
  detail card with clickable connection chips. This is the legibility + "find fast"
  target. Its label/badge model (`NodeBadge`, `showLabel` tiers) and edge model
  (merged `LineSegments`, opacity pulse, dim-on-select) port directly to Canvas.
- **K · BloomGraph (progressive reveal / autofocus):** the interaction pattern —
  reveal labels/neighbours progressively around focus instead of all at once. Adopt
  this as the label-collision rule so the graph never looks cluttered.
- **N · Force3D (true 3D force graph):** uses SDF `Text` with `outlineWidth`/
  `outlineColor` (Force3D.tsx:830-840) and screen-space `Html` badges with
  `distanceFactor` — confirming that even the 3D web variants do NOT use world
  extruded text; they use camera-facing SDF/DOM text with a stroke. The iOS
  equivalent of SDF-with-outline is SwiftUI `Text` with `.stroke` in Canvas.
- **O · NeuralUniverse (hero / volumetric):** the "premium" look = additive
  billboard halos (instanced glow sprites), `Billboard` SDF `Text` with
  `outlineWidth:0.05 / outlineColor:#04060f` (NeuralUniverse.tsx:721-735), pulses
  along synapses, heavy ambient haze. The legible text is camera-facing SDF with a
  dark outline — again, never world-extruded. Mine this for the ambient-depth layer
  of the hybrid, not for the graph mechanics.

Across all four finalists the pattern is identical and decisive: **billboarded /
screen-space text with a stroke + dark backing, additive glow sprites for nodes,
AA line segments for edges, focus-driven progressive label reveal.** The current
iOS build is the only place using world-extruded meter-sized text and box-mesh
lines — which is exactly why it looks worse than the web reference.

---

## Migration notes (low-risk, incremental)

1. Reuse pure math: `UniverseLayout`, `RelationshipIntelligence`,
   `RelationshipReason`, `UniverseSeed` are RealityKit-free and feed a Canvas
   renderer unchanged. Port BrainGraph's `relax()` spring solver to Swift for the
   planar layout (or keep the existing ring layout, just flattened).
2. New `UniverseCanvasView` (SwiftUI `Canvas` + `TimelineView`) draws edges
   (gradient AA strokes), node orbs (radial-gradient + halo), and overlays labels
   as SwiftUI `Text` badges positioned from the same node coordinates. Hit-testing
   via point-in-circle against node screen positions.
3. Wire the existing interaction/haptic/glass kit (`PressBounce`, `ParallaxTilt`,
   `BrandHaptics`, `LiquidGlass`) to node taps/long-press — these already exist and
   are unused by the RealityKit path's world-space gestures.
4. Optional ambient layer: keep `StarFieldEntity`/`GalaxyDustEntity` behind it, or
   replace with a cheap Canvas star/nebula draw to drop the RealityView entirely.
5. `VisualizationStyle.swift` already models a style enum — add the 2.5D mode there
   and A/B it against the RealityKit scene rather than ripping it out day one.

---

## Aside (out of lens, found while reading): chat does not scroll to bottom

`ChatDock.threadScroll` (ChatDock.swift:76-81) auto-scrolls in
`.onChange(of: thread.turns.map(\.id))` — it only fires when a turn is *added/removed*.
If the last turn's text grows (streamed answer) without the id set changing, no
scroll happens, so the view stays pinned above the new content. Fix: also observe
the last turn's content length, or use `.defaultScrollAnchor(.bottom)` (iOS 17+),
or scroll on the streamed-text change as well as the id change.
