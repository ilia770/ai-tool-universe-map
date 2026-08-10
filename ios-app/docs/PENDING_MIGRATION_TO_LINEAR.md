# Не перенесённое в Linear

Собрано 2026-08-09 при удалении `ios-app/docs/LOOP_QUEUE.md`. Это всё, что
оставалось незакрытым в той очереди на момент её удаления; сам файл удалён в
том же коммите, история в git.

**Оговорка к решению.** Удаление было принято из расчёта «семь открытых
слайсов» — столько их в воркстриме WS-DS. Фактически незакрытых пунктов
оказалось **30, в одиннадцати воркстримах**. Перенесены все: терять 23 пункта
из-за неточности в счёте было бы неправильно.

**Ни один пункт не проверен против текущего кода.** Очереди от трёх до пяти
недель, и часть работы за это время сделана другими путями либо отменена
решениями от 2026-08-09 — в частности, разворот 3D → 2D отложен, а вместе с
ним теряют смысл пункты про RealityKit и Bloom. Проверять по одному — работа
для `/day-plan`, а не для переноса.

**Срок.** Как только Linear подключён, первый прогон разбирает этот файл:
подтверждённое становится issue, отменённое вычёркивается, файл удаляется. Он
не должен пережить разбор — иначе это просто ещё одна MD-очередь под другим
именем.

Ссылка на исходный файл и строку под каждым пунктом, чтобы поднять контекст из
git-истории.

---

## WS-DS — Design-system cleanup workflow (USER DIRECTIVE 2026-07-15, TOP PRIORITY)

- [ ] DS.3 Universe chrome spacing sweep — align map top route controls, bottom card/dock clearance, empty state actions, and inspector spacing through tokens. Files: `UniverseMapView`, `UniverseOverlayView`, `PlanetInfoCard`; do not touch SearchDock internals.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:159`</sub>
- [ ] DS.4 Chat/SearchDock glass cleanup — remove nested/manual glass, reconcile send/add/attach button recipes, keep input focus from driving map blackout, and preserve local-vs-global state boundaries from `UI_STATE_MACHINE.md`. Owning spec: `INPUT_CHAT_SPEC.md`.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:163`</sub>
- [ ] DS.5 Sheets cleanup — Add Tool, Tool Detail, Root Sheet, Account/Settings: normalize section rhythm, segmented controls, keyboard-safe action bars, and product-card density. Own specs: `ADD_TOOL_SPEC.md`, `TOOL_DETAIL_SPEC.md`, `SETTINGS_PROFILE_SPEC.md`.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:167`</sub>
- [ ] DS.6 Accent discipline sweep — remove saturated category fills, borders, shadows, and glows outside deliberate labels/glyphs/status dots. Use neutral surfaces and small accent markers. Needs screenshots before/after.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:171`</sub>
- [ ] DS.9 RealityKit retirement/quarantine decision — inventory live references to `UniverseRealityView` / `UniverseSceneController`, decide whether to delete, quarantine behind a future flag, or keep for a later user-reviewed 3D rebuild. No destructive deletion without explicit user approval.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:184`</sub>
- [ ] DS.10 Final QA matrix — run build gate, focused unit tests, UI smoke, screenshot set, and human visual review queue. Update `QA_REGRESSION_CHECKLIST.md` with what passed and what still needs TestFlight/device review.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:189`</sub>

## WS10 — Design-system audit (user: "перепроверить каждую деталь по дизайн-системе")

