# Universe → RealityKit Redesign — Camera System

Date: 2026-07-10 · Branch: `polish/day-sprint` · Phase 1 design doc (no code).
Companion to `UNIVERSE_REALITYKIT_AUDIT.md`. Citations are `file:line` under
`ios-app/Sources/MyAIMap/Universe/` unless noted. Ground truth: the LIVE
controller is `CameraRigController.swift`; `Camera/CameraController.swift` is
dead (§9).

## 1. Camera modes

One explicit mode enum, owned next to the rig (the audit's unified
interaction-phase enum). The existing imperative verbs stay as the *inputs*;
the enum formalizes state the rig already tracks in two booleans
(`isTransitioning` `CameraRigController.swift:25`, `isInteracting` `:30`).

| Mode | Entered by (existing verb) | Today's equivalent | Status |
|---|---|---|---|
| `overview` | `overview()` `:52-57`, `returnToOverview()` `:153-155`, `reset()` `:87-91` | landed, target `.zero`, distance 21.4 | rename |
| `browsing` | `focus(on: planet)` `:93-101` / `focus(category:)` `:59-61`, landed | landed on a sun; NeighborSnap active (§6) | rename |
| `focusing` | any verb while flight in progress | `isTransitioning == true` (`applyCamera` `:264-290`) | rename |
| `focused` | `focus(on:around:)` `:103-121`, `enterDetail` `:123-141`, `enterChat` `:143-151`, landed | landed on a tool/detail/chat pose | rename |
| `returning` | `overview()` flight in progress | indistinguishable from `focusing` today | **NEW semantics** — split so interruption policy can differ (§4b: any tap during `returning` retargets) |
| `userControlled` | `beginInteraction()` `:160-163` (drag/pinch) | `isInteracting == true` | rename; **NEW edge**: reachable *from* `focusing` via touch-interrupt (§4b) — today impossible |

Mapping: `isTransitioning` → `focusing`/`returning`; `isInteracting` →
`userControlled`. Everything else is a rename of behavior that already exists;
only `returning` (as a distinct state) and the `focusing → userControlled`
edge are new. `UniverseMode` stays the navigation source of truth; camera mode
is derived per-flight, never drives navigation.

## 2. Travel path

Four phases; the first three exist verbatim in `applyCamera` (`:248-295`).

| Phase | Spec | Status |
|---|---|---|
| Departure | 0.15 s ease-out pullback, 0.72 units along the retreat direction from current transform (`:267-276`) | exists — keep |
| Travel | `move(to:)` with `CameraEasing.fly` = cubicBezier(0.16, 1, 0.30, 1) (`CameraEasing.swift:9-14`), duration = total − 0.15, floor 0.1 (`:283`) | exists — keep |
| Deceleration | the curve tail: both bezier control points have y = 1, giving a long expo-out decel that lands at ~zero velocity | exists (implicit) — keep, no separate phase |
| Arrival settle | **recommend: keep none** | see below |

**Settle recommendation — none.** The expo-out tail already arrives at zero
velocity, so a spring would only add overshoot — risky next to the distance
clamp floor (§5) and the eye y-floor (`:301`). There is also already a
de-facto settle beat: `isTransitioning` clears ~0.20 s *after* visual landing
(sleep is `duration + 0.05` measured from main-move start, which runs
`duration − 0.15`; `:283-289`), which is when labels re-project
(`UniverseOverlayView.swift:38-40`). A second `move(to:)` settle would extend
that window further and delay label return. Revisit only if device QA reads
the landing as abrupt.

### Per-transition durations (existing values = baseline)

| Transition | Total | Source |
|---|---|---|
| Category (→ browsing) | 1.05 s | `transitionDuration` `:17`, used `:100` |
| Tool (→ focused) | 0.68 s | `toolTransitionDuration` `:18`, used `:120` |
| Detail | 0.32 s | `detailTransitionDuration` `:19`, used `:140` |
| Chat | 0.32 s | reuses detail duration `:150` |
| Overview return | 1.12 s | literal `:56` |
| Momentum settle (finishPan) | 0.42 s | `:184` |
| Pinch-button zoom step | 0.24 s | `zoom(delta:)` `:189` |

## 3. A→B travel between planets (KEPT core)

The interruptible flight engine in `applyCamera` (`:248-295`) is the kept
foundation — do not rewrite it:

