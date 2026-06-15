# Visualization Playground Design

Date: 2026-06-15
Status: approved for planning
Owner: Codex

## Goal

Build a contained web playground that lets us compare three alternate AI Map
visualization metaphors side by side before choosing what to productize:

1. AI Brain - Obsidian/Cosmograph-style animated graph.
2. Vision Space - black Vision Pro-like object space.
3. AI Galaxy - Google Earth / No Man's Sky / RTS-style galaxy map.

The playground is for product and design testing. It must not replace or
destabilize the current production map.

## Non-Goals

- No new backend, database, or data migration.
- No iOS implementation in this slice.
- No production default switch to a new visualization.
- No large dependency migration.
- No attempt to perfectly solve force-directed graph physics yet.

## Entry Point

Add a lightweight mode switch in `src/App.tsx`:

- `Universe Map` shows the current `AIToolUniverseMap`.
- `Visual Lab` shows the new comparison playground.

This avoids adding a routing library and keeps the experiment easy to remove.
The default app opens the existing universe map, preserving current behavior.

## Shared Data Adapter

Create a small adapter under `src/components/VisualizationLab/` that maps the
existing seed data into render-oriented structures:

- `LabNode`: id, label, category id, color, stage, orbit, relation ids, weight.
- `LabLink`: source id, target id, strength, label, confidence.
- `LabCluster`: category id, label, color, node ids.

All three variants consume the same adapter output so differences come from
visualization, not data drift.

## Variant A: AI Brain

Purpose: test the most useful UX direction.

Design:

- 2D animated relationship graph inspired by Obsidian and Cosmograph.
- Nodes are tools; node color is category; node radius is orbit/importance.
- Edges are existing `workflowLinks` and `relationIds`.
- Selecting a node makes it the visual center and increases opacity of its
  direct neighborhood.
- Labels stay visible for selected and nearby nodes, with background labels
  reduced to avoid clutter.

Implementation:

- Use SVG or Canvas inside React for the first prototype.
- Implement deterministic lightweight force simulation in local component state.
- Avoid adding a heavy graph dependency until this variant wins.
- Respect reduced motion by rendering a settled layout with no continuous drift.

## Variant B: Vision Space

Purpose: test the premium Apple-like direction.

Design:

- Minimal black 3D scene with floating category/vendor objects.
- Fewer objects are visible at once; categories act as spatial anchors.
- Selected category/object enlarges, connected tools appear as orbiting chips.
- Strong glow and depth, but restrained palette and low label density.

Implementation:

- Use existing Three/R3F stack and current category/tool data.
- Keep geometry simple: spheres, rounded panels, billboard text.
- Reuse existing category colors and reduced-motion helper.
- Avoid large postprocessing changes in this slice.

## Variant C: AI Galaxy

Purpose: test the most dramatic exploration direction.

Design:

- Galaxy/RTS map where categories are sectors and tools are stars.
- Overview shows the whole AI industry; zoom/focus moves toward a category
  sector; selected tools brighten with relation arcs.
- Star size derives from orbit/importance; color derives from category.
- The interaction should feel like navigating a map, not reading a directory.

Implementation:

- Use existing Three/R3F stack.
- Create deterministic galaxy positions from category angle and tool angle.
- Reuse the current camera controller patterns where possible.
- Keep particle/star counts bounded for mobile GPU safety.

## Playground UI

`VisualizationLab` contains:

- Header with back/switch button to current map.
- Three tabs: Brain, Vision, Galaxy.
- Shared selected tool state.
- Small comparison rail showing qualitative notes:
  - readability
  - perceived premium feel
  - relationship clarity
  - mobile/GPU risk

The playground should avoid marketing copy. It is an internal evaluation tool.

## File Plan

Expected new files:

- `src/components/VisualizationLab/VisualizationLab.tsx`
- `src/components/VisualizationLab/visualization-data.ts`
- `src/components/VisualizationLab/BrainGraphVariant.tsx`
- `src/components/VisualizationLab/VisionSpaceVariant.tsx`
- `src/components/VisualizationLab/GalaxyMapVariant.tsx`
- `src/components/VisualizationLab/index.ts`

Expected modified files:

- `src/App.tsx`
- `src/index.css` only for shared lab styles that cannot stay local.
- `.gitignore` to ignore `.superpowers/` companion artifacts.

## Testing

Minimum verification:

- `npm run typecheck`
- `npm test`
- `npm run build`

Focused tests:

- Add unit tests for the visualization data adapter:
  - every tool becomes one node
  - generated links reference known nodes
  - category clusters include only their tools
  - output order is deterministic

Visual smoke is recommended after implementation if the local dev server is
available, but this design spec does not require production screenshot gates.

## Success Criteria

- The existing default map still opens first.
- Visual Lab can switch between all three variants without a page reload.
- All variants use the same seed data.
- AI Brain clearly communicates tool relationships.
- Vision Space clearly communicates premium spatial objects.
- AI Galaxy clearly communicates sector/scale exploration.
- Build and unit checks pass.

## Risks

- Three variants can become too broad. Mitigation: keep each as a prototype,
  not production polish.
- Labels can clutter the Brain and Galaxy variants. Mitigation: selected and
  near-neighbor labels are prioritized; background labels fade.
- R3F duplication can grow. Mitigation: keep shared helpers in
  `visualization-data.ts` only; do not refactor the production 3D scene.
- Mobile GPU risk in Galaxy. Mitigation: deterministic bounded counts and
  no expensive postprocessing in this slice.
