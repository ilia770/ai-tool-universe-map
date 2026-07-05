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
- [~] 1.1 PARTIAL — machine freed, app built+installed+launched on AIMapGate 26.5;
      captured baseline: onboarding overlay + OVERVIEW/Founder OS map chrome +
      colored category chips (Coding/Design/Research/Media/Social — confirms 9.6
      colors render, not white). Screenshots in `ios-app/screenshots/loop/`.
      REMAINING: populated Bloom (branch bloom w/ tools) needs sample-load / tool-add
      via UI driving — blocked by stale UI smoke test (5.3 below). Do with user.
- [ ] 5.3 **STALE TEST:** `MyAIMapUITests` smoke harness fails — waits for
      "RootShell.ShowChat" Button (+ chat-composer-field) that recent UI renamed/
      removed (63s timeout). It's NOT a required CI check but blocks scripted
      screenshot capture. Update the harness element ids/flow to the current UI.
- [ ] 1.1old Snapshot baseline of Bloom in overview + one bloomed branch on the
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
- [x] 3.1 Tokenized 39 exact-match paddings across 13 views → BrandSpacing
      (value-preserving; off-grid values left). commit 98c86b8.
- [ ] 3.2 Add Tool: re-verify keyboard-avoiding action bar + "New branch" row
      reachable on SE-class width; fix any overlap.
- [ ] 3.3 Tool detail density + Account/Settings segmented-control polish pass.

## WS4 — Accessibility
- [ ] 4.1 VoiceOver: every interactive node/control has a label + trait; Bloom
      nodes announce name + "expandable/expanded". Add a11y unit coverage.
- [ ] 4.2 Dynamic Type: no clipped/truncated text at XXL on key screens.
- [ ] 4.3 Reduce-motion + reduce-transparency full matrix across map + sheets.

## WS5 — Mechanics & state machine
- [x] 5.1 Nav-trap audit done (read-only subagent). No hard unexitable trap;
      found real bug cluster → new fix slices below. Clean: empty states, cancel-
      discard, detail/chat mutual-exclusion, chat collapse/resume.
      **Findings → fix slices:**
- [x] 5.1a data-misfile fixed — Add blocked when creating a branch with empty
      name (pure AddToolLogic.canAdd + 4 tests). commit c4c6fe9.
- [x] 5.1b state-desync fixed — seedID(for:) seeds/focuses Bloom from current
      selection (guaranteed-valid, core fallback) + 6 tests. commit dd81b80.
- [~] 5.1c PARTIAL (via 5.1b): syncEngineFocus on mode-change now moves graph
      focus to revealed nodes (covers rail-select/restore). REMAINING (needs sim):
      empty-tap should COLLAPSE the bloom (not just refocus) + full overview reset
      visual — engine.reset() wiring + settle verification. Deferred to sim window.
- [ ] 5.1d 3D chat/detail hides the only "Back to 2D" exit (spatialExperimental
      Notice gated off in chatOpen) — not a hard trap (Map pill/xmark exit) but
      2-step. Keep Back-to-2D mounted in chatOpen. Logic gate; look needs sim.
- [~] 5.2 N/A for Bloom — no user pan/zoom exists (camera auto-follows focus via
      force-sim, self-correcting, no zoom factor). Slice was written for the old
      pan/zoom renderer. Manual pan/zoom would be a NEW FEATURE (user decision),
      not a hardening slice.

## WS9 (cont.) — correctness audit findings (cycle 33, sim-free)
- [x] 9.3 FIXED — internal pricing branch guarded against open-source strings;
      agent-skills now shows free-core row (+3 tests). commit 9b805f5.
- [x] 9.4 DONE — composer-wipe fixed + AssistantResponder seam + throwing-responder
      failure test (draft survives). commit 101ce4d. Full-sim green.
- [x] ~~9.4 (old stash note below, superseded)~~
- [/] 9.4-hist — fix WRITTEN (reviewed-correct) but STASHED, not gated:
      `git stash` "wip-9.4-deepseek-composer-fix". Adds `AssistantResponder` seam
      (protocol + DeepSeekClient conformance + injectable on VM init), moves the
      `assistantQuery=""` reset out of appendLocalReply into the sync send branch
      (DeepSeek branch keeps its up-front clear). Worker died mid-test on an API
      error; disk then dropped to 3.4-3.8 GiB (< wait line) so the gate couldn't
      run. RESUME when disk > ~6 GiB: `git stash pop`, add the failure-path test
      (inject throwing responder; note: async fire-and-forget Task + dev-gated
      backend make it non-trivial — may need an await seam), gate, commit.
