# R-node-badge — NodeBadge glass pill
**Phase:** R · **Lens:** render

## Goal (1-2 lines)
A fixed-size, screen-space SwiftUI glass-pill badge — dark translucent plate, 1px stroke/outline, subtle glow, Dynamic Type label, optional brand icon, press 0.96 + haptic — that replaces the meter-sized 3D extruded text. This is the marquee legibility fix named #1 by five of six lenses.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Universe/Overlay/NodeBadge.swift` (SwiftUI view).
- reuse `Sources/MyAIMap/UI/Effects/PressBounce.swift` (press 0.96), `Sources/MyAIMap/UI/Haptics/BrandHaptics.swift` (`.light` tap), `Sources/MyAIMap/UI/Theme/BrandColor.swift`, `BrandRadius.swift`, `BrandTypography.swift`.
- reuse category color/angle source `Resources/ai-tool-universe.seed.json` via `Data/ToolCategory.swift` / `UniverseSeed.swift` for the tint.
- positioned by `UniverseProjection` output inside the overlay host (R-viz-switcher).

## Approach (bullet steps)
- Capsule pill (radius = height/2). Plate: vertical gradient `#0E1726@0.86 → #040812@0.76`; 1px border white@0.18, tinted to category color ~40% for category pills; 1px inner top highlight (liquid-glass sheen).
- Label `Text` `#F8FCFF`@0.96 with a dark stroke/outline (shadow or layered draw) for legibility over any backdrop; `lineLimit(1)`, `minimumScaleFactor(0.85)`, max-width ~116pt tool / 232pt focus.
- Type via `@ScaledMetric` (Dynamic Type): category ≈ `.caption.bold`, tool ≈ `.caption2.semibold`, focused ≈ `.subheadline.bold`.
- Optional leading category-color dot (tool) or brand icon (`ToolLogo`-style monogram fallback) to tie orb→label.
- Press: `PressBounce` scale 0.96 + `BrandHaptics.light` on tap-select.
- Entrance: fade + scale 0.85→1.0 over 0.32s via `UniverseMotion` (R-motion), gated on Reduce Motion.
- Pure view of `(text, role, categoryColor, opacity)` — placement/projection stays outside.

## Interface / contract
```swift
enum BadgeRole { case category, tool, focused }
struct NodeBadge: View {
    let title: String
    let role: BadgeRole
    let categoryColor: Color
    let icon: Image?          // brand glyph / monogram fallback
    let opacity: CGFloat      // from depth/declutter
    let onTap: () -> Void
    var body: some View { /* capsule + stroke + glow + label */ }
}
```

## Tests (`Tests/MyAIMapTests`)
- View body is hard to unit-test headless; follow `SettingsSheetTests`/`ChromeSnapshotTests` conventions for view-construction smoke + any pure helpers.
- create `Tests/MyAIMapTests/NodeBadgeTests.swift`: assert any pure pill-metrics helper (plate height per role, max-width per role, scaled-type sizes) returns expected constants and tool < category < focused.
- Assert `categoryColor` is sourced from seed (no hardcoded hex divergence) where a helper exposes it.
- Real legibility/contrast verified by simulator screenshots (overview + pocket) per design "Testing".

## Done criteria (checklist)
- [ ] Fixed point-size pill; never scales with camera distance.
- [ ] Stroke + dark plate + Dynamic Type + `minimumScaleFactor`; readable over starfield and bright nebula.
- [ ] Press 0.96 + `.light` haptic; entrance honors Reduce Motion.
- [ ] Category border tinted to seed category color.

## Dependencies (other tasks)
- R-projection (placement), R-motion (entrance/Reduce Motion), R-declutter (supplies `opacity`/visibility).
- Reuses A-/S- nothing; pure render. Hosted by R-viz-switcher.
