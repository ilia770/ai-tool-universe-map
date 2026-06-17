# R-viz-switcher — VisualizationStyle real switcher
**Phase:** R · **Lens:** render

## Goal (1-2 lines)
Turn the stubbed `VisualizationStyle` into a real live switcher over our finalist layouts A/K/N/O, all rendered through ONE shared overlay engine (orbs/edges/badges) — only the layout strategy differs, the render path is shared. Persisted via `AppSettings`.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- modify `Sources/MyAIMap/State/VisualizationStyle.swift` — rename/extend cases to the finalists, drop `available == galaxy only`, add per-style metadata; keep stable `rawValue`s + RU/EN titles (see `VisualizationStyleTests`).
- create `Sources/MyAIMap/Universe/Overlay/LayoutStrategy.swift` (pure protocol + A/K/N/O strategies producing world positions).
- create `Sources/MyAIMap/Universe/Overlay/UniverseOverlayHost.swift` (the shared overlay: TimelineView → `UniverseProjection` → OrbLayer + ConnectionCanvas + NodeBadge).
- reuse `Universe/UniverseLayout.swift` as strategy **A/N** base (ring + 3D depth); `AppSettings.swift` for persistence; `Universe/UniverseScreen.swift` to mount the host.

## Approach (bullet steps)
- Define `LayoutStrategy` returning `[NodeId: SIMD3<Float>]` from seed + selection; map the four finalists:
  - **A** Connected Mind — force-directed (port web `relax()` spring solver).
  - **K** Bloom — progressive reveal (drives DeclutterRule reveal order, A layout base).
  - **N** 3D Force — true orbit/parallax depth (current `UniverseLayout` + projection depth).
  - **O** Neural Universe — hero hybrid (A positions + heavier halo/ambient styling).
- All strategies feed `UniverseProjection`; `UniverseOverlayHost` renders orbs/edges/badges identically — layout differs, render shared.
- Settings → Visualization picker switches live; persist selection in `AppSettings`; cross-fade between layouts via `UniverseMotion` (Reduce-Motion gated).
- Galaxy/legacy RealityKit scene retained as an ambient backdrop / fallback option (per design: RealityKit = backdrop only).

## Interface / contract
```swift
protocol LayoutStrategy: Sendable {
    var style: VisualizationStyle { get }
    func positions(seed: UniverseSeed, mode: ViewMode, openCategory: ToolCategory?) -> [String: SIMD3<Float>]
}
enum LayoutStrategyFactory {
    static func make(_ style: VisualizationStyle) -> any LayoutStrategy
}
struct UniverseOverlayHost: View {
    let style: VisualizationStyle
    // builds CameraState → projects → OrbLayer + ConnectionCanvas + NodeBadge
    var body: some View { TimelineView(.animation) { _ in /* … */ } }
}
```

## Tests (`Tests/MyAIMapTests`)
- extend `Tests/MyAIMapTests/VisualizationStyleTests.swift`: every finalist case now `available`; raw values stable; RU/EN titles non-empty (keep existing asserts green).
- create `Tests/MyAIMapTests/LayoutStrategyTests.swift` (pure): each strategy returns a position for every seed tool; core stays at origin; positions are finite/non-NaN; A/N differ for the same seed (layouts are real, not aliases).
- `AppSettings` persists/restores the chosen style (extend `AppSettingsTests`).
- Live switch + per-style look verified by simulator screenshots (design "Testing").

## Done criteria (checklist)
- [ ] All four finalists selectable and render through the shared overlay (not stubs).
- [ ] Settings picker switches live and persists via `AppSettings`.
- [ ] `LayoutStrategy` outputs unit-tested (every tool placed, finite, core at origin).
- [ ] `VisualizationStyleTests` still pass; raw values unchanged.

## Dependencies (other tasks)
- R-projection, R-orb-layer, R-connection-canvas, R-node-badge, R-declutter, R-motion (the shared render stack).
- S-account-settings-screen (the picker UI) + reuses `AppSettings`.
