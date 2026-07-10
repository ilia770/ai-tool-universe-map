# UNIVERSE_ARCHITECTURE — RealityKit target architecture

Status: **Phase 1 design doc.** Ground truth: `UNIVERSE_REALITYKIT_AUDIT.md`
(2026-07-10, branch `polish/day-sprint`). Citations are `file:line` under
`ios-app/Sources/MyAIMap/`. No production code changes in this phase.

## Thesis

The audit's verdict stands: refactor, not rewrite. Two structural changes turn
the current implementation into the persistent-RealityView architecture:
(1) selection leaves the scene-rebuild key and becomes per-entity component
mutation via an id→entity registry; (2) the `RealityView` leaves the renderer
switch and stays mounted for the life of `UniverseMapView`.

## Before / after

### Current — rebuild-on-everything

```
UniverseMapView.body
 └─ ZStack
     ├─ switch model.renderMode (UniverseMapView.swift:59-81)   ← renderer switch
     │    ├─ .graph2D   → BloomGraphView            (torn down on toggle)
     │    └─ .spatial3D → UniverseRealityView       (torn down on toggle)
     │         └─ RealityView (UniverseRealityView.swift:29-44)
     │              make:   makeScene → cameraRig.attach (re-attach per mount)
     │              │        + sceneSignature = "" (G1 hack, :53-54 → forced rebuild)
     │              update: rebuildIfNeeded
     │                       └─ sceneSignature(mode, style, toolset, reduceMotion)
     │                           changed? → clearDynamicChildren() (:137,359-363)
     │                                      + rebuild EVERY planet/satellite/
     │                                        orbit/link from scratch
     ├─ dim scrim (:85-88)
     └─ UniverseOverlayView (:90-105)
```

Every selection, mode change, or 2D↔3D toggle destroys and recreates all
dynamic entities. Names (`planet:<id>`) are stable; object identity is not.

### Target — persistent scene, diffed registry

```
UniverseMapView.body
 └─ ZStack
     ├─ UniverseRealityView                          ← ALWAYS mounted
     │    │   dormant when renderMode == .graph2D:
     │    │   .opacity(0) + .allowsHitTesting(false) + .accessibilityHidden(true)
     │    │   + root.isEnabled = false + ambient clips paused
     │    └─ RealityView
     │         make:   makeScene — runs ONCE per surface life;
     │                 cameraRig.attach(camera) exactly once; G1 hack deleted
     │         update: apply(planets:mode:style:reduceMotion:)
     │                  ├─ structure key changed (toolset + style)? → diff registry
     │                  │    (create missing / remove gone / keep the rest)
     │                  └─ always → mutate(mode) in place on registry handles
     ├─ BloomGraphView   (mounted only when .graph2D — cheap SwiftUI, unchanged)
     ├─ dim scrim
     └─ UniverseOverlayView (persistent chrome, unchanged)
```

## Module responsibilities (brief name → existing type; adapt, don't duplicate)

