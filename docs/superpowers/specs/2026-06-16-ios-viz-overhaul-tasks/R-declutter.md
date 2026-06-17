# R-declutter — DeclutterRule
**Phase:** R · **Lens:** render

## Goal (1-2 lines)
A pure rule that decides which nodes/labels render: overview shows only category badges + hub nodes, opening a pocket reveals that category's tool badges, the rest distance-fade. The single biggest legibility win on a 6" screen — never 49 labels at once.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Universe/Overlay/DeclutterRule.swift` (pure, Foundation + simd + CoreGraphics only).
- reuse `Universe/Entities/ToolLabelFade.swift` (distance-fade curve) for the per-node fade term.
- reuse `State/UniverseSelection.swift` (`ViewMode` overview/pocket/node) + selection state.
- feeds visibility/opacity into R-node-badge, R-orb-layer, R-connection-canvas.

## Approach (bullet steps)
- Inputs: `ViewMode`, the open category (if any), selected tool, each node's `(role, category, depthScale, screenPoint)`.
- Overview → emit category badges + hub/core only; tool badges hidden except the single selected tool.
- Pocket → emit the open category's tool badges + its edges; other categories' tools fade by distance.
- Distance fade per node from `ToolLabelFade.opacity(distance:)` (or its depthScale equivalent) so far nodes recede smoothly.
- Screen-space collision: if two badge centers project within ~36pt, fade the lower-priority one (selected > category > inner orbit > outer orbit) — cheap pairwise compare on projected points.
- Output is a per-node decision (`hidden` / `opacity`) the render layers multiply into their own alpha; pure and deterministic.

## Interface / contract
```swift
struct NodeVisibilityInput: Sendable {
    var id: String
    var role: OrbRole            // core / category / tool
    var orbit: Int
    var isSelected: Bool
    var inOpenPocket: Bool
    var depthScale: CGFloat
    var screen: CGPoint
}
enum DeclutterRule {
    static func decide(
        mode: ViewMode,
        nodes: [NodeVisibilityInput],
        collisionRadiusPt: CGFloat = 36
    ) -> [String: CGFloat]      // id → resolved label/orb opacity (0 == hidden)
}
```

## Tests (`Tests/MyAIMapTests`)
- create `Tests/MyAIMapTests/DeclutterRuleTests.swift` (pure, like `UniverseLayoutTests`/`ToolLabelFadeTests`):
  - overview hides non-selected tool labels, keeps all category labels + core.
  - pocket reveals open-category tools, fades other categories' tools toward 0.
  - selected tool always visible even at overview.
  - two badges within `collisionRadiusPt` → lower priority gets reduced opacity; far apart → both full.
  - all opacities clamped [0,1]; deterministic for fixed input.

## Done criteria (checklist)
- [ ] Overview never emits more than category pills + selected tool.
- [ ] Pocket reveals exactly the open category's tools; others distance-fade.
- [ ] Screen-space 36pt collision arbitration by priority.
- [ ] Pure + headless-tested; clamped [0,1]; reuses `ToolLabelFade`.

## Dependencies (other tasks)
- R-projection (screen points + depthScale), reuses `ToolLabelFade`, `ViewMode`.
- Consumed by R-node-badge, R-orb-layer, R-connection-canvas.