- [ ] 10.c **DEFERRED — appearance-changing, NEED USER'S EYE** (from the audit, workers listed them per surface in the workflow journal). The 3 systemic P1 themes to review together: 1. **Glass architecture** — 9 surfaces hand-roll glass (raw .ultraThinMaterial + manual stroke, black backing plates, glass-on-glass nesting, deprecated liquidGlass shim) → route through LiquidGlassCard/glassSurface. Biggest systemic defect; changes material/edge/shadow look everywhere. 2. **Accent > 0.12 cap** — 9 surfaces use category/accent as saturated fills/ tints/strokes/glows (OVERVIEW pill fill, selected-chip 0.64 border, 0.4 tints, colored shadows) → confine accent to label/glyph/status-dot. Changes the selected/primary look. 3. **Touch targets + primary-action recipe + category-rail 48pt overflow** — sub-44pt controls (floor LiquidGlassButton), Send/FAB/CTA recipe disagree, rail frame can't fit its 44pt chip. Layout/size changes. Screenshots: onboarding clean after fix in `screenshots/loop/design-after/`.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:232`</sub>

## WS-NU — NEURAL UNIVERSE (USER DIRECTIVE 2026-07-10 evening, TOP PRIORITY)

- [ ] NU.5 Polish vs web-O + perf sanity (entity budget) + reduce-motion matrix + screenshot set for user review.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:290`</sub>
- [ ] NU.6 Docs closeout: implementation report update, LOOP_LOG, memory.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:292`</sub>

## WS-RK — RealityKit Universe redesign (USER DIRECTIVE 2026-07-10, top priority)

- [ ] RK.4 Phase 4 — camera modes + InteractionPhase + touch-interrupt decision.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:359`</sub>
- [ ] RK.5 Phase 5 — visual polish (materials table, light budget, starfield; skybox/dust re-enable device-gated).  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:360`</sub>
- [ ] RK.6 Phase 6 — SwiftUI overlays/labels integration.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:362`</sub>
- [ ] RK.7 Phase 7 — perf + a11y (VoiceOver bridge, RM matrix) + `UNIVERSE_IMPLEMENTATION_REPORT.md`.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:363`</sub>

## WS1 — Bloom 2D map (the new default renderer) — FRONTIER

- [ ] 5.3 **STALE TEST:** `MyAIMapUITests` smoke harness fails — waits for "RootShell.ShowChat" Button (+ chat-composer-field) that recent UI renamed/ removed (63s timeout). It's NOT a required CI check but blocks scripted screenshot capture. Update the harness element ids/flow to the current UI.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:428`</sub>
- [ ] 1.1old Snapshot baseline of Bloom in overview + one bloomed branch on the 26.5 sim; confirm it renders (not blank), no clipping, taps select. Save to `ios-app/screenshots/loop/bloom-baseline/`.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:432`</sub>
- [ ] 1.3 Hierarchy + legibility: core vs category vs tool visually distinct (size/colour/label weight); dimmed non-focus nodes still readable; labels don't overlap at overview (lean on `LabelPacker`).  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:438`</sub>
- [ ] 1.4 Auto-fit / camera bounds: bloomed fan never clips screen edges or the top chrome; pan/zoom stays in bounds; empty-tap collapses to overview.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:441`</sub>
- [ ] 1.5 Motion polish: spring-in / collapse fade frame-rate-independent (1-exp(-k·dt)); reduce-motion path is instant + correct; 60fps on device.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:443`</sub>
- [ ] 1.6 Retire dead `ConstellationView` path IF Bloom is confirmed the keeper (flag to user first in log — this is a direction decision, not silent).  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:445`</sub>

## WS2 — 3D spatial: presentable (deferred recs from POLISH_SPRINT_PLAN)

- [ ] 2.1 Default camera: 3/4 orbit with real depth separation (not a flat ring).  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:449`</sub>
- [ ] 2.2 Top-chrome declutter in 3D: one clear exit; move Experimental note to a quieter spot; no stacked toggle/banner/Back-to-2D collision.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:450`</sub>
- [ ] 2.3 Depth cues: fog/scale falloff + faint orbit grid so nodes read as placed in space. Keep the Experimental badge.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:452`</sub>

## WS3 — Sheets, spacing & tokens

- [ ] 3.2 Add Tool: re-verify keyboard-avoiding action bar + "New branch" row reachable on SE-class width; fix any overlap.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:458`</sub>
- [ ] 3.3 Tool detail density + Account/Settings segmented-control polish pass.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:460`</sub>

## WS4 — Accessibility

- [ ] 4.1 VoiceOver: every interactive node/control has a label + trait; Bloom nodes announce name + "expandable/expanded". Add a11y unit coverage.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:463`</sub>
- [ ] 4.2 Dynamic Type: no clipped/truncated text at XXL on key screens.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:465`</sub>
- [ ] 4.3 Reduce-motion + reduce-transparency full matrix across map + sheets.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:466`</sub>

## WS5 — Mechanics & state machine

- [ ] 5.1d 3D chat/detail hides the only "Back to 2D" exit (spatialExperimental Notice gated off in chatOpen) — not a hard trap (Map pill/xmark exit) but 2-step. Keep Back-to-2D mounted in chatOpen. Logic gate; look needs sim.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:481`</sub>

## WS6 — Performance

- [ ] 6.7 (from 6.2) Idle `BloomGraphView` TimelineView redraw when `engine.isSettled` to also skip the per-frame Canvas redraw of static content — NEEDS SIM (verify resume stays instant on tap). Visual-gated.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:513`</sub>

## WS8 — Release QA (runs when WS1–7 mostly closed)

- [ ] 8.1 Full screenshot gallery of key states (2D/3D/sheets) → `screenshots/loop/`.  
  <sub>источник: `ios-app/docs/LOOP_QUEUE.md:553`</sub>

