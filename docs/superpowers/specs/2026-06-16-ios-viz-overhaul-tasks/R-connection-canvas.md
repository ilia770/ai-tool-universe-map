# R-connection-canvas — ConnectionCanvas anti-aliased edges
**Phase:** R · **Lens:** render

## Goal (1-2 lines)
Draw anti-aliased connection edges in a SwiftUI `Canvas` between projected node points: opacity by depth × relationship confidence, always attached to live node points (fixes the pocket-open detach), gently curved, tappable → "connected because" reason.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Universe/Overlay/ConnectionCanvas.swift` (SwiftUI `Canvas`).
- create `Sources/MyAIMap/Universe/Overlay/EdgeOpacity.swift` (pure opacity ladder — unit-tested).
- reuse `Data/RelationshipIntelligence.swift`, `Data/RelationshipReason.swift` (edges + reasons; see `RelationshipReasonTests`).
- positions from `UniverseProjection`; replaces world-box lines in `Universe/Entities/LinkGeometry.swift` / `UniverseView.makeLink` (no longer drawn in world space).

## Approach (bullet steps)
- Each frame the overlay hands `ConnectionCanvas` the projected endpoints of live nodes, so edges re-route automatically when a pocket opens (no detach).
- Pure `EdgeOpacity` ladder (mirrors web `ConnectionLines`): core→category 0.28, category→tool 0.10, inferred `0.06 + confidence·0.30`; multiply by min(endpoint `depthScale`) so far edges recede.
- Selection emphasis: an edge touching the selected tool / open category brightens to ~0.60 at ~2px in the endpoint color; all others drop to ~0.05.
- Stroke gently curved quadratic Bézier (slight sag), constant screen-px width, antialiased (`Canvas` default), additive-ish blend for glow.
- Hit-testing: point-to-segment distance against the curve; tap within ~10pt selects the edge → surface `RelationshipReason` ("connected because"). Reuse existing reason model.

## Interface / contract
```swift
enum EdgeKind { case spine, branch, inferred }
struct ProjectedEdge: Sendable {
    var a: CGPoint; var b: CGPoint
    var kind: EdgeKind
    var confidence: CGFloat        // inferred only
    var depthScale: CGFloat        // min of endpoints
    var touchesFocus: Bool
}
enum EdgeOpacity {
    static func base(_ kind: EdgeKind, confidence: CGFloat) -> CGFloat
    static func resolved(_ edge: ProjectedEdge, focused: Bool) -> CGFloat
}
struct ConnectionCanvas: View {
    let edges: [ProjectedEdge]
    let onTapEdge: (Int) -> Void   // index → reason lookup
    var body: some View { /* Canvas { Path … } */ }
}
```

## Tests (`Tests/MyAIMapTests`)
- create `Tests/MyAIMapTests/EdgeOpacityTests.swift` (pure, like `ToolLabelFadeTests`):
  - spine > branch base opacity; inferred grows with confidence and stays clamped [0,1].
  - `resolved` brightens a `touchesFocus` edge above a non-focus edge; non-focus drops near 0.05 when any focus exists.
  - opacity scales down with lower `depthScale`.
- Hit-test helper (point-near-segment) asserted on known geometry.
- Edge→reason mapping reuses `RelationshipReasonTests` conventions.

## Done criteria (checklist)
- [ ] Edges re-route on pocket open (driven by live projected points, no static world line).
- [ ] AA constant-width strokes; opacity ladder = depth × confidence with selection emphasis.
- [ ] Tappable edge opens its "connected because" reason.
- [ ] `EdgeOpacity` math unit-tested headless; clamped [0,1].

## Dependencies (other tasks)
- R-projection (endpoints + depthScale), R-declutter (which edges are live/visible), R-motion (emphasis transitions).
- Reuses existing `RelationshipIntelligence`/`RelationshipReason`.
