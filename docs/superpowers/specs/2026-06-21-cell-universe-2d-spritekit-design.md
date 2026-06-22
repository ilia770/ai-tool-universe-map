# 2D Cell Universe (SpriteKit) — Design

Date: 2026-06-21
Status: Approved (brainstorm), pending spec review
Branch: `feat/cell-universe-spritekit` (off `feat/render-modes-product-v2` / PR #97)

## Goal

Replace the `graph2D` render mode's static Canvas graph with a living
**cell universe**: physics-driven cells the user pokes and drags. Tapping a
big category cell makes it "divide" — its tools burst out as smaller cells,
animated and bouncy, while staying visibly tied to their parent. The
`spatial3D` (RealityKit) mode is untouched; the user still picks 2D vs 3D in
Settings.

## Locked interaction model

- **Hybrid hierarchy.** Founder OS is a permanent central anchor. Category
  "big cells" hang in a ring around it. Tools are not shown until a category
  is expanded. Preserves core → category → tool.
- **Tap a category → it divides.** Tool cells spawn from the category centre
  and burst outward (radial impulse = "распад"), held near the parent by
  springs. Tap again → tools are pulled back in and despawn.
- **Multiple categories can be expanded at once.** Density is handled by
  pan/zoom.
- **Lineage shown four ways at once:** parent colour, umbilical lines,
  spatial cluster, translucent membrane (see §4).
- **Everything is physical:** cells bounce, jiggle, and can be dragged; the
  neighbourhood reacts with spring + restitution.

## Architecture

### 1. SwiftUI ↔ SpriteKit bridge
- `graph2D` branch in `UniverseMapView` renders `CellUniverseView` (was
  `UniverseGraphView`).
- `CellUniverseView: View` hosts `SpriteView(scene:)` with a single
  `CellUniverseScene: SKScene`.
- The view passes the model snapshot in and observes `UniverseViewModel`:
  - in → `planets: [PlanetData]`, `mode: UniverseMode`, `reduceMotion`,
    `expandedCategories: Set<ToolCategoryId>`.
  - out (scene → model) via closures: tap tool → `model.focusTool(id)`,
    tap category → toggle expand, tap empty → `onEmptyTap`.
- On model change, `CellUniverseView.updateUIView`-equivalent diffs and
  tells the scene what to add/remove (don't rebuild the scene).

### 2. Scene graph + physics
- **Core**: static `SKPhysicsBody` (circle) pinned at scene centre; Founder
  OS label.
- **Category cells**: dynamic circular bodies, each `SKPhysicsJointSpring`
  to the core → they orbit/jiggle around the centre in a ring (initial
  angle from `UniverseSeed.category(id).angle`).
- **Tool cells**: spawned on expand; dynamic bodies, `SKPhysicsJointSpring`
  to their category cell (cluster + umbilical anchor).
- **Collision**: all cells collide (mutual repulsion, never overlap);
  `restitution ≈ 0.6` for bounce. Bitmask groups so umbilical lines /
  membrane (non-physical `SKShapeNode`s) don't collide.
- **Drag**: `touchesBegan/Moved` picks the nearest body; drag moves it
  (temporarily high damping / mouse-joint style), neighbours react via
  springs + restitution; release lets it settle.

### 3. Divide / collapse
- **Expand**: add tool nodes at the category centre, apply outward radial
  `applyImpulse` (fan by index), attach spring joints to the parent. The
  springs' rest length defines the cluster radius.
- **Collapse**: remove the tool joints, apply an inward impulse toward the
  parent, despawn each tool node once it is within a small radius (or after
  a fixed settle interval).
- Re-tapping toggles; many categories may be expanded simultaneously.

### 4. Lineage visuals (all four)
- **Parent colour**: tool cell fill = its category's `BrandColor`.
- **Umbilical lines**: one `SKShapeNode` per tool→category joint; its path
  is recomputed every frame in `update(_:)` to follow both bodies.
- **Cluster**: spring joints keep a category's tools grouped near it.
- **Membrane**: one translucent `SKShapeNode` per *expanded* category — a
  convex hull (or padded bounding blob) around that category's tool cells +
  the category cell, recomputed each frame; filled with the category colour
  at low opacity, like a cell membrane.

### 5. Camera
- `SKCameraNode`: drag-to-pan, pinch-to-zoom (clamped), so many expanded
  categories remain navigable. Default frames the core + category ring.

### 6. Reduce-motion & UI-test quiescence (critical)
- A continuously-simulating `SKScene` never reaches quiescence, which would
  hang `MyAIMapUITests` exactly like the RealityKit issue solved earlier.
- Under `reduceMotion` **or** the `-uitestStatic` launch argument:
  - lay cells out with the existing pure `UniverseGraphLayout` (static
    target positions, no physics),
  - set `scene.physicsWorld.speed = 0` / `scene.isPaused = true` after the
    first layout pass,
  - skip umbilical/membrane per-frame recompute (draw once).
- This keeps the smoke test green and keeps `UniverseGraphLayout` +
  `UniverseGraphLayoutTests` alive as the static-layout source of truth.

### 7. State ownership
- `expandedCategories: Set<ToolCategoryId>` is UI state. Decision: store it
  on `UniverseViewModel` (so it survives sheet open/close and is unit-
  testable) but it is NOT persisted to disk (resets each launch).
- A pure `CellExpansionReducer` (toggle / collapseAll / isExpanded) is the
  testable core; the scene just reflects it.

## Components (units, each independently testable where possible)

| Unit | Purpose | Testable |
| --- | --- | --- |
| `CellUniverseView` | SwiftUI host, model↔scene sync | light |
| `CellUniverseScene` | SpriteKit scene: bodies, joints, drag, camera | visual/QA |
| `CellExpansionReducer` | expanded-set toggle logic | unit |
| `UniverseGraphLayout` (reuse) | static fallback positions | unit (exists) |
| tap→intent mapping | node name → model intent | unit |

## What is removed / changed
- `UniverseGraphView` (Canvas 2D from PR #97) is replaced by the SpriteKit
  path for `graph2D`. `UniverseGraphLayout` + its tests are **kept** (static
  fallback). `spatial3D` path unchanged.

## Testing strategy
- Unit: `CellExpansionReducer`, tap→intent mapping, `UniverseGraphLayout`
  (existing, incl. no-overlap of the static fallback).
- Physics/scene: not unit-tested; validated by screenshots (2D divide states)
  + the existing UI smoke (must stay green via §6).
- Gate: `ios-verify.sh --full-test` + sim screenshots of: collapsed ring,
  one category divided, multiple divided.

## Out of scope (YAGNI)
- Persisting expansion state.
- 3D changes.
- Progressive multi-level beyond category→tool (no sub-tool nesting).

## Open defaults (chosen, not blocking)
- Pan/zoom via `SKCameraNode`: kept.
- Category ring visible from first launch around the core: yes.
