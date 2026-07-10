# Universe → RealityKit Redesign — Phase 1 Audit

Date: 2026-07-10 · Branch: `polish/day-sprint` · Scope: `ios-app/**` only.
Produced by 4 parallel read-only audits (rendering/hierarchy, state ownership,
camera/gestures, entities/visual/deployment). All citations are `file:line`
under `ios-app/Sources/MyAIMap/`.

## Verdict

**Refactor, not rewrite.** The live 3D path is already RealityKit
(`RealityView` + `PerspectiveCamera` + PBR + IBL), already has a persistent
scene controller, an authored deterministic layout, an interruptible camera
transition engine, and a single navigation source of truth. It fails the
"persistent planets" bar for exactly two structural reasons:

1. **Selection is baked into the scene-rebuild key.** `sceneSignature`
   includes `mode.signature` (`UniverseSceneController.swift:107-121`), so
   *every* selection/navigation change calls `clearDynamicChildren()`
   (`:137,359-363`) and rebuilds every planet/satellite/orbit/link from
   scratch. Entities have stable *names* (`planet:<id>`) but not stable
   *identity*.
2. **The RealityView is mounted inside the renderer switch**
   (`UniverseMapView.swift:59-81`), so toggling 2D↔3D tears it down; `makeScene`
   then forces a full rebuild via `sceneSignature = ""`
   (`UniverseSceneController.swift:53-54`, the G1 fix).

Fix those two and the current implementation *is* the persistent-RealityView
architecture the redesign asks for. Everything else is component-level polish.

## Baseline

- Last recorded green gate: **full-sim 434/434** (loop cycle 35, commit
  `56cda14`). Per-slice compile gate `scripts/ios-verify.sh --test-build-only`
  was green through cycle 37.
- **Local builds currently impossible:** `xcrun simctl list runtimes` is
  empty — no iOS platform/simulator runtime installed on this machine
  (Xcode 26.5 present, iOS 26.5 platform components missing; earlier-session
  AIMapGate sim is "runtime profile not found"). `ios-verify.sh
  --test-build-only` fails at destination resolution. Until a runtime is
  reinstalled (or CI is used as the gate), no phase can be build-verified
  locally. **This blocks the per-phase build requirement — user decision
  needed (runtime download ≈8–10 GB; disk has ~10 GiB free).**
- gh API was unreachable at audit time; re-check `gh run list
  --workflow=ios.yml` for the CI-side baseline when it recovers.
- Separate pre-existing critical (2D renderer, not RealityKit): Bloom
  force-sim tick-1 numerical blowup — root-caused and fixed in working tree
  (`BloomEngine.minRepelD2` clamp + regression test), commit pending a
  runnable gate. See LOOP_QUEUE §1.0.

## Current architecture

### View hierarchy (live)

```
RootShell.swift:162 → UniverseScreen (UniverseScreen.swift:9, passthrough)
 └─ UniverseMapView.body (UniverseMapView.swift:128)
     ├─ universeStack: ZStack (:56-107)
     │   ├─ switch model.renderMode (:58-82)     ← renderer switch
     │   │    ├─ .graph2D  → BloomGraphView       (:61)  DEFAULT
     │   │    └─ .spatial3D → UniverseRealityView (:69)  "Experimental"
     │   ├─ dim scrim (:85-88, hit-testing off)
     │   └─ UniverseOverlayView (:90-105)         ← all SwiftUI chrome
     ├─ iPad inspectorPanel RootSheet 360pt (:112-126)
     └─ sheets: detail / account / add-tool (:184-197)
```

`UniverseRealityView` = one `RealityView { make } update: { update }`
(`UniverseRealityView.swift:29-44`) + tap/drag/pinch gestures (`:45-91`) +
mode-driven `.opacity/.blur` (`:92-93`).

### Renderers — 2 live, 2 dead

