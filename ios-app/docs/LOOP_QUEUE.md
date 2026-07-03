# LOOP QUEUE — Autonomous Day Sprint (iOS)

Single source of truth for the self-driving improvement loop. The orchestrator
reads this each cycle, picks the top `[ ]` slice, dispatches a worker to
implement it, runs the gate, then marks `[x]` (done) / `[!]` (blocked) and logs
to `LOOP_LOG.md`. When the open queue runs low, the orchestrator runs an audit
subagent to append fresh slices (the "loop" keeps refilling itself).

Branch: `polish/day-sprint`. Scope: `ios-app/**` only (Claude ownership — never
touch Codex web files). Every slice must be surgical + committed on green gate.

---

## OPERATING MODEL (the autonomous machine)

**Main agent = persistent orchestrator.** Durable state lives in THIS file +
`LOOP_LOG.md`, so any fresh context window resumes the loop by re-reading them.
Per cycle the main agent:
1. `git status`; read this queue + tail `LOOP_LOG.md`.
2. **Backpressure check** (see below). If blocked → prune or wait, don't build.
3. Pick the top `[ ]` slice. Dispatch ONE **worker subagent** with the slice +
   the Guardrails contract below.
4. **Answer the worker's questions** (via SendMessage to the same worker so its
   context is kept) — the worker asks instead of guessing.
5. When the worker returns: run the **gate**. Green → commit, mark `[x]`, log.
   Red → mark `[!]`, log the error, requeue (or dispatch a focused fix worker).
6. When `< 3` open slices remain → dispatch a **read-only audit subagent** to
   propose new improvement slices; append them here. (This is the infinite
   refill — the loop never runs dry.)
7. Continue to the next cycle, or `ScheduleWakeup` to resume in a later context
   window. Target duration: ~1 day of wall-clock.

**Worker subagents** execute exactly ONE slice in `ios-app/**`: implement, run
the compile gate themselves, self-review, then report `{files changed, gate
result, questions, follow-ups}`. They ask the main agent when blocked.

**Gate tiers (this machine is shared — be a good citizen):**
- Per-slice (primary): `bash scripts/ios-verify.sh --test-build-only`
  — generic destination, **no simulator boot**, disk/CPU-light. Already green.
- Workstream boundary / logic or test changes: full
  `--run-tests --device-id <AIMap sim>` — only in a **clear window**
  (free disk > 8 GiB AND no non-AIMap `xcodebuild` running).

**Backpressure (user requirement — wait or clean, never thrash):**
- A SECOND autonomous loop (Codex/MultTracker) shares this M1 Air. Never touch
  the `Mult-*` simulators or any MultTracker files. Before a heavy gate,
  `pgrep -fl xcodebuild` — if a non-AIMap build runs, defer heavy gates.
- Free disk < 6 GiB → prune `ios-app/build/Build/Intermediates.noindex` +
  old `*.xcresult` + `~/Library/Developer/Xcode/DerivedData`.
- Free disk < 4 GiB after pruning, OR rate/session limit hit → **WAIT**:
  `ScheduleWakeup` ~1200s and retry; do not build. Rate limits pause the loop
  naturally; the durable docs let it resume cleanly.

**Orchestrator wakeup prompt (reuse verbatim for ScheduleWakeup):**
> AUTONOMOUS iOS LOOP (ai-tool-universe-map, branch polish/day-sprint). You are
> the persistent main orchestrator. Read `ios-app/docs/LOOP_QUEUE.md` +
> `LOOP_LOG.md` and run the next cycle per the Operating Model: backpressure
> check → pick top `[ ]` slice → dispatch a worker subagent → answer its
> questions → run the gate → green commit+mark[x]+log / red mark[!]+log+requeue
> → refill via audit subagent when <3 open. Then continue or ScheduleWakeup to
> keep the loop going for the day.

## Gate (every slice)
```
bash scripts/ios-verify.sh --run-tests --device-id 94F154FE-290A-4154-9942-EB9C3A9D1852
```
Green = build + `MyAIMapTests` all pass, `failedTests == 0`, pass count ≥ prior.
Baseline pass count: _(filled by cycle 0)_. Never background xcodebuild.
New files compile via xcodegen (the script regenerates the project).

## Guardrails (worker prompt contract)
- Only `ios-app/**`. Match existing style. Route paddings through `BrandSpacing`.
- Surgical: every changed line traces to the slice. No drive-by refactors.
- TDD pure logic (engines/layout/adjacency) before view wiring where possible.
- Update the matching `ios-app/docs/*_SPEC.md` when behavior changes.
- Respect the 2D-as-default contract + the renderer switch + reduce-motion.
- Prune `ios-app/build` + old xcresults if free disk < 6 GiB before a gate.
- Flag any judgement call that needs the user in `LOOP_LOG.md`, don't guess.

