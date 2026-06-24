# Spatial Universe — Increment 2: Atmosphere & Material (Design)

Date: 2026-06-23
Status: Design (roadmap-approved in Increment 1 spec); proceeding to plan
Scope: iOS app (`ios-app/`), `.spatial3D` render path only

## Context

Increment 1 (branch `feat/spatial-universe`, READY TO MERGE) delivered the spatial spine: galaxy of suns + tool-planets, hybrid nav, selected-only reveal, near-zero chrome. Increment 2 makes it feel *expensive* — the visual language from the product vision: deep black space, soft volumetric lighting, glass panels, minimal typography, large negative space, spatial depth, premium motion.

Still north-star Track A: only `.spatial3D` changes; 2D stays default and untouched.

## What Increment 2 delivers

1. **Calm volumetric lighting.** Fix the two Increment-1 open items: sun `PointLight`s currently emit full intensity regardless of mode, so dimmed neighbor suns still cast full light and all 8 lights burn in overview. Lighting should follow the same focus hierarchy as the meshes — the focused system is lit, the rest recede.
2. **Selected-only glass reveal.** Principle 4 ("only selected planet reveals detailed information"). In 3D, focusing a tool-planet currently shows no inline info (the 2D info card is hidden). Add a single floating **glass reveal card** for the focused tool: minimal typography (name, category, one-line), large negative space, one primary action ("Open" → existing full detail). No card in overview/sun-focus.
3. **Deeper space.** Deep-black background, restrained starfield/dust with parallax depth so the galaxy sits in real space, not on a flat panel.
4. **Premium planet material.** Tune planet/sun PBR (roughness, clearcoat, metallic, emission falloff) so bodies read as glass-and-light, not flat spheres.

## Design decisions (defaults — flag to redline)

- **Lighting model:** per-mode intensity scales with the same `UniverseMode` focus hierarchy used for mesh opacity. Focused sun's light at full; non-focused suns' lights dimmed; in overview all suns share a lower ambient level so the galaxy glows softly without blowing out. Pure helper `SunLightIntensity.intensity(for:isFocused:)`, unit-tested.
- **Reveal card:** floating glass card pinned low-center, above the Ask-AI dock, shown only in `toolSelected` (3D). Tapping it (or its "Open") routes to the existing detail path. It is the *only* added chrome; overview/sun-focus stay bare.
- **Typography:** SF Rounded, minimal — title + faint category + one-line summary. Reuse `LiquidGlass` so it matches the system.
- **Starfield/dust:** tune existing `SkyboxEntity` / `GalaxyDustEntity` / stars — do not add new heavy layers (perf). Reduce density, deepen black, keep subtle parallax.

## Scope boundaries (hard)

- Only `.spatial3D`. 2D untouched. No data-model change. No new product features.
- No new navigation behavior (that was Increment 1). Reveal card routes to the *existing* detail surface.
- Motion/detail-panel *refinement* (physical/expensive easing, full panel polish) is Increment 3 — Increment 2 adds the reveal card and material/light, not a motion overhaul.

## Success criteria

- Focused system is clearly lit; non-focused suns recede; overview glows softly without blow-out. (On-device / sim-with-delay screenshot.)
- Focusing a tool-planet reveals a minimal glass card; overview and sun-focus show no card. Tapping it opens full detail.
- Background reads as deep space with subtle depth, not a flat gradient.
- Planets read as premium glass-and-light.
- 2D unchanged; `npm run ios:verify` build + unit + smoke stay green.

## Risks

- RealityKit renders black for the first seconds in the iOS Simulator; visual verification uses the populated-universe + `spatial3D` plist + delay + screenshot method, real device as source of truth.
- Lighting tuning is taste; pure helper makes the *rule* testable, but final values need an eyeball.
