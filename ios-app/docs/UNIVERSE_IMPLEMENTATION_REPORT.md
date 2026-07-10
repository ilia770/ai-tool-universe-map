# Universe RealityKit Redesign — Implementation Report

Date: 2026-07-10 · Branch: `polish/day-sprint` (pushed) · Commits `62c3daa…HEAD`.
Companion to the Phase-1 docs (AUDIT / ARCHITECTURE / STATE_MACHINE /
CAMERA_SYSTEM / VISUAL_SYSTEM / QA_CHECKLIST).

## Architecture: before → after

| Concern | Before | After |
|---|---|---|
| Scene lifecycle | RealityView mounted inside `switch renderMode` — torn down on 2D↔3D toggle; G1 hack (`sceneSignature=""`) forced full rebuild per mount | ALWAYS mounted (opacity/hitTesting gate); camera attaches once; G1 hack deleted |
| Selection/mode change | `sceneSignature` included `mode.signature` → `clearDynamicChildren()` rebuilt every planet/satellite/orbit/link | `structureSignature` = style + tool ids ONLY; selection = component mutations on persistent entities |
| Planet entities | Rebuilt from scratch each change (`makePlanet(isSelected:)`) | `PlanetHandle` registry — created once per category id, mutated (scale/materials/rims/spin/sun/opacity) |
| Satellites | Torn down on ANY mode change incl. tool selection | `SatelliteBranch` persists per focused category; tool selection mutates (`SatelliteHandle`); traces transient |
| Meshes | ~250+ `generateSphere` + per-ring torus regen per rebuild | 1 shared unit sphere + torus cache by (radius,tube) + 4 star material tiers |
| Motion | Uniform hardcoded spin (30s/18s), fixed axis | `PlanetVisual` descriptors: deterministic per-category duration + axial tilt (FNV-hash fallback for custom branches); selection ×0.6 |
| Materials | Uniform roughness/metallic | Per-category PBR surfaces (VISUAL_SYSTEM §2 table), one rendering language |
| Interaction state | Fragmented flags (isTransitioning / isInteracting / drag / pinch) | `InteractionPhase` single derivation (overlay > cameraAnimating > dragging > pinching > idle) wired into all gesture guards |
| 2D-default launch cost | Paid nothing (3D never mounted) → after lift would pay full boot | Dormancy: camera-only root until first 3D activation; hidden scene pauses all clips |
| A11y | Reduce Motion only; planets invisible to VoiceOver | + VO bridge: ordered virtual children per planet, tap-free selection |

## Files

**Added:** `Universe/PlanetHandle.swift` (handle + `PlanetVisual` descriptors),
`Universe/SatelliteBranch.swift` (branch + `SatelliteHandle`),
`Universe/InteractionPhase.swift`,
`Tests/UniverseSceneRegistryTests.swift`, `Tests/InteractionPhaseTests.swift`.

**Modified:** `UniverseSceneController.swift` (registry diff, structure-only
signature, applyMode mutations, lazy static layer, style invalidation),
`UniverseRealityView.swift` (`isActive`, phase guards, VO bridge),
`UniverseMapView.swift` (always-mounted 3D), `PlanetEntityFactory.swift`
(caches, exposed helpers, legacy builders removed), `UniverseMode.swift`
(comment), `BloomGraphView.swift`/`BloomEngine.swift` (2D fixes, separate
track), `UniverseGestureController.swift` (read-only flags),
`State/UniverseViewModel.swift` + `UniverseSelection.swift` (dead state
removed), signature tests rewritten.

**Removed (dead / superseded):** `UniverseGraphView.swift` (1083L),
`Camera/CameraController.swift` (+tests), `Constellation/ConstellationView.swift`
+ `ConstellationLayout.swift` (+tests), `ViewMode`, `hoveredToolID/setHover`,
legacy `makePlanet`/`makeSatellite` builders. Net −2000+ lines of dead code.

## How the contracts hold

- **Entity identity:** `UniverseSceneRegistryTests` asserts pointer equality of
  every planet root across all 7 nav modes, renderer toggles, and scoped
  structural diffs; same for satellites within a focused category.
- **Camera:** unchanged `CameraRigController` core — two-phase fly
  (0.15s pullback → `CameraEasing.fly` expo-out), generation-guarded
  cancellation on rapid re-selection, `prefersInstant` under Reduce Motion.
- **Rotation:** RealityKit `FromToByAnimation` clips (time-parameterized,
  frame-rate independent, zero SwiftUI churn); restarted only on
  selection/pause change; paused in detail/chat, when hidden behind 2D, and
  under Reduce Motion (incl. the satellite pauseMotion fix).
- **Interruption:** selection mid-flight cancels + retargets (existing
  generation guard, kept). Touch-interrupt of fly-tos: designed in
  UNIVERSE_CAMERA_SYSTEM.md, DEFERRED to device testing (sim can't synthesize
  real touch).
- **Adversarial review:** codex pass over the Phase-2 diff — 4/6 hunt targets
  clean (selection parity math independently confirmed); 2 findings fixed
  (style-change handle invalidation; true dormancy for the static layer).

## Verification

- Suite: **403/403** green on AIMapGate (26.5) at HEAD; every slice gated
  compile + full suite before commit.
- Visual (sim screenshots, `ios-app/screenshots/loop/rk-phase2/`):
  overview planets/halo/rings/links/labels (02), design-branch focus with
  satellites + selection + traces (03), RK.5 material differentiation (04).
- Known cold-boot artifact: first 3D mount on a fresh runtime = ~40s
  PSO/shader compile storm (one-time, not a hang).

## Remaining limitations / follow-ups

1. Device-only checks pending (TestFlight): touch-interrupt decision, gesture
   feel (13/17 Phase-B tail), skybox/dust re-enable (square-star raster
   artifact), Instruments frame/memory profile, VO on-device pass.
2. Camera-mode enum naming (overview/browsing/focusing/…) not materialized as
   a type — behavior already matches; introduce if/when touch-interrupt lands.
3. Sun-light budget (max 3 live suns) from VISUAL_SYSTEM §5 not yet enforced
   (8 suns live in overview as before).
4. Renderer default stays `.graph2D` — flip is a user/product decision after
   the on-device pass.
5. Manual QA sequence (QA_CHECKLIST §Manual) requires interactive taps —
  XCUITest or device session.

## Manual QA (exact sequence)

Run `UNIVERSE_QA_CHECKLIST.md` §Manual steps 1–17. Sim-able today: 1–3, 7–8,
11–12, 15 (via container-plist renderMode flip + `-uitestSampleUniverse`).
Device-only: 4–6, 9–10, 13–14, 16–17.
