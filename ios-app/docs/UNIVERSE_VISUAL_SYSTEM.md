# Universe RealityKit — Visual System

Date: 2026-07-10 · Phase 1 design doc, companion to
`UNIVERSE_REALITYKIT_AUDIT.md` / `UNIVERSE_ARCHITECTURE.md`. No code changed.
Current-state citations are `file:line` under `ios-app/Sources/MyAIMap/`.

## Principles

One coherent rendering language across all planets. Category identity comes
from *parameter variation* (tint, roughness, metallic, atmosphere, ring), not
from different techniques per planet. Restrained: readable silhouettes on
OLED, no bloom-noise, background never competes with planets.

## 1. PlanetDescriptor extension (PlanetData)

`PlanetData` (`PlanetData.swift:11-82`) today: id, title, subtitle,
color/accent, position3D, radius, toolCount, tools, categoryType. Add:

```swift
struct PlanetVisualDescriptor: Sendable {  // derived, deterministic per id
    let rotationSpeed: Double     // rad/s, slow: 0.008…0.02
    let axialTilt: Float          // radians, 0.05…0.35
    let materialStyle: MaterialStyle
    let atmosphereStyle: AtmosphereStyle  // tint + intensity + radius factor
    let ringStyle: RingStyle?     // nil for most; torus params for 1-2
    let satellite: SatelliteAccent?       // small orbiter, ≤2 planets total
}
```

Derivation: pure function of category id (hash-seeded constants table — NOT
random-per-launch; layout precedent: `UniverseSpatialLayout.swift:147-171`).
Replaces factory literals (spin duration hardcoded at
`PlanetEntityFactory.swift:56`, atmosphere factor `:38`, material split
`:244-251`).

## 2. Per-category visual table (proposal — tune with user's eye)

| Category | Seed color | MaterialStyle | Roughness | Metallic | Atmosphere | Ring/Satellite | Tilt | Spin |
|---|---|---|---|---|---|---|---|---|
| core (AI Operating Core) | #d8faff | emissive ceramic core | 0.32 | 0.10 | bright soft halo (exists: founder halo `:194-211`) | — | 0.05 | slowest 0.008 |
| coding | #6ee7ff | soft metallic | 0.38 | 0.55 | cyan rim | thin ring | 0.22 | 0.014 |
| design | #ff8bd2 | satin | 0.52 | 0.25 | pink glow | — | 0.30 | 0.012 |
| research | #7fffd4 | frosted translucent | 0.60 | 0.12 | mint haze | — | 0.15 | 0.016 |
| media | #ffd166 | mineral | 0.48 | 0.35 | warm amber | small satellite | 0.35 | 0.018 |
| distribution | #9bff8a | glass-like | 0.30 | 0.20 | green rim | — | 0.12 | 0.020 |
| infrastructure | #a78bfa | soft metallic (darker) | 0.42 | 0.60 | violet | thin ring | 0.26 | 0.010 |
| knowledge | #f0abfc | ceramic | 0.55 | 0.15 | orchid haze | — | 0.18 | 0.013 |
| analytics | #67E8F9 | satin (cool) | 0.50 | 0.30 | teal rim | — | 0.24 | 0.015 |

MaterialStyle → `PhysicallyBasedMaterial` parameter sets only (baseColor tint
from seed color, roughness/metallic per table, emissive from accent ×
selection state). Rings on exactly 2 planets (coding, infrastructure); one
satellite (media). Differences stay in-system per the brief.

## 3. Selection visuals (mutation, never rebuild)

Baseline projections keep driving everything (`UniverseMode.swift:118-160`
opacity tables — already restrained, no full-screen dimming). On select:
- scale ×1.06, short ease via `move(to:)` on `handle.root`
- atmosphere intensity up (existing `pulse()` clip `:341-353`)
- sun light lerp 500→5200 (`SunLightIntensity.swift:4-17` — exists)
- spin × 0.6 (readability, brief requirement)
- label promotion is SwiftUI overlay (`PlanetInfoCard`) — unchanged
- NO added rings/borders, NO aggressive dim of others (brief).

## 4. Mesh/material caching

Today (audit §Planet entities): per-planet `generateSphere` ×2, per-satellite,
per-halo, per-star ×120, per-ring torus regenerated — only `linkMesh` shared
(`PlanetEntityFactory.swift:150`); dust shows the correct pattern
(`GalaxyDustEntity.swift:38-46`, unmounted).

After:
| Resource | Cache |
|---|---|
| Sphere mesh | ONE unit sphere (`generateSphere(radius: 1)`) static let; scale via transform (planets, atmospheres, satellites, stars) |
| Torus (orbit/ring) | `static var cache: [RingKey: MeshResource]` keyed (radius, tube) quantized |
| Star field | one mesh + one material, N instances (or one entity w/ instancing if API allows at iOS 18) |
| Materials | per-category material built once from descriptor, stored on PlanetHandle; selection mutates a copy's emissive only |
| Link/trace | keep shared `linkMesh`; materials per relation kind cached by kind |

## 5. Lighting budget

Keep: key directional 2600 + rim 750 (`UniverseSceneController.swift:307-320`)
+ IBL (`CosmicEnvironmentTexture` 512×256, `:328-337`). Change: per-planet
PointLights (8 live today, `:162-167`) → budget of **3 live suns**: focused
planet + 2 nearest neighbors at full computed intensity; all others
intensity→0 (component mutation, light entity stays). Transitions lerp
intensity over ~0.4s — never rebuild lights. Focused-planet lighting emphasis
= its sun's `SunLightIntensity` focus tier (exists).

## 6. Background restraint

- Today: 120 individual star sphere entities (`addStars`
  `UniverseSceneController.swift:339-344`) + IBL speckle. Skybox + dust exist
  but unmounted (TestFlight square-star raster artifact, comment `:322-327`).
- Target: stars → shared mesh/material, count ~90, radius/opacity tiers as
  today; dust re-enable at 22 blobs (`GalaxyDustGeometry.dustCount`, opacity
  0.05) ONLY after device verification of the raster artifact; skybox
  re-enable gated the same way (verify on device, not sim).
- OLED: background stays near-black (`BrandColor.void` gradient), planet
  silhouettes carry the contrast; no bright particle field (brief).
- Depth haze: skip unless device testing shows planets float context-free —
  cheapest approximation is the existing IBL gradient + size attenuation.

## 7. Rotation & motion

- Mechanism: keep per-entity `FromToByAnimation` clips
  (`PlanetEntityFactory.swift:327-353`) — RealityKit-time-based, frame-rate
  independent, zero SwiftUI involvement (audit confirmed no per-frame body
  updates). A custom ECS System is NOT needed for uniform spin; revisit only
  if per-frame parametric motion (wobble) gets approved later.
- Speeds/tilts from descriptor (§2), applied at handle creation; selection
  restarts clip at ×0.6 speed.
- Reduce Motion: all clips gated (exists,
  `PlanetEntityFactory.swift:55,108,135,198`); fix the satellite
  inconsistency — pass `pauseMotion` not raw `reduceMotion`
  (`UniverseSceneController.swift:202,246`).
- Hidden renderer (2D active): pause all clips (power) — see
  UNIVERSE_ARCHITECTURE.md §Always-mounted.