| Renderer | File | Status |
|---|---|---|
| Bloom 2D (variant K) | `Universe/Bloom/BloomGraphView.swift` | **LIVE, default** (`UniverseViewModel.swift:24`) |
| 3D spatial | `Universe/UniverseRealityView.swift` | LIVE, `isExperimental` badge (`UniverseSelection.swift:56-58`) |
| `UniverseGraphView` (1083 lines) | `Universe/UniverseGraphView.swift` | **DEAD** — never mounted |
| `ConstellationView` (+`ConstellationLayout`) | `Universe/Constellation/` | **DEAD** — never mounted; `ConnectionResolver` from the same folder IS live (used by scene `:282` and Bloom) |

No `.id()` modifiers anywhere in the Universe module — remounts come only
from the renderer switch.

### State — single source of truth already exists

- `UniverseViewModel.universeMode: UniverseMode` (`UniverseViewModel.swift:15`)
  — enum `.overview / .branchFocus / .toolSelected / .detail / .chatOpen`
  (`UniverseMode.swift:8-13`). All selection/focus/category/presentation
  values are *projections* of it (`UniverseMode.swift:15-209`,
  `UniverseViewModel.swift:125-183`). `@Observable @MainActor`, no Combine.
- `renderMode` persisted via `UniverseStore` (`UniverseViewModel.swift:24-29`,
  `UniverseStore.swift:30-44`).
- `mode.signature` = cheap string diff key (`UniverseMode.swift:40-53`);
  consumed by BloomGraphView `.onChange` and (problematically) by
  `sceneSignature`.

**Duplication / conflicts found:**
- `BloomEngine.focusID` + reveal `stack` (`Bloom/BloomEngine.swift:34-45`) —
  2D-only parallel selection; one-way store→engine reconcile
  (`BloomGraphView.swift:98-104`); can diverge. Stays 2D-internal; must not
  leak into the 3D redesign.
- `Camera/CameraController.swift` — dead duplicate of the live rig (see below).
- `ViewMode` enum + `UniverseSelection.viewMode`
  (`UniverseSelection.swift:7-11,257-259`) — parallel overview/pocket/node
  vocabulary, never read by live code.
- `hoveredToolID` / `setHover` (`UniverseViewModel.swift:18,299-301`) — zero
  consumers, vestigial.
- `detailPresented` + `modeBeforeDetail` local mirrors in UniverseMapView
  (`:12-13`) — two-way synced, momentary conflict window.
- Interaction state fragmented across 3 owners: `CameraRigController
  .isTransitioning/.isInteracting`, `UniverseGestureController
  .dragInteracting/.pinchInteracting`, `BloomEngine.isSettled` — no unified
  interaction phase.

### Camera

- **Live:** `CameraRigController` (`CameraRigController.swift`) — spherical
  yaw/pitch/distance/target scalars (`:21-24`), writes one
  `PerspectiveCamera` transform (`UniverseSceneController.swift:14,37,53`).
  FOV 44°.
- Transitions: RealityKit `Entity.move(to:…timingFunction:)` with
  `CameraEasing.fly` = cubicBezier(0.16,1,0.30,1) (`CameraEasing.swift:8-15`),
  two-phase (0.15s ease-out pullback → main fly). Durations: category 1.05s,
  tool 0.68s, detail 0.32s, overview 1.12s.
- **Interruption is solid:** `transitionTask?.cancel()` + generation guard +
  `stopAllAnimations()` (`applyCamera` `:248-295`) — rapid A→B→C re-selection
  cancels cleanly mid-flight.
- **Gap:** gestures are hard-locked during transitions
  (`isTransitioning` guards, `UniverseRealityView.swift:49,63,70,85`) — no
  touch interruption of a fly-to.
- **Gap:** no dt-based inertia integrator; momentum = one-shot 0.42s
  `predictedEndTranslation` extrapolation (`:180-185`).
- **No camera FSM** — imperative verbs (`overview()/focus(…)/enterDetail`)
  driven by `focusCamera(for:)` translating `UniverseMode`
  (`UniverseMapView.swift:300-353`).
- **Dead:** `Camera/CameraController.swift` — never instantiated (only a doc
  comment + `CameraControllerTests.swift`); pre-cutover artifact (superseded
  by the galaxy-of-suns redesign commits).
