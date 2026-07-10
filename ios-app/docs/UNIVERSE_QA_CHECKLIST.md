# Universe RealityKit — QA Checklist

Date: 2026-07-10 · Phase 1 design doc. Maps the redesign brief's 17
acceptance criteria to executable checks. Baseline: 434/434 unit tests
(commit `56cda14`). Verification constraint: iOS simulator runtime was
missing on this machine at audit time (reinstall in progress) — items marked
**[sim]** need it; **[device]** need real hardware; **[unit]** run anywhere
Swift builds.

## Manual QA sequence (run per phase 4+, full run before flip/release)

1. Launch app → Universe. **Assert (debug log): exactly one "scene init".**
2. Switch to 3D Spatial. Overview: all 9 planets visible, rotating slowly,
   distinct silhouettes, background calm (no bright noise). **[sim]**
3. Watch 10s: rotation continuous, no hitching; labels legible. **[sim]**
4. Tap planet A (e.g. Design): camera flies (pullback → travel → settle),
   min distance respected, neighbors still visible, info card updates at
   arrival. **[sim]**
5. Mid-flight tap planet B: flight cancels cleanly, retargets; no snap, no
   state corruption (criterion 9/10 of the brief). Repeat 5× fast. **[sim]**
6. A→B travel: same scene, both planets alive throughout (watch A while
   flying to B — it must keep rotating). **[sim]**
7. Return to overview (empty tap / back): same camera animates back; planets
   unchanged. **Assert: zero "entity created" logs since step 2.** **[sim]**
8. Toggle 2D↔3D ×3: **assert no new "scene init" / "entity created" logs**
   (persistent RealityView criterion 5/13). **[sim]**
9. Drag from a planet: must orbit, NOT select (threshold check, criterion
   10). Drag then release with flick: momentum settles, neighbor snap OK. **[sim]**
10. Pinch: dolly clamps (no clipping through planets — criterion 8). **[sim]**
11. Open detail sheet → close; open chat → close: map dims/undims via
    opacity only; on return, entities unchanged. **[sim]**
12. Leave Universe tab → return: no duplicate scene init (criterion 13). **[sim]**
13. VoiceOver: planets reachable in predictable order, labeled, selectable
    without gestures (criterion 15 prerequisite). **[sim]**
14. Reduce Motion ON: transitions instant/short, no sweeping arcs, all
    functionality intact; rotations paused. **[sim]**
15. Add a tool via AddToolSheet: only that category's satellites diff; other
    planets' entity identity intact (registry log). **[sim]**
16. Frame profile (Instruments, signposters exist in scene/Bloom): steady
    frame time in overview + during travel; memory flat across 10 A→B
    cycles (no leak from clip restarts). **[device]**
17. TestFlight visual pass: star raster artifact check (blocks skybox/dust
    re-enable — `UniverseSceneController.swift:322-327`), OLED black levels,
    thermal after 5 min. **[device]**

## Automated tests

| Test | Kind | Phase | Notes |
|---|---|---|---|
| Existing 434 suite | [unit] | every | must stay green |
| `sceneSignature` excludes mode/reduceMotion | [unit] | 2 | string-compose test |
| Registry pointer equality across mode changes | [unit] | 2 | build scene, cycle overview→branch→tool→detail→overview, assert `===` per handle root |
| Registry diff: add/remove tool id | [unit] | 3 | only affected handles change |
| Descriptor determinism | [unit] | 3 | same id → same visual descriptor across calls |
| Mesh cache hit | [unit] | 3 | two planets share sphere `MeshResource` instance |
| Camera generation-guard interruption | [unit] | 4 | exists pattern (`CameraRigControllerTests` if present) — extend: cancel mid-flight retarget |
| InteractionPhase transitions | [unit] | 4 | legal-transition table from UNIVERSE_STATE_MACHINE.md |
| Sun-light budget (≤3 live) | [unit] | 5 | intensity table for N planets |
| Satellite pauseMotion fix | [unit] | 2 | regression for `UniverseSceneController.swift:202,246` |
| Bloom sim bounded from coincident seed | [unit] | landed | `simStaysBoundedFromCoincidentSeed` (in tree, pending gate) |

## Per-phase gates

| Phase | Gate |
|---|---|
| 2 Persistent foundation | compile gate + registry/pointer + signature tests green; manual steps 1,7,8,12 clean |
| 3 Planet entities | + descriptor/cache/diff tests; manual 2,3,15 |
| 4 Camera | + interruption/phase tests; manual 4,5,6,9,10 |
| 5 Visual polish | manual 2,3 re-pass + 17 on device (skybox/dust gated) |
| 6 SwiftUI integration | manual 11,13 (labels/overlays); a11y labels test |
| 7 Perf + a11y | manual 13,14,16,17 full; Instruments capture attached to PR |

Gate commands (once runtime installed): per-slice
`bash scripts/ios-verify.sh --test-build-only`; boundary
`--run-tests --device-id <AIMap sim>` (LOOP_QUEUE backpressure rules apply —
shared machine).

## Blocked-until list

- All **[sim]** items: iOS runtime install (in progress this session).
- All **[device]** items: physical iPhone + signing (Apple Developer team id
  pending per project memory) — TestFlight phase.
- Skybox/dust re-enable: device raster verification (17).
- Renderer default flip: user decision after full manual pass.