| Brief name | Existing type (keep/extend) | File | Change |
|---|---|---|---|
| UniverseView | `UniverseMapView` | `Universe/UniverseMapView.swift` | Lift `UniverseRealityView` out of the renderer switch (:59-81) |
| UniverseViewModel / Store | `UniverseViewModel` + `UniverseStore` | `State/UniverseViewModel.swift`, `State/UniverseStore.swift` | None structural — stays the single source of truth |
| UniverseRealityView | `UniverseRealityView` | `Universe/UniverseRealityView.swift` | `update:` calls `apply(...)`; add dormant handling |
| UniverseSceneCoordinator | `UniverseSceneController` | `Universe/UniverseSceneController.swift` | Gains id→entity registry + diff/mutate paths; loses `clearDynamicChildren` rebuild loop |
| PlanetEntityFactory | `PlanetEntityFactory` | `Universe/PlanetEntityFactory.swift` | Split into create-once builders (selection-neutral) + mutators; shared mesh/material caches (Phase 3) |
| PlanetDescriptor | `PlanetData` (extended) | `Universe/PlanetData.swift` | Add `rotationSpeed`, `axialTilt`, `materialStyle`, `atmosphereStyle`, `ringStyle` — move factory literals (`PlanetEntityFactory.swift:56,244-249`) into config |
| UniverseCameraController | `CameraRigController` + `CameraEasing` | `Universe/CameraRigController.swift` | Keep core; attach-once; interaction-phase integration (Phase 4) |
| UniverseLightingController | **stays inside `UniverseSceneController`** | `UniverseSceneController.swift:301-337` | Decision: no new type. Lights are scene-graph children and mutations are one-line intensity writes; a separate controller adds indirection with no second consumer. Revisit only if Phase 5's point-light budget work grows past ~50 lines |
| UniverseInteractionController | `UniverseGestureController` + new `UniverseInteractionPhase` enum | `Universe/UniverseGestureController.swift` | New enum (idle / possibleTap / dragging / pinching / cameraAnimating / overlayInteracting) owned next to the rig; replaces the 3 fragmented flag owners (audit "State" §) |
| UniverseOverlayView | `UniverseOverlayView` | `Universe/UniverseOverlayView.swift` | None — already persistent, renderer-agnostic |

No parallel types. `PlanetDescriptor`, `UniverseSceneCoordinator` etc. are
*roles*, fulfilled by the existing names above.

## The id→entity registry

Owned by `UniverseSceneController`, replacing `clearDynamicChildren()` +
rebuild (`UniverseSceneController.swift:123-205`).

```swift
struct PlanetHandle {                     // one per PlanetData.id
    let root: Entity                      // "planet-root:<id>"
    let body: ModelEntity                 // "planet:<id>" (tap target)
    let atmosphere: ModelEntity
    let rim: ModelEntity                  // ALWAYS built; opacity/scale-toggled
    let sunLight: PointLight?             // nil for .core
    let coreLink: ModelEntity?            // "link:core-<id>", nil for .core
    var appliedSelection: Bool            // last applied — skip no-op mutations
}
private var planetHandles: [ToolCategoryId: PlanetHandle] = [:]
private var satelliteHandles: [String: SatelliteHandle] = [:]   // keyed by tool id
private var orbitRingHandles: [ModelEntity] = []                 // per style, rebuilt with style
```

### Diff algorithm (runs when the structure key changes)

1. **Desired sets:** planets = incoming `[PlanetData]` by id; satellites =
   focused category's tools when `mode.showsSatellites` (`UniverseMode.swift:55-65`),
   else empty.
2. **Create missing:** factory builds selection-*neutral* entities (no
   `isSelected` parameter baked in), insert handle, add to `planetRoot` /
   `satelliteRoot`.
3. **Remove gone:** `removeFromParent()`, drop handle. Only data changes
   (tool add/delete — the F3 case, `UniverseSceneController.swift:99-106`)
   remove planets; only focus changes swap the satellite population.
4. **Mutate the rest:** `mutate(mode:)` — component writes below, guarded by
   `appliedSelection`/last-applied caches so steady frames are no-ops.

`mutate(mode:)` also runs on *every* update where only `mode` changed — the
diff is skipped entirely because the structure key is unchanged.

### What mutates on selection / mode change