- No proximity auto-enter in 3D (web-only concept). Live analog = yaw-based
  `NeighborSnap` after orbit settle (`NeighborSnap.swift:13-33`,
  `UniverseMapView.swift:411-420`).

### Gestures

Wired in `UniverseRealityView.swift:45-91`, bookkeeping in
`UniverseGestureController.swift`:
- Entity tap: `SpatialTapGesture().targetedToAnyEntity()` → parent-walk
  name-prefix resolution (`UniverseSceneController.swift:79-94`).
- Empty tap: simultaneous `TapGesture` + 80ms sleep + generation check
  (`UniverseGestureController.swift:71-81`) — time-based, not spatial.
- Drag: `DragGesture(minimumDistance: 4)` = tap-vs-drag threshold; orbit
  yaw/pitch mapping (`CameraRigController.swift:173-178`).
- Pinch: `MagnifyGesture`, base-distance capture, dolly clamp 6.2…28
  (`:192-202`). Drag+pinch nest via `activeGestureCount` (`:160-171`).
- Mode gate: `.detail/.chatOpen` disable map gestures
  (`UniverseMode.swift:109-116`).
- **Latent conflict surface:** no explicit gesture arbitration with chat
  scroll / iPad rail — relies on sibling hit-testing + mode gate only.

### Planet entities / visuals

- Factory: `PlanetEntityFactory.makePlanet` builds `planet-root:<id>` →
  surface + atmosphere + optional rim ring (`PlanetEntityFactory.swift:19-62`).
  Selection is *baked at build time*, not a component toggle.
- **Meshes NOT cached:** per-planet `generateSphere` ×2, per-satellite,
  per-halo, per-star (120!), per-orbit-ring torus regenerated
  (`:30,38,85,194,230,269-287`). Only `linkMesh` is shared (`:150`). Dust
  demonstrates the correct shared-mesh pattern but is unmounted
  (`GalaxyDustEntity.swift:38-46`).
- Rotation: per-entity `FromToByAnimation` spin/pulse/breathe (`:327-353`) —
  frame-rate independent, repeat mode, reduce-motion gated. **No RealityKit
  ECS `System` anywhere in the module.** Rotation speed/axis hardcoded
  (`:56`), no `axialTilt`/`rotationSpeed` in the descriptor.
- Descriptor: `PlanetData` (`PlanetData.swift:11-82`) has
  id/title/subtitle/color/position3D/radius/tools — missing rotationSpeed,
  axialTilt, material/atmosphere/ring sub-configs (factory literals instead).
- Layout: **fully authored + deterministic** — fixed angle table
  (`UniverseSpatialLayout.swift:147-171`), deterministic satellite trig,
  seeded LCG dust, index-hashed stars. Solid, keep as-is.
- Lighting: key directional 2600 + rim 750 + **up to 8 per-planet PointLights**
  (`SunLightIntensity` 500–5200) + IBL from procedural
  `CosmicEnvironmentTexture` (512×256 equirect,
  `UniverseSceneController.swift:307-337`). No post/bloom (emissive+additive
  halos fake glow).
- Background: `SkyboxEntity` + `GalaxyDustEntity` exist but are **unmounted**
  (TestFlight square-star raster artifact — comment `:322-327`). Live
  background = SwiftUI gradient + **120 individual star sphere entities**
  (`addStars` `:339-344`) + IBL speckle. Noisy-starfield risk: moderate.

### Deployment / a11y

- iOS 18.0 min (`project.yml:8-9`), Swift 6, strict concurrency. All RealityKit
  APIs used are ≥iOS 18-safe; single `#available(iOS 26)` gate is chrome-only
  Liquid Glass (`UniverseOverlayView.swift:564-570`).
- Reduce Motion: fully threaded (`UniverseRealityView.swift:17-26` →
  `prefersInstant`, spin/pulse gates). One inconsistency: `addSatellites`
  receives raw `reduceMotion` instead of `pauseMotion`
  (`UniverseSceneController.swift:202-203,246`) — satellites keep spinning in
  dimmed detail/chat.