1. `transitionTask?.cancel()` `:256` — kills the pending phase-2/completion task.
2. `transitionGeneration += 1` `:257` — stale tasks are fenced at both awaits (`:279`, `:288`).
3. `camera.stopAllAnimations()` `:259` — halts the in-flight `move(to:)`.
4. `zoomBaseDistance = nil` `:263` — a fly-to drops a stale pinch base.
5. Pullback recomputes from the *current* transform (`:267-274`), so an A→B
   retarget departs from the mid-flight position — no teleport.

**Completion / label-timing contract:**
- Rig scalars (yaw/pitch/distance/target) are set to the *destination* by the
  verb **before** the flight starts; `projection(for:in:)` (`:208-246`) reads
  scalars, so labels project from the landed pose — intentional (they settle
  around the focus, `UniverseOverlayView.swift:33-40`).
- `isTransitioning` flips true synchronously at flight start (`:265`) and
  clears at t ≈ total + 0.20 s, only if the generation still matches (`:288-289`).
  Labels (and today's gestures) unlock at that moment. Any FSM must preserve
  this ordering: scalars first, flag second, labels last.
- No completion callbacks exist or are needed — consumers observe
  `isTransitioning` via `@Observable`.

## 4. Interruption policy

**(a) New selection during flight — cancel + retarget. Exists, keep.** The §3
sequence handles it; entity taps are currently *blocked* mid-flight though
(`UniverseRealityView.swift:49`) — see (b).

**(b) Touch during flight — today hard-locked, propose drag-interrupt.**
Guards: `UniverseRealityView.swift:49,63,70,85` and rig-side `pan` `:174`,
`finishPan` `:181`, `zoom(magnification:)` `:193`.

Proposal (brief: "interrupt an active camera movement and select another
planet safely"):
- **Entity tap mid-flight → retarget.** Lift the `isTransitioning` guard on
  the `SpatialTapGesture` only (`UniverseRealityView.swift:49`). This is just
  case (a) triggered by touch — already proven safe. Empty tap stays blocked
  (accidental deselect mid-flight is worse than a 1 s wait).
- **Drag mid-flight → cancel + hand to user** after translation exceeds
  ~12 pt (deliberately above the 4 pt tap-vs-drag minimum so a brush doesn't
  kill a flight). On trigger: cancel task, bump generation,
  `stopAllAnimations()`, then **re-derive yaw/pitch/distance from the actual
  camera transform** (keep the flight's `target`; scalars currently hold the
  destination, not the interpolated pose — handing off without re-deriving
  would snap the camera to the destination). Enter `userControlled`.
- Risk: the eye y-floor `max(3.2, …)` (`:301`) makes the eye function
  non-invertible at low pitch — clamp derived pitch to −0.16…0.72 (the pan
  clamp `:176`) and accept a one-frame ≤ floor correction. Verify on device;
  ship behind the FSM so it can be gated off if derivation jitters.

**(c) Rapid repeated selection — generation guard proof.** Each `applyCamera`
increments `transitionGeneration` (`:257`); both awaits recheck it (`:279`,
`:288`) and `Task.isCancelled`; `stopAllAnimations()` halts the previous move.
So N selections in quick succession leave exactly one live flight (the last)
and `isTransitioning` cannot be cleared by a stale task. Keep the existing
rapid A→B→C behavior as a regression test target (Phase 4 interruption tests).

## 5. Safe framing

| Rule | Mechanism | Status |
|---|---|---|
| Min/max distance | clamp 6.2…28 (`:14-15`) in every verb (`:95,117,137,145`) and both zooms (`:188,200`) | exists — keep |
| Distance formulas | category `r·6.8+5.0` `:95`; tool `r·6.0+4.6` `:117`; detail `r·7.8+5.8`, floor min+1.2 `:137`; chat `r·8.2+7.0`, floor min+2 `:145` | exists — keep; these keep neighboring suns in frame (NeighborSnap depends on it) — do not shrink |
| Viewing-angle preservation | yaw bias off the sun bearing: +0.24 category `:99`, +0.18 tool `:119`, +0.22 detail `:139`, +0.28 chat `:148` — focused planet keeps curvature, never a "flat centered coin" | exists — keep |
| Pitch ladder | overview 0.26 `:55`, category 0.24 `:97`, tool 0.20 `:118`, detail 0.18 `:138`, chat 0.22 `:146`; eye y-floor `max(3.2, …)` `:301` | exists — keep |
| No clipping through planets | **NEW — target-path validation:** at flight start, test the segment (pullback eye → landing eye) against planet bounding spheres (`position3D`, `radius` + ~0.6 margin). On hit, deepen the pullback beyond 0.72 / raise pitch for that flight. A validation + fallback, not a spline system. | propose (Phase 4) |

## 6. Gesture map

Wired in `UniverseRealityView.swift:45-91`; bookkeeping in
`UniverseGestureController.swift`. Mode gate: `allowsMapGestures`
(`UniverseMode.swift:109-116`).

| Gesture | Wiring | Rig effect |
|---|---|---|
| Entity tap | `SpatialTapGesture().targetedToAnyEntity()` (`UniverseRealityView.swift:46-59`) → name-prefix resolve (`UniverseSceneController.swift:79-94`) | selection → `focusCamera(for:)` (`UniverseMapView.swift:300-353`) |
| Empty tap | simultaneous `TapGesture` + 80 ms generation check (`UniverseGestureController.swift:71-81`) | stepped-back navigation |
| Drag | `DragGesture(minimumDistance: 4)` high-priority → `pan(delta:)` gains 0.0062/0.0038, pitch clamp −0.16…0.72 (`:173-178`) | direct orbit, unanimated |
| Drag end | `finishPan` one-shot 0.42 s from `predictedEndTranslation` (`:180-185`, `UniverseGestureController.swift:28-37`) | momentum — keep as-is |
| Orbit settled | `onOrbitSettled` → `maybeSnapToNeighborSun` (`UniverseMapView.swift:411-420`), `NeighborSnap.snapTarget` threshold 0.28 rad (`NeighborSnap.swift:13-33`) | **keep — this is the browsing affordance** (3D analog of web proximity-enter) |
| Pinch | `MagnifyGesture` → `zoom(magnification:)`, base-distance capture, clamp 6.2…28 (`:192-202`); drag+pinch nest via `activeGestureCount` (`:160-171`) | direct dolly, unanimated |

**dt-based smoothing: not justified.** Pan applies event deltas directly and
momentum is a single time-parameterized `move(to:)` — both frame-rate
independent by construction (§8). A dt integrator would introduce the
per-frame update loop this module deliberately lacks (no ECS `System`).
Revisit only if device QA shows drag judder; do not gold-plate.

## 7. Reduce Motion

`prefersInstant` (`:32-36`) is set from `accessibilityReduceMotion` OR
`-uitestStatic` (`UniverseRealityView.swift:17-26,94-97`). `applyCamera`
collapses `animated` (`:250`) to the instant branch (`:291-294`): transform
set directly, `isTransitioning` never raised.

| Interaction | Standard | Reduce Motion |
|---|---|---|
| Selection fly (category/tool/detail/chat) | pullback + fly | instant cut — same destination pose |
| Overview return | 1.12 s sweep | instant cut |
| Momentum (`finishPan`) | 0.42 s glide | instant (`animated && !prefersInstant`) |
| Drag / pinch | direct, unanimated | unchanged |
| NeighborSnap | fires after settle | still fires; resulting focus is an instant cut |

No sweeping arcs under Reduce Motion; every destination remains reachable —
functionality preserved, only motion removed. Keep instant (vs a short
cross-move): it matches shipped behavior and XCUITest quiescence depends on no
transition Tasks running (`:32-35`).

## 8. Frame-rate independence

- All animated camera motion is RealityKit `move(to:duration:timingFunction:)`
  — time-parameterized, identical wall-clock on 60/120 Hz. Keep.
- No per-frame SwiftUI mutation for the camera: rig scalars mutate per gesture
  *event*, not per frame; no CADisplayLink, no `System`.
- Label re-projection deferred while transitioning/interacting via the
  `labelsQuiescent` guard (`UniverseOverlayView.swift:38-40`) — keep; it is
  what makes `@Observable` rig mutation affordable during gestures.
- Momentum is one predicted shot, not integration — no dt dependency to break.

## 9. Removal targets

| Item | Notes |
|---|---|
| `Universe/Camera/CameraController.swift` | dead — never instantiated (audit-confirmed; pre-galaxy-of-suns artifact) |
| `CameraControllerTests.swift` | tests the dead controller only |
| `ViewMode` enum + `UniverseSelection.viewMode` (`UniverseSelection.swift:7-11,257-259`) | parallel overview/pocket/node vocabulary, never read by live code |
| Stale doc comments (`UniverseViewModel.swift:8`, `UniverseSelection.swift:3`) | point at the dead controller |

No gate — removable in the Phase 2/hygiene slice (audit "OBSOLETE" table).
