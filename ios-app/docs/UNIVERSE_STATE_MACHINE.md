# UNIVERSE_STATE_MACHINE — navigation + interaction phases (RealityKit redesign)

Date: 2026-07-10 · Branch: `polish/day-sprint` · Phase 1 design doc, companion
to `UNIVERSE_REALITYKIT_AUDIT.md` and `UI_STATE_MACHINE.md`. Citations are
`file:line` under `ios-app/Sources/MyAIMap/`.

## 1. Navigation machine — `UniverseMode` (unchanged by the redesign)

Five cases (`UniverseMode.swift:8-13`), single writer
`UniverseViewModel.universeMode` (`UniverseViewModel.swift:15`); the view reads
an alias only (`UniverseMapView.swift:27`). All presentation is projected off
the enum (`UniverseMode.swift:55-209`). The redesign changes *consumers*, never
the machine.

```
overview ──tap planet──► branchFocus ──tap tool──► toolSelected ──re-tap / Details──► detail
   ▲                       │   ▲                      │   ▲                              │
   │◄─empty tap / core tap─┘   └─────empty tap────────┘   └────────sheet dismiss─────────┘
   │                            (steppedBack)                    (→ steppedBack)
   └──chat dismiss (no ctx) · resetUniverse · deleteTool-fallback

{overview | branchFocus | toolSelected} ──focus chat input──► chatOpen
chatOpen ──dismiss / empty tap──► toolSelected(ctx) | branchFocus(ctx) | overview
```

| From → To | Trigger | Call site |
|---|---|---|
| overview → branchFocus(c) | tap planet / rail category | `selectCategory` `UniverseMapView.swift:214` → `model.selectCategory` `UniverseViewModel.swift:255-261` |
| any navigable → toolSelected(c,t) | tap tool node; search ⏎; chat chip | `focusToolFromMap` `UniverseMapView.swift:241` → `model.focusTool` `UniverseViewModel.swift:272`; `focusFirstSearchMatch` `:308` |
| toolSelected → toolSelected(c′,t′) | tap another tool (lateral, direct) | same `focusToolFromMap` path |
| branchFocus(A) → branchFocus(B) | tap another planet; yaw settle snap | `selectCategory`; `maybeSnapToNeighborSun` `UniverseMapView.swift:411-420` |
| toolSelected → detail | re-tap selected tool/planet; Details button; chat "open detail" chip | `focusToolFromMap:243-246` / `selectCategory:216-218` → `presentDetail` `:368-379`; `requestToolDetail` `UniverseViewModel.swift:293` → `consumePendingDetailRequest` `UniverseMapView.swift:358-366`; `openToolDetailFromChat` `:253-262` |
| detail → toolSelected | sheet dismiss (swipe-down = iOS Escape); model leaves `.detail` (e.g. deleteTool) | `onChange(detailPresented)` `UniverseMapView.swift:176-183`; mirror `:167-169` |
| toolSelected → branchFocus | empty-space tap (3D step-up walk) | `handleEmptySpaceTap` `:292-294` → `steppedBack` `UniverseMode.swift:216-227` |
| branchFocus → overview | empty tap; core planet tap | `handleEmptySpaceTap:295-297` → `resetToOverview` `:274-284` |
| navigable → chatOpen(ctx) | chat input focused | `setChatOpen` `UniverseMapView.swift:381-392` → `chatContext` `UniverseMode.swift:230-243` |
| chatOpen → prior ctx | chat dismiss; empty tap while chat open | `restoreNavigationMode` `:394-403` (fallback `navigationModeForSelection` `:405-409`); `handleEmptySpaceTap:288-289` |
| toolSelected → branchFocus/overview | selected tool deleted | fallback in `deleteTool` `UniverseViewModel.swift:464-467` |
| any → overview | reset universe | `resetUniverse` `UniverseViewModel.swift:245` |

Escape-equivalents on iOS: empty-space tap (one `steppedBack` step), sheet
swipe-down (detail), chat dismiss. No keyboard path.

## 2. NEW — unified `InteractionPhase` enum

Today interaction state is fragmented across three owners with no single
answer to "may this gesture run now": `CameraRigController.isTransitioning`
(`CameraRigController.swift:25`) / `.isInteracting` (`:30`),
`UniverseGestureController.dragInteracting`/`pinchInteracting`
(`UniverseGestureController.swift:10-11`), plus per-gesture guards repeated in
`UniverseRealityView.swift:49,63,70,85`.

```swift
enum InteractionPhase: Equatable {
    case idle              // navigable mode, camera at rest, no touch
    case possibleTap       // touch down, movement < tapSlop, intent unresolved
    case dragging          // drag and/or pinch owns the camera
    case cameraAnimating   // programmatic fly-to in flight
    case focused           // selection landed, camera settled on target
    case overlayInteracting// detail/chat sheet owns input; map gated off
}
```

Owner: `CameraRigController.phase` (it already owns both camera flags; the
gesture controller becomes the sole *requester* via `beginInteraction`/
`endInteraction` `CameraRigController.swift:160-171`). Single writer, observable
so the overlay keeps its `!isInteracting` label-projection gate
(`UniverseOverlayView.swift:39`) as `phase != .dragging`.