| Visual (today: baked at build) | Source | Target mutation |
|---|---|---|
| Planet opacity | `mode.planetOpacity` (`UniverseMode.swift:177-198`) | `OpacityComponent` write on `handle.root` |
| Planet scale 1.28× selected / 0.80× | `PlanetEntityFactory.swift:26` | animate `root.scale` (short `move(to:)`) |
| Planet material (tint/emissive/clearcoat) | `planetMaterial` (`:238-252`) | swap prebuilt selected/unselected material pair on `handle.body` |
| Selection rim ring | conditional build (`:44-53`) | always built; opacity + scale toggle |
| Sun light intensity 500–5200 | `SunLightIntensity.intensity(for:isFocused:)` | `sunLight.light.intensity` write (animated ramp in Phase 5) |
| Rotation speed 18s selected / 30s | `PlanetEntityFactory.swift:56` | restart spin clip with descriptor `rotationSpeed`; Phase 3 may hoist into one ECS `System` |
| Selected-atmosphere pulse | `:58` | play/stop clip on `handle.atmosphere` |
| Orbit-ring opacity | `mode.orbitOpacityMultiplier` (`UniverseMode.swift:155-166`) | material opacity write on `orbitRingHandles` |
| Core→category link fade | `UniverseSceneController.swift:182-194` | opacity write on `handle.coreLink` |
| Satellite opacity | `mode.satelliteOpacity` (`UniverseMode.swift:200-209`) | `OpacityComponent` write |
| Satellite selected visuals (scale/tint/emissive/halo/ring) | `PlanetEntityFactory.swift:77-106` | same handle pattern as planets |
| Orbit-shell opacity 0.42/0.28 | `UniverseSceneController.swift:230` | opacity write |
| Connection traces | `addConnectionTraces` (`:273-299`) | keyed sub-diff (`trace:<from>-<to>`); create/remove allowed — annotation entities, not identity-bearing |
| Ambient motion pause | `mode.pausesAmbientMotion` (`UniverseMode.swift:105-107`) | pause/resume animation playback — **not** a rebuild; also fixes the satellites `reduceMotion` vs `pauseMotion` bug (`UniverseSceneController.swift:202,246`) |
| Label state (planet/tool labels, anchor) | `showsPlanetLabels`/`showsToolLabels`/`showsToolAnchor` (`UniverseMode.swift:67-88`) | stays SwiftUI overlay-side (`UniverseOverlayView`) — zero scene work |
| Map opacity/blur/dim/gesture gate | `UniverseMode.swift:109-153` | already SwiftUI-side — unchanged |

**Invariant:** entity object identity survives any selection/mode change.
Absolute for planet handles; for satellite handles, absolute within a focused
category (branchFocus ↔ toolSelected ↔ detail ↔ chatOpen on the same
category) — changing the focused category swaps the satellite population by
design. Verified in tests via `ObjectIdentifier` equality across transitions
(audit Phase 2 acceptance).

## The rebuild key, after

`sceneSignature` (`UniverseSceneController.swift:107-121`) shrinks to the
**structure key** — only inputs that change *which entities exist*:

| Term | Stays? | Why |
|---|---|---|
| per-planet id + tool ids | **YES** | data changes create/remove entities (F3 fix preserved) |
| `visualizationStyle.rawValue` | **YES** | changes geometry radii / ring counts (`:346-356`); rare, settings-level |
| `mode.signature` | **NO** | every projection above becomes an in-place mutation |
| `reduceMotion` | **NO** | becomes animation playback control (pause/resume clips) |

`mode.signature` itself stays — `BloomGraphView` still consumes it (2D diff
key, out of scope). The G1 hack `sceneSignature = ""`
(`UniverseSceneController.swift:53-54`) is deleted: with an always-mounted
view there is no re-mount to defend against.

## Lifting RealityView out of the renderer switch

- `UniverseRealityView` moves out of `switch model.renderMode`
  (`UniverseMapView.swift:59-81`) into the base of the ZStack, always mounted.
  `BloomGraphView` stays conditionally mounted on top (cheap SwiftUI).
- **Dormant state** (renderMode == `.graph2D`): `.opacity(0)`,
  `.allowsHitTesting(false)` (Bloom must own all gestures),
  `.accessibilityHidden(true)`, scene `root.isEnabled = false`, ambient
  spin/pulse clips paused — extend the `pausesAmbientMotion` condition with
  "renderer dormant". A disabled root skips render + animation work, so the
  mounted-but-hidden view costs ~nothing; verify power in Phase 7 profiling.
