# R-orb-layer — OrbLayer glowing discs
**Phase:** R · **Lens:** render

## Goal (1-2 lines)
Render nodes as light glowing discs (radial-gradient core + additive halo aura) in the overlay `Canvas`, with a clear size hierarchy core > category > tool and a single palette from the category color system — always perfectly round and identically lit, replacing the dark untessellated RealityKit spheres.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Universe/Overlay/OrbLayer.swift` (SwiftUI `Canvas`).
- create `Sources/MyAIMap/Universe/Overlay/OrbStyle.swift` (pure: radius ladder + emissive ramp — unit-tested).
- reuse `Universe/Camera/PocketTransition.swift` radius intent (`baseToolRadius`, `desiredToolRadius`, `baseAnchorRadius`) as the screen-space size ladder source of truth.
- palette from seed via `Data/ToolCategory.swift`; positions/size from `UniverseProjection` (`depthScale`).
- supersedes world spheres in `UniverseView.styleToolNode`/`styleAnchor`/`makeFounderHalo`.

## Approach (bullet steps)
- Draw each orb as a radial-gradient filled circle (bright core → category hue → transparent rim) plus a larger additive halo (scale 1.2–1.6, low opacity) for the "subtle glow/depth".
- Screen radius = base ladder radius × `depthScale` (near bigger, far smaller). Three-step ladder: core ≈ 2× a mid tool, category shell ≈ 1.3× a tool — derived from `PocketTransition` radii so 3D and overlay agree.
- Emissive ramp by state: overview / pocket / selected / dimmed (lighter base than the old `darkened(0.75)` lumps).
- Selected orb: brighter core + halo + ±5% pulse (R-motion); others recede.
- Eased entrance/scale (lerp toward target, no snap) via `UniverseMotion`.
- One palette only — category hue from seed; no per-orb ad-hoc colors.

## Interface / contract
```swift
enum OrbRole { case core, category, tool }
enum OrbState { case overview, pocket, selected, dimmed }
struct ProjectedOrb: Sendable {
    var center: CGPoint
    var depthScale: CGFloat
    var role: OrbRole
    var state: OrbState
    var color: Color
}
enum OrbStyle {
    static func screenRadius(role: OrbRole, orbit: Int, depthScale: CGFloat) -> CGFloat
    static func emissive(_ state: OrbState) -> CGFloat   // glow intensity
    static func haloScale(_ state: OrbState) -> CGFloat
}
struct OrbLayer: View {
    let orbs: [ProjectedOrb]
    var body: some View { /* Canvas { for orb in orbs … } */ }
}
```

## Tests (`Tests/MyAIMapTests`)
- create `Tests/MyAIMapTests/OrbStyleTests.swift` (pure, like `PocketTransitionTests`/`ToolLabelFadeTests`):
  - size ladder: core > category > tool at equal depth; radius scales with `depthScale`.
  - `emissive` selected > pocket > overview > dimmed; all ≥ 0.
  - `haloScale` ≥ 1 and larger for selected than overview.
  - ladder constants trace to `PocketTransition` radii (no divergent magic numbers).
- Visual roundness/lighting verified by simulator screenshots per design "Testing".

## Done criteria (checklist)
- [ ] Orbs are perfectly round radial-gradient discs + additive halo; no dark lumps.
- [ ] Clear core > category > tool size hierarchy; single seed palette.
- [ ] Eased entrance/scale (no snap); selected pulses, others recede.
- [ ] `OrbStyle` math unit-tested headless.

## Dependencies (other tasks)
- R-projection (center + depthScale), R-motion (eased scale + pulse), R-declutter (which orbs draw).
- Reuses `PocketTransition` radius ladder + seed palette.