- [x] 9.5 FIXED — custom init(from:) delegates to memberwise init (single clamp
      source); format preserved (+3 tests). commit d9d57ec.

## WS6 — Performance
- [x] 6.1 os_signpost intervals `bloom.tick` + `bloom.layout` — commit 2fe78c1.
      (Frame-budget confirmation on sim deferred to a clear window.)
- [x] 6.2 Settle-cap — tick early-returns when at rest (velocity/appear/
      collapsing/camera < eps); every mutation wakes via wake(). +5 tests incl.
      resume-on-mutation guards. commit 9e0ba90.
- [ ] 6.7 (from 6.2) Idle `BloomGraphView` TimelineView redraw when
      `engine.isSettled` to also skip the per-frame Canvas redraw of static
      content — NEEDS SIM (verify resume stays instant on tap). Visual-gated.
- [x] 6.3 HOTSPOT fixed — memoized allTools/toolByID/adjacency/allEdges to
      @State, rebuilt only on tool-set change (was every TimelineView frame).
      commit 7a3f74b. Follow-up: `edges(from:adjacency)` overload to dedupe the
      double build in rebuildModel (harmless, off hot path) → 6.5.
- [x] 6.4 Engine guard tests +4 (tap-focus-only, collapseTo(0) clamp, reset()
      restore, visibleEdges excludes collapsing endpoint) — commit 104daed.
      Follow-up: collapseLast from 3-deep stack, fanSeed geometry → 6.6.
- [x] 6.5 `BloomAdjacency.edges(from:)` overload — build once in rebuildModel;
      byte-identical edge set; equivalence test. commit 4cb55cd.

## WS7 — Copy & content
- [x] 7.1 Copy consistency (mechanical) — unified tool-detail label
      Category→Branch (lone outlier vs 10+ canonical). commit 78d6ba9.
      **4 subjective calls DEFERRED TO USER (7.2):**
      - "Load sample universe" vs "Load a sample universe" (1v1, no winner)
      - pricing slash spacing "Paid/cloud" vs "Subscription / usage" (typographic)
      - "map" vs "universe" for the user's collection (brand voice)
      - "Add Tool" title-case vs "Add tool" a11y sentence-case (may be intended)

## WS9 — Correctness (from audit refill, cycle 7 — sim-free)
- [~] 9.1 REFUTED (cycle 7 adversarial verify): the "missing `.lowercased()`" is a
      no-op — `MissingToolSuggestion.slug` uses `.folding([.caseInsensitive,...])`
      which already lowercases, so it equals `UniverseViewModel.slug` for all
      inputs (verified empirically incl. exotic Unicode). No bug, no change. Audit
      static-read false positive — treat audit slugs skeptically.
- [x] 9.2 FIXED (user delegated "distinct names ⇒ two tools"): host match now
      gated on name-slug agreement so distinct-named same-host tools coexist;
      same-name dedup unchanged. +2 tests. commit f8bba44.

## WS9 (cont.) — audit cycle 34 findings (sim-free, gate-blocked on disk)
- [x] 9.6 FIXED — ColorHex.parse() adds rgba + 3/8-digit hex; planet glows/accents
      now render their tint not white. +6 tests. commit f98a574.
- [x] 9.7 FIXED — classifier matches keywords on word boundaries (tokenize), not
      substrings. commit d593296. Full-sim caught a camelCase regression → 9ec2f9b
      (tokenizer splits camelCase/acronym before folding; +2 tests).

## WS8 — Release QA (runs when WS1–7 mostly closed)
- [ ] 8.1 Full screenshot gallery of key states (2D/3D/sheets) → `screenshots/loop/`.
- [x] 8.2 `docs/JOINT_SESSION_DIGEST.md` — shipped-work table, 3 user decisions
      (1.6 / 7.2 copy / publish branch), sim-blocked backlog, first-actions. No
      build needed.