- VoiceOver: only the *selected* node is described, via the overlay
  `PlanetInfoCard` (`PlanetInfoCard.swift:26-31,128-133`). No a11y traversal
  of 3D planets. Right rail deliberately `accessibilityHidden`
  (`RightUniverseRail.swift:62-64`).

## Components to PRESERVE (foundation of the redesign)

| Component | Why |
|---|---|
| `UniverseMode` + `UniverseViewModel.universeMode` | The single source of truth; renderer-agnostic; already drives all presentation |
| `CameraRigController` + `CameraEasing` | Interruptible, generation-guarded, Reduce-Motion-aware transition engine |
| `UniverseGestureController` | Thin correct gesture→rig bridge; tap disambiguation |
| `UniverseSceneController` container roots + persistent stars/lights/IBL pattern (`root.children.isEmpty` guards `:31-41,340`) | The model for how ALL entities should behave |
| `UniverseSpatialLayout` + `UniverseLayout` | Authored, deterministic, unit-tested layout math |
| `PlanetEntityFactory` builders | Entity construction (to be called once per id, not per rebuild) |
| `CosmicEnvironmentTexture` IBL rig | Restrained environment lighting |
| `UniverseOverlayView` / `PlanetInfoCard` / `SpatialRevealCard` / SearchDock / CategoryRail | Persistent SwiftUI chrome, renderer-agnostic, content swaps on selectedPlanetID |
| `NeighborSnap`, `OverviewLabelFocus`, `SunLightIntensity` | Pure mode-driven helpers |
| `ConnectionResolver` | Live relation derivation (used by 3D scene + Bloom) |
| BloomGraphView + BloomEngine | The live 2D default — untouched by this redesign |

## Components to REFACTOR

| Component | Change |
|---|---|
| `UniverseSceneController.sceneSignature` | Remove `mode.signature` + reduceMotion from the rebuild key; key on tool-set/style only. Selection → per-entity component mutation |
| `clearDynamicChildren` rebuild path | Replace with id→entity registry + diff (create missing, remove gone, mutate the rest: OpacityComponent, scale, light intensity, label state) |
| RealityView mount (`UniverseMapView.swift:59-81`) | Lift out of the renderer switch (always mounted, opacity/hidden-driven) so 2D↔3D stops destroying the scene |
| `PlanetEntityFactory` mesh/material allocation | Shared unit-sphere mesh + scale; torus cache by (radius,tube); material reuse; 120 stars → one shared mesh/material (copy dust pattern) |
| `PlanetData` | Extend into full PlanetDescriptor: rotationSpeed, axialTilt, materialStyle, atmosphereStyle, ringStyle (move factory literals into config) |
| Rotation | Hoist spin/pulse into one RealityKit `System` (or keep animation clips but descriptor-driven speeds/tilts); selected planet slows |
| Satellites reduce-motion arg | Pass `pauseMotion`, not raw `reduceMotion` (`UniverseSceneController.swift:202,246`) |
| Interaction state | Unify fragmented flags into one interaction-phase enum (idle/possibleTap/dragging/cameraAnimating/focused/overlayInteracting) owned next to the rig |
| Point-light budget | Cap simultaneous suns (focused + neighbors), fade others — 8 live PointLights is heavy on mobile GPUs |
| VoiceOver | A11y element list bridging planets (predictable order, non-gesture switching) |

## OBSOLETE — remove (timing-gated)

| Item | Gate |
|---|---|
| `Universe/UniverseGraphView.swift` (1083 lines, dead) | none — remove in hygiene slice |
| `Universe/Constellation/ConstellationView.swift` + `ConstellationLayout` | **gated:** LOOP_QUEUE 1.6 says keep until Bloom verified legible on device (Bloom fix in tree, unverified) |
| `Universe/Camera/CameraController.swift` + `CameraControllerTests.swift` | none — dead since galaxy-of-suns cutover |
| `ViewMode` enum + `UniverseSelection.viewMode` | with CameraController removal |
| `hoveredToolID`/`setHover` | none |
| Stale doc comments pointing at CameraController (`UniverseViewModel.swift:8`, `UniverseSelection.swift:3`) | with removal |