- **Updates keep flowing while dormant** — the registry stays in sync via
  cheap component writes, so 2D→3D wake-up is instant and correct. On wake:
  re-enable root, resume clips, `focusCamera(for: mode, animated: false)`
  (the existing hook at `UniverseMapView.swift:171-175` already does this).
- **Camera attach-once:** `cameraRig.attach(camera)` runs in the `make`
  closure exactly once per surface life (today it re-attaches per mount,
  `UniverseSceneController.swift:53`). A second `makeScene` call becomes a
  debug assertion — see invariant I2.

## One source of truth

`UniverseViewModel.universeMode` (`State/UniverseViewModel.swift:15`) remains
the canonical navigation state (see `UI_STATE_MACHINE.md`). The scene is a
pure function of `(planets, universeMode, visualizationStyle)` — the
controller stores no navigation state, only handles and last-applied caches.

State DELETED (audit's obsolete list; timing gates apply):

| Item | Gate |
|---|---|
| `Universe/UniverseGraphView.swift` (1083 lines, dead) | none |
| `Universe/Camera/CameraController.swift` + `CameraControllerTests.swift` | none |
| `ViewMode` enum + `UniverseSelection.viewMode` (`UniverseSelection.swift:7-11,257-259`) | with CameraController removal |
| `hoveredToolID` / `setHover` (`UniverseViewModel.swift:18,299-301`) | none |
| Stale doc comments pointing at CameraController (`UniverseViewModel.swift:8`, `UniverseSelection.swift:3`) | with removal |
| `ConstellationView` + `ConstellationLayout` | **gated** on Bloom device verification (LOOP_QUEUE 1.6); `ConnectionResolver` stays — it is live |
| G1 hack `sceneSignature = ""` (`UniverseSceneController.swift:53-54`) | with Phase 2 |

## Phase plan

Phases 2–7 as specified in `UNIVERSE_REALITYKIT_AUDIT.md` §"Proposed migration
phases" — persistent foundation (2), planet entity system (3), camera (4),
visual polish (5), SwiftUI integration (6), performance + a11y (7). This doc
is the Phase 2 blueprint; details are not duplicated here.

## Risks & invariants

Risks: the audit's Risks section applies in full. The two this design adds or
sharpens:

1. **Missed signature consumer → stale scene** (inverse of G1): every
   projection in the mutation table above must be re-expressed as a mutation;
   a debug-build assertion that `apply(...)` output matches a from-scratch
   build (spot check via entity counts + opacity samples) guards regressions.
2. **Dormant-scene cost:** if `root.isEnabled = false` + paused clips still
   show idle GPU/power drain in Phase 7 profiling, the fallback is demand-gated
   updates while dormant (queue the last state, apply on wake) — not
   re-introducing the mount switch.

Invariants (hold across all phases):

- **I1 — No scene recreation on selection.** No `mode` term in the structure
  key; entity identity per the registry invariant above. Test: registry
  pointer equality across every `UniverseMode` transition.
- **I2 — No duplicate scene init.** `makeScene` runs once per controller
  life; the `root.children.isEmpty` guard (`UniverseSceneController.swift:31-41`)
  becomes an assertion, camera attach exactly once.
- **I3 — Deployment target stays iOS 18.0** (`project.yml:8-9`). Everything
  used here (`OpacityComponent`, `Entity.isEnabled`, animation playback
  control) is iOS-18-safe; no new availability gates.
- **I4 — `UniverseViewModel.universeMode` has exactly one writer**; the scene
  controller never mutates navigation state.
- **I5 — Default renderer stays `.graph2D`**; BloomGraphView and BloomEngine
  are untouched by this redesign. `BloomEngine.focusID` must not leak into
  the 3D path.
- **I6 — 434-test suite stays green** per phase (gate strategy per the
  audit's open decision #1).
