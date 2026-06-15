# Claude Code Backlog — 50 Tasks

Last updated: 2026-06-11. **Phase A COMPLETE** (1–10: #47 #48 #52 #54); 12 fixed (#53); 39 audited (#49). Owner: Claude Code.

Living backlog executed in parallel with Codex. Every task stays inside
Claude's ownership lanes (`ios-app/**`, `src/components/AIToolUniverse3D/**`,
visual QA, Claude-side docs) per `docs/AGENT_OPERATING_MODEL.md`. Codex lanes
(`AIToolUniverseMap.tsx`, `src/index.css`, `src/data/**`, classifier, release
docs) are off-limits here; overlaps go through `docs/AGENT_STATUS.md` first.

Rules of engagement:

- One slice = one branch = one PR ≤ ~400 lines, worktree-isolated.
- Verify gate per slice: iOS → full `xcodebuild test` on the ClaudeGate
  simulator (`4E244EB6-52EB-4AD6-B4E4-4C28F2921DEE`); web → `npm run
  typecheck && npm run lint && npm test && npm run build` (+ visual smoke
  when the scene changes).
- Status legend: `[ ]` todo · `[~]` in progress · `[x]` merged.
- Tasks within a phase are ordered; phases A–C are sequential for iOS,
  phases D–F can interleave any time the simulator / dev server is free.

> **Review top-10 in progress (2026-06-14):** NEW-1 iPad fix #59, NEW-2 seed port #58,
> NEW-4 connected-to #60, NEW-7 dim+exit #61, NEW-5/6/8/9/10 + iOS CI (this PR). Backlog
> 15/16 (PocketTransition + persistent scene) landed #55. Remaining review items: NEW-3
> web url backfill (Codex data lane), backlog 23/26 labels (Phase C pull-forward),
> backlog 34 iOS CI (this PR), 35/36 perf baseline.

> **Полное мультиагентное ревью 2026-06-12:** `docs/reviews/2026-06-12-full-project-review.md`
> (9 ролей, 90 находок, 24 P1, 0 опровергнутых). P1: iPad-шит блокирует карту, iOS-сид 12/49
> инструментов, анонимные сферы без подписей/связей, тупиковая карточка инструмента,
> «No public link» у 26 реальных продуктов. Топ-10 действий — в отчёте; выполнять ПЕРЕД Phase C.

## Phase A — finish Phase 2 (`docs/PHASE_2_PLAN.md` steps 6–8)

1. `[x]` **SearchDock core** — pure `SearchCore` matcher (prefix + substring
   + category-name match, ranked, Foundation-only) + Swift Testing suite.
2. `[x]` **SearchDock UI** — `UI/Search/SearchDock.swift`: liquid-glass top
   dock, debounced query field, ranked result rows, keyboard avoidance,
   reduce-motion variants.
3. `[x]` **SearchDock wiring** — view-model `searchQuery` / `focusTool` glue:
   Enter focuses first match, tapping a row opens the tool's category pocket
   and selects it; haptic on commit.
4. `[x]` **RootSheet with 3 detents** — `UI/Sheets/RootSheet.swift` replacing
   the inline bottom sheet; `.fraction` detents, grabber, glass material.
5. `[x]` **ToolDetailSection** — full tool card inside the sheet: what it is,
   why it matters, stage badge, links; parity with web right panel content.
6. `[x]` **CategoryRail extraction** — move the chip rail into
   `UI/Sheets/CategoryRail.swift` with its own preview + snapshot-friendly
   layout.
7. `[x]` **ClarityMenu** — focus / context / atlas mode switcher (web F/C/A
   parity) wired through the view model.
8. `[x]` **Pocket readout overlay** — SwiftUI overlay "Pocket world · N tools
   expanded" when a pocket is open (deferred from slice 3).
9. `[x]` **Haptics wiring pass (step 8)** — proximity enter/exit, search
   commit, sheet detent changes, clarity switches; all through `BrandHaptics`,
   no double-fires with `PressableButtonStyle`.
10. `[x]` **Phase 2 closeout** — AGENT_STATUS + PHASE_2_PLAN checkboxes,
    deviations log, CHANGELOG entry.