## Risks

**Rendering**
1. Any missed `sceneSignature` consumer after the diff refactor → stale scene
   (the inverse of today's G1 bug). Every mode-driven visual must be
   re-expressed as an in-place mutation.
2. Lifting RealityView out of the switch changes lifecycle timing —
   camera `attach` must run exactly once (`makeScene` currently re-attaches
   per mount, `UniverseSceneController.swift:53`).
3. Selection-baked geometry (rings, selected material) must become toggled
   components or the "no recreation on selection" criterion silently fails.
4. Skybox/dust re-enable is blocked by the TestFlight square-star raster
   artifact — needs a soft-sprite or texture fix, verify on device.

**Performance**
1. Rebuild storm today: every navigation reallocates all meshes+materials.
   The diff refactor removes this class entirely.
2. 120 individual star entities; 8 simultaneous PointLights; per-pixel
   CoreGraphics env-map on the scene-build path (one-time, main actor).
3. `@Observable` rig mutates during gestures → SwiftUI invalidation each
   event; label projection already deferred via `!isInteracting` guard
   (`UniverseOverlayView.swift:39`) — keep that pattern.

**Process**
1. **No local build/test capability until an iOS runtime is installed** (see
   Baseline). CI-only verification makes per-phase gates slow.
2. Shared machine (second autonomous loop) — heavy gates need clear windows
   (LOOP_QUEUE backpressure rules apply).
3. 434-test suite must stay green; renderer default stays `.graph2D` until
   the user flips it (product decision, not this redesign's call).

## Proposed migration phases (maps to the redesign brief)

Phase 1 — this audit + design docs (`UNIVERSE_ARCHITECTURE.md`,
`UNIVERSE_STATE_MACHINE.md`, `UNIVERSE_CAMERA_SYSTEM.md`,
`UNIVERSE_VISUAL_SYSTEM.md`, `UNIVERSE_QA_CHECKLIST.md`). No production code.

Phase 2 — Persistent foundation. Lift RealityView out of the renderer switch;
drop `mode.signature`/reduceMotion from `sceneSignature`; introduce id→entity
registry in `UniverseSceneController`; selection/mode → in-place component
mutations. Debug-only OSLog on scene init/entity create/selection/camera
(signposter already exists). Acceptance: 2D↔3D toggle and every selection
change leave entity identities intact (assert via registry pointer equality
in tests).

Phase 3 — Planet entity system. PlanetDescriptor extension; shared
mesh/material caches; descriptor-driven axial rotation (single System or
config-driven clips); selected-planet slow-down; collision shapes unchanged.

Phase 4 — Camera. Keep `CameraRigController` core; add the interaction-phase
enum; optional touch-interrupt of fly-to; A→B travel already works — tune
pullback/settle; interruption tests.

Phase 5 — Visual polish. Material system per descriptor style; point-light
budget; starfield → shared-mesh/soft sprites; skybox/dust re-enable behind
device verification; lighting transitions animated not rebuilt.

Phase 6 — SwiftUI integration. Persistent info card driven by
selectedPlanetID (already is); label fade by projected distance
(`OverviewLabelFocus` exists); safe-area/keyboard; matched-geometry only in
SwiftUI overlays.

Phase 7 — Performance + a11y. Profile (signposters exist); VoiceOver bridge;
Reduce-Motion QA matrix; lifecycle (leave/return Universe) tests; remove
debug noise from release.

## Open decisions (user)

1. **iOS runtime install** (~8–10 GB, ~10 GiB free) vs CI-only gates — blocks
   local per-phase verification either way it must be picked before Phase 2.
2. **Default renderer flip** (`graph2D` → `spatial3D`) — product call, out of
   scope until acceptance criteria pass on device.
3. **Dead-code removal timing** — UniverseGraphView + CameraController can go
   now; ConstellationView is gated on Bloom device verification.