---

## WS1 — Bloom 2D map (the new default renderer) — FRONTIER
The WIP swaps `graph2D` from `ConstellationView` → `BloomGraphView` (variant K:
force-directed progressive reveal). Finish, harden, verify, make it feel Apple.
- [ ] 1.1 Snapshot baseline of Bloom in overview + one bloomed branch on the
      26.5 sim; confirm it renders (not blank), no clipping, taps select. Save to
      `ios-app/screenshots/loop/bloom-baseline/`.
- [x] 1.2 (logic) `BloomEngineTests` +8 expand/collapse stack invariants —
      commit b60f8a9. Remaining (needs sim window): live end-to-end tap→bloom→
      collapse + breadcrumb check → folded into 1.1 snapshot.
- [ ] 1.3 Hierarchy + legibility: core vs category vs tool visually distinct
      (size/colour/label weight); dimmed non-focus nodes still readable; labels
      don't overlap at overview (lean on `LabelPacker`).
- [ ] 1.4 Auto-fit / camera bounds: bloomed fan never clips screen edges or the
      top chrome; pan/zoom stays in bounds; empty-tap collapses to overview.
- [ ] 1.5 Motion polish: spring-in / collapse fade frame-rate-independent
      (1-exp(-k·dt)); reduce-motion path is instant + correct; 60fps on device.
- [ ] 1.6 Retire dead `ConstellationView` path IF Bloom is confirmed the keeper
      (flag to user first in log — this is a direction decision, not silent).

## WS2 — 3D spatial: presentable (deferred recs from POLISH_SPRINT_PLAN)
- [ ] 2.1 Default camera: 3/4 orbit with real depth separation (not a flat ring).
- [ ] 2.2 Top-chrome declutter in 3D: one clear exit; move Experimental note to a
      quieter spot; no stacked toggle/banner/Back-to-2D collision.
- [ ] 2.3 Depth cues: fog/scale falloff + faint orbit grid so nodes read as placed
      in space. Keep the Experimental badge.

## WS3 — Sheets, spacing & tokens
- [ ] 3.1 Audit hardcoded `.padding(n)` / magic radii across `ios-app/Sources`;
      route through `BrandSpacing` (4px grid). Value-preserving, tested.
- [ ] 3.2 Add Tool: re-verify keyboard-avoiding action bar + "New branch" row
      reachable on SE-class width; fix any overlap.
- [ ] 3.3 Tool detail density + Account/Settings segmented-control polish pass.

## WS4 — Accessibility
- [ ] 4.1 VoiceOver: every interactive node/control has a label + trait; Bloom
      nodes announce name + "expandable/expanded". Add a11y unit coverage.
- [ ] 4.2 Dynamic Type: no clipped/truncated text at XXL on key screens.
- [ ] 4.3 Reduce-motion + reduce-transparency full matrix across map + sheets.

## WS5 — Mechanics & state machine
- [ ] 5.1 Navigation-trap audit: escape layering, category-focus exit, chat
      open/close, add-tool end-to-end, empty states. Fix dead ends with tests.
- [ ] 5.2 Pan/zoom + gesture-bounds hardening on Bloom; no lost/stuck states.

## WS6 — Performance
- [x] 6.1 os_signpost intervals `bloom.tick` + `bloom.layout` — commit 2fe78c1.
      (Frame-budget confirmation on sim deferred to a clear window.)
- [ ] 6.2 Cap force-sim work (sleep when settled); no busy-loop when idle.
- [ ] 6.3 **HOTSPOT (found in 6.1):** `BloomGraphView.draw` rebuilds the full
      `BloomAdjacency.build(tools:)` dict + `allEdges`/`toolByID` computed props
      EVERY frame just to read the focus's neighbours. Cache/memoize (rebuild
      only when the tool set changes). Pure-logic + measurable; sim-free gate.
- [ ] 6.4 Engine guard tests (from cycle 1 worker): tap-focus-only path,
      `collapseTo(0)` clamp to root, `reset()` restores initial stack/focus,
      `visibleEdges` filtering while an endpoint is `collapsing`. Sim-free.

## WS7 — Copy & content
- [ ] 7.1 Terminology + label-length consistency pass across map + sheets.

## WS8 — Release QA (runs when WS1–7 mostly closed)
- [ ] 8.1 Full screenshot gallery of key states (2D/3D/sheets) → `screenshots/loop/`.
- [ ] 8.2 Written change summary + list of user-decision flags for the joint session.