## Phase B — gestures + camera feel

11. `[ ]` **Drag-to-orbit** — `DragGesture` → yaw/pitch on CameraController
    (clamped pitch, inertia), gesture priority after `SpatialTapGesture` per
    the decision log.
12. `[x]` **Fix mid-pinch auto-enter jump** — known follow-up: accumulated
    magnification re-applies after proximity auto-enter; reset baseline on
    mode change + regression test.
13. `[ ]` **Dolly-to-cursor** — pinch zooms toward the gesture centroid
    (web `dollyToCursor` parity), not the screen center.
14. `[ ]` **Double-tap focus** — double-tap a node → camera fly-to + select;
    double-tap empty space → overview reset.
15. `[x]` **PocketTransition lerp helpers** — `Camera/PocketTransition.swift`
    easing between overview/pocket/node framings (replaces snap), pure-math
    core + tests.
16. `[x]` **Persistent scene container** — remove `.id(selectedCategory)`
    full rebuild: keep one scene, move entities on category change so spins,
    fades and cooldowns survive transitions (unlocks real PocketTransition).
17. `[ ]` **Camera feel tuning pass** — smoothTime/clamps side-by-side vs web
    on device, document final constants in the design README.

## Phase C — iOS Phase 3 visual parity

18. `[ ]` **ConnectionLines entity** — core→category→tool lines (thin
    unlit quads or LowLevelMesh), confidence-weighted opacity, pocket-aware
    emphasis.
19. `[ ]` **StarField port** — instanced star points (two size/brightness
    tiers), idle-mounted after first frame to protect launch time.
20. `[ ]` **GalaxyDust port** — sparse large translucent sprites drifting
    slowly; reduce-motion static.
21. `[ ]` **Sparkles in pocket** — particle field inside the open pocket
    (RealityKit particle emitter), count/scale parity with web Sparkles.