### Mapping today's flags → phases

| Phase | Today's fragment | Notes |
|---|---|---|
| `idle` | implicit (all flags false, `mode.allowsMapGestures`) | |
| `possibleTap` | implicit: `DragGesture(minimumDistance: 4)` slop (`UniverseRealityView.swift:68`) + 80 ms empty-tap sleep / 0.18 s entity-tap window (`UniverseGestureController.swift:71-81`) | becomes an explicit phase, not two timers |
| `dragging` | `isInteracting` + `dragInteracting`/`pinchInteracting` | one phase covers drag, pinch, and nesting (`activeGestureCount` `CameraRigController.swift:39,160-171` stays as the internal refcount) |
| `cameraAnimating` | `isTransitioning` (`:25`, set/cleared `:265,289,293`) | |
| `focused` | implicit: `.toolSelected`/`.branchFocus` + camera settled | entry point for `NeighborSnap` (`UniverseMapView.swift:411`) and label re-projection |
| `overlayInteracting` | `mode.allowsMapGestures == false` (`UniverseMode.swift:109-116`) | mode-derived; pinned while `.detail`/`.chatOpen` |

### Gesture legality per phase

| Gesture | idle | possibleTap | dragging | cameraAnimating | focused | overlayInteracting |
|---|---|---|---|---|---|---|
| Entity tap (select) | ✓ | resolves | ✗ | **✓ NEW** (retarget) | ✓ (re-tap → detail) | ✗ |
| Empty tap (step back) | ✓ | resolves | ✗ | ✗ ignored | ✓ | chat: ✓ dismiss (`UniverseRealityView.swift:63`); detail: ✗ |
| Drag (orbit) | ✓ | escalates ≥ tapSlop | ✓ | **✓ NEW** interrupt (§7) | ✓ | ✗ |
| Pinch (dolly) | ✓ | escalates | ✓ (nests) | **✓ NEW** interrupt (§7) | ✓ | ✗ |

**During `cameraAnimating`, nothing is queued — latest intent wins.** Entity
taps retarget immediately (generation guard cancels the old fly, §7). Empty
taps are *ignored*, not deferred: a mid-fly step-back is ambiguous and a queued
one would fire after landing, teleporting the user. This matches the existing
last-writer-wins generation pattern (`CameraRigController.swift:256-258`).

**Tap-vs-drag threshold ownership:** the 4 pt slop, 80 ms empty-tap defer, and
0.18 s entity-tap window become named constants next to `InteractionPhase`
(`tapSlop`, `emptyTapDefer`, `entityTapWindow`), consulted only by
`UniverseGestureController` — no more literals split between the view
(`UniverseRealityView.swift:68`) and the controller
(`UniverseGestureController.swift:74,76`).

## 3. Phase × Mode matrix

Seed = `mode.allowsMapGestures` (`UniverseMode.swift:109-116`): map gestures
live in overview/branchFocus/toolSelected, dead in detail/chatOpen.

| Phase \ Mode | overview | branchFocus | toolSelected | detail | chatOpen |
|---|---|---|---|---|---|
| idle | ✓ | ✓ | ✓ | – | – |
| possibleTap | ✓ | ✓ | ✓ | – | ✓ (empty-tap dismiss only) |
| dragging | ✓ | ✓ | ✓ | – | – |
| cameraAnimating | ✓ | ✓ | ✓ | ✓ (fly to detail frame, `enterDetail` `CameraRigController.swift:123`) | ✓ (fly to chat frame `:143`) |
| focused | – | ✓ | ✓ | – | – |
| overlayInteracting | – | – | – | ✓ pinned | ✓ pinned |

## 4. Selection flow — tap → store → fan-out

**Today (rebuild path):**
```
tap entity → target(from:) name-walk (UniverseSceneController.swift:79-94)
 → onToolTap → focusToolFromMap (UniverseMapView.swift:241) → model.focusTool (UniverseViewModel.swift:272)
 → universeMode mutates, fan-out:
    ├─ onChange(universeMode) → focusCamera (UniverseMapView.swift:161,300-353)   [keep]
    ├─ overlay/chips/rail re-render off projections                                [keep]
    └─ RealityView update → sceneSignature differs (mode.signature at
       UniverseSceneController.swift:114) → clearDynamicChildren (:137) → FULL REBUILD  [remove]
```

**After the redesign:** the first three hops are byte-identical — tap
resolution, handler, store mutation all stay. Only the scene's consumption
changes: `update` diffs `mode` against the id→entity registry and applies
**component mutations**, creating/destroying nothing:

| Mode projection | In-place mutation |
|---|---|
| `planetOpacity` / `satelliteOpacity` (`UniverseMode.swift:177-209`) | `OpacityComponent` per entity |
| `isPrimaryPlanet` (`:168-175`) | selected ring/scale toggle (today baked at build, `PlanetEntityFactory.swift:19-62`) |
| `orbitOpacityMultiplier` (`:155-166`) | orbit ring material alpha |
| `showsSatellites` / label flags (`:55-88`) | satellite opacity 0 (not removal), label state |
| `pausesAmbientMotion` (`:105-107`) | pause/resume animation clips |
| focused category | `SunLightIntensity` ramp on point lights |

Entity creation/removal happens only when the tool-set part of the key changes
(add/delete tool). Acceptance: registry pointer-equality across any
selection-only change (audit Phase 2).

## 5. Fate of `mode.signature`

- **KEPT for 2D Bloom:** `BloomGraphView` uses it as a cheap `.onChange` diff
  key (`BloomGraphView.swift:64` → `syncEngineFocus` `:98-104`). Unchanged.
- **REMOVED from `sceneSignature`:** the 3D rebuild key
  (`UniverseSceneController.swift:107-121`) drops `mode.signature` *and*
  `reduceMotion`; new key = visible tool set per planet + `visualizationStyle`
  only. Reduce Motion becomes a pause/resume mutation, not a rebuild. The
  stale doc-comment on `pausesAmbientMotion` (`UniverseMode.swift:100-104`,
  "the scene already rebuilds on entering these modes") must be rewritten with
  this change.

## 6. State to delete / fold

| Item | Verdict |
|---|---|
| `ViewMode` enum + `UniverseSelection.viewMode` (`UniverseSelection.swift:7-11,257-259`) | **Delete.** Never read by live code; dies with dead `Camera/CameraController.swift`. |
| `hoveredToolID` / `setHover` (`UniverseViewModel.swift:18,299-301`) + `UniverseSelection.hoveredToolID` (`UniverseSelection.swift:253`) | **Delete.** Zero consumers; also drop from the `selection` projection (`UniverseViewModel.swift:134`). |
| `detailPresented` (`UniverseMapView.swift:13`) | **Fold into the model.** Replace with a derived `Binding` — get: `mode.isDetailOpen`; set-false: `model.universeMode = mode.steppedBack`. Kills the two-way sync (`:167-169` + `:176-183`) and its momentary conflict window. Model-driven exits (deleteTool) dismiss the sheet for free. Sheet-swap sites (`presentAccount` `:428-435`, `presentAddTool` `:445-452`) write the model instead of the flag. |
| `modeBeforeDetail` (`UniverseMapView.swift:12`) | **Delete.** Every live writer stores `.toolSelected(cat, tool)` (`presentDetail:374-376`, `openToolDetailFromChat:256`, `openRelatedToolFromDetail:267`), which is exactly `detail(cat, tool).steppedBack` (`UniverseMode.swift:222-223`). Dismiss → `steppedBack`; no saved state needed. |
| `accountPresented` / `addToolPresented` (`:14-15`) | **Stay local.** Chrome sheets, not navigation modes — per the global-vs-local rule in `UI_STATE_MACHINE.md`. |

## 7. Interruption semantics

- **Rapid re-selection during `cameraAnimating` — keep as-is.** The generation
  guard (`transitionTask?.cancel()` + `transitionGeneration` + guarded sleep
  continuations, `CameraRigController.swift:256-295`) already makes A→B→C
  retargeting cancel cleanly. New: drop `!cameraRig.isTransitioning` from the
  entity-tap guard (`UniverseRealityView.swift:49`) so taps *retarget mid-fly*
  instead of being swallowed.
- **Drag/pinch during transition — today locked out**
  (`UniverseRealityView.swift:70,85` + internal guards
  `CameraRigController.swift:174,193`). **Decision: allow touch interruption.**
  On `possibleTap → dragging` while `cameraAnimating`: cancel the transition
  task, `stopAllAnimations()`, then **read the camera's live transform back
  into yaw/pitch/distance/target** before the first pan frame. The readback is
  mandatory: rig scalars jump to *destination* values at fly start (`focus(on:)`
  `:93-101` mutates scalars, then animates the transform), so grabbing the
  camera without syncing scalars teleports it. Ship the interrupt with a
  `syncScalars(fromTransform:)` helper + interruption tests; until that helper
  lands, the drag lock stays (interim = today's behavior).
- **Empty tap during `cameraAnimating`:** stays ignored (§2 — never queued).

## 8. Rules for the 2D Bloom renderer

1. `BloomEngine.focusID` + reveal `stack` (`BloomEngine.swift:35-36`) are
   **renderer-local** reveal/physics state, not navigation. They stay.
2. **One-way store→engine sync stays:** `.onChange(of: mode.signature)` →
   `syncEngineFocus` (`BloomGraphView.swift:64,98-104`) — follow the selection
   only toward already-revealed nodes, never re-issue a held focus.
3. **The engine never writes the store.** The only path back is a user tap →
   `onToolTap`/`onPlanetTap`/`onEmptyTap` callbacks (`BloomGraphView.swift:14-16`)
   into the same `UniverseMapView` handlers as 3D (§1). Breadcrumb/collapse is
   engine-internal until it surfaces as one of those taps.
4. The `InteractionPhase` enum is **3D-only**. Bloom keeps `isSettled`
   (`BloomEngine.swift:45`) internally; its gesture gate remains
   `mode.allowsMapGestures` (`BloomGraphView.swift:52`).