22. `[x]` **Shell breathing + yaw sway** — `ShellBreathingSystem` +
    `ShellBreathingComponent` drive the ±1.8 % wobble and yaw sway on the
    pocket-shell root; pure `ShellBreathing` curve (web-cadence sin), tagged
    only when reduce-motion is off (#77).
23. `[ ]` **CategoryRingEntity** — proper orbit ring + billboarded category
    label around each anchor (web CategoryRing parity).
24. `[ ]` **Node hover/selection pulse** — selected-node emissive pulse via
    transform/emissive animation, reduce-motion static highlight.
25. `[~]` **Tool monogram textures** — SUPERSEDED by 26. Texture-mapping
    letters onto spheres distorts and fights the PBR look; billboarded tool
    labels (26, the canonical web approach) deliver node identifiability
    crisply. Revisit only if labels prove insufficient at far distance.
26. `[x]` **Billboarded tool labels** — `makeToolLabel` billboarded
    `generateText` entities per pocketed tool, spawned/removed with the
    pocket; `ToolLabelFadeSystem` + pure `ToolLabelFade` curve fade them by
    camera distance so the overview stays uncluttered (#78).
27. `[ ]` **Founder core hero treatment** — layered core: inner emissive
    sphere + outer frosted shell + slow pulse; matches "hero node" brief.
28. `[x]` **Scene background depth** — `SkyboxEntity` inverted-sphere shell
    (r=300, beyond the star field) textured with the shared
    `CosmicEnvironmentTexture` equirectangular map so backdrop and IBL
    reflections agree; UnlitMaterial, gradient kept as fallback (#74).
29. `[x]` **IBL / environment lighting** — `EnvironmentResource` image-based
    lighting so PBR materials get real reflections (#72). Procedural
    `CosmicEnvironmentTexture` replaces the deferred bundled-`.exr` assumption;
    skybox backdrop (28) still pending, can now reuse the same env map.
30. `[ ]` **Reduce-motion + contrast audit (iOS)** — sweep every animation
    and material for `accessibilityReduceMotion` / contrast; matrix table in
    docs/design.
31. `[ ]` **VoiceOver entity accessibility** — AccessibilityComponent labels
    /hints/traits on every tappable entity; rotor-friendly ordering.

## Phase D — iOS infrastructure + release readiness

32. `[ ]` **Snapshot test harness** — deterministic UniverseScreen snapshot
    tests (SwiftUI ImageRenderer or xcresult attachments) for chrome layouts.
33. `[ ]` **XCUITest flow tests** — launch → tap category → pocket opens →
    tap tool → sheet shows; search → Enter → focus. Runs on ClaudeGate sim.
34. `[ ]` **iOS CI workflow** — GitHub Actions macOS job: xcodegen +
    build-for-testing + test-without-building; cache DerivedData; PR-gated.
35. `[ ]` **Performance profile pass** — signposts + Instruments run on
    device-class sim: frame time during pocket open, entity counts, texture
    memory; budget table in docs/perf-ios.md.
36. `[ ]` **Launch experience** — launch screen, app icon set (brandkit
    cosmic mark), first-frame time measurement.
37. `[ ]` **Build automation script** — `ios-app/scripts/gate.sh` wrapping
    xcodegen + split build/test with simulator health checks (the
    BUILD INTERRUPTED lesson, encoded).
38. `[ ]` **TestFlight dry run** — archive locally with placeholder signing,
    walk `ios-app/TESTFLIGHT_CHECKLIST.md`, file gaps as issues (no upload —
    needs the user's Apple Developer team id).

## Phase E — web 3D scene (Claude lane: `AIToolUniverse3D/**`)

39. `[x]` **Pocket-shell web/iOS diff audit** — side-by-side screenshots,
    reconcile drift both directions, document canonical constants in one
    table both ports reference.
40. `[ ]` **Hover-label overlap hardening** — stress-test label collisions at
    tablet/mobile widths in the 3D scene; fix worst offenders.
41. `[ ]` **Scene render-cost pass** — memo/instancing audit of Scene.tsx
    children, drei `Detailed`/LOD where it pays; before/after FPS trace.
42. `[ ]` **Camera transition easing polish** — overview↔pocket↔node
    transitions: tune damping/offsets, kill end-of-flight jitter.
43. `[ ]` **Search fly-to parity** — verify Enter-to-focus framing matches
    the iOS implementation (task 3); shared constants doc.
44. `[ ]` **Mobile touch UX audit** — pinch/rotate/tap targets on real
    mobile viewport; fix dead zones; Playwright mobile project assertions.
45. `[ ]` **Visual smoke expansion** — Playwright specs for: pocket open via
    proximity, search focus, clarity modes, reduced-motion render (Codex
    lane 1 overlaps — coordinate via AGENT_STATUS before touching
    `tests/visual-smoke.spec.ts`).

## Phase F — docs, QA, hygiene

46. `[ ]` **PHASE_3_PLAN.md** — author the Phase 3 plan (tasks 18–31 scoped
    into slices with verify gates) once Phase A merges; review with Codex via
    PR.
47. `[ ]` **Design README update** — PBR material system, lighting rig,
    motion language, haptic map: the "premium cosmic liquid glass" spec in
    implementation terms for iOS.
48. `[ ]` **Visual QA rubric run** — full desktop/tablet/mobile + iOS sim
    screenshot set against `docs/design/README.md` rubric; findings filed as
    tasks.
49. `[ ]` **Branch hygiene** — list merged remote branches for the user to
    delete (deletion is permission-blocked for agents), prune local
    worktrees, verify no stray dirty files in shared checkout.
50. `[ ]` **Release review dry run** — run the release-review checklist
    against the iOS app + web scene before any TestFlight/production push;
    stop-ship findings → tasks.

## Coordination with Codex

- Codex's standing lanes (from `docs/CLAUDE_PARALLEL_TASKS.md`, inverted):
  visual-QA spec file, TestFlight docs, product docs, data QA. Tasks 38/45/50
  touch shared files — announce in AGENT_STATUS before starting.
- Render-path decision (2026-06-11): RealityKit is canonical for
  `UniverseView` — see AGENT_STATUS. Tasks here build on it.
- Heavy machines resources (simulator, Playwright) are serialized: only one
  agent runs them at a time.
