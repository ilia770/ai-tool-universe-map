# POLISH SPRINT — Audit + Day Plan

Owner: autonomous polish pass (iOS app). Reviewed with user after ~1 day.
Goal stated by user: bring the whole app to "ideal" — fix spacing/padding
across every component, make product mechanics work as intended, and **rebuild
the 2D and 3D visualizations** so they read as an intuitive, reference-grade
map. Content placed cleanly. User returns to refine + test together.

This file is the running plan + log. Each workstream has: findings → target →
status. Update status as work lands. Screenshots live in
`/tmp/aimap-*` during the run and the kept set is copied to
`screenshots/polish-sprint/`.

---

## Audit — current state (verified on iPhone 16 Pro sim, sample universe)

### 2D Graph (DEFAULT renderer — top priority)
Evidence: live overview screenshot + `UniverseGraphView.swift`.

1. **Overcrowded overview.** Core + 9 categories + ~50 tool nodes all render
   at once on a phone. Result reads as mush, not a map. The bottom card even
   says "Choose a branch to reveal its tools" — but tools are already all
   shown, defeating progressive disclosure.
2. **Edge clipping.** Category/tool nodes are cut off at the left and right
   screen edges ("Analy…", half-circles on the right). Layout extends past
   the viewport at scale 1 with no auto-fit.
3. **Weak hierarchy.** Core, category, and tool nodes look nearly identical
   (same glassy circle + glow). Hard to tell a category from a tool at a
   glance.
4. **Tools not visibly grouped.** Tool nodes float near center, not clearly
   parented to their category (collision solver scatters them).
5. **Faint edges.** Connection lines are low-opacity and organic-wobbly;
   the core→category hub-and-spoke does not read.
6. **Chrome overlaps the map.** The top "Ask AI | Map" segment and the
   "2D Graph | 3D Spatial" toggle overlap each other AND graph node labels.

### 3D Spatial (EXPERIMENTAL renderer)
Per `VISUALIZATION_SPEC.md`: known overlap / clipping / depth / rotation
artifacts, intentionally deferred. Skybox + dust were removed earlier due to
square-texel artifacts. Needs to at least be presentable; not the priority.

### Sheets & components
- **Add Tool:** "Next" button overlaps the branch card; "New branch" row is
  hidden behind the keyboard; branch selector cramped.
- **Account / Settings:** the Settings|History segmented control — active pill
  text is clipped and the active style is heavy/odd. Section spacing loose.
- **Tool detail:** density pass already in progress (commits E1/E2); continue.
- **Inconsistent spacing:** audit hardcoded `.padding(n)` / magic numbers and
  route through `BrandSpacing` (4px grid) per the token contract.

### Mechanics
- Escape layering, category-focus exit, chat open/close, pan/zoom bounds,
  add-tool end-to-end, empty-state onboarding. Audit for traps + dead ends.

---

## Day plan (sequenced, autonomous; each step verified by build + tests + shots)

- [ ] **WS0 Setup** — isolate on a branch carrying existing WIP; capture
      baseline screenshots of all key states; stand up the task list.
- [ ] **WS-A 2D overview redesign** — progressive disclosure. Overview shows
      core + categories only, evenly placed on an orbit, none clipped, with
      strong tiered hierarchy and clear radial spokes. TDD on
      `UniverseGraphLayout` (pure, already tested).
- [ ] **WS-B Map top-chrome** — stop the toggles overlapping each other and the
      map; one clean control row with correct spacing + safe-area.
- [ ] **WS-A2 Branch focus + tool reveal** — tapping a category reveals its
      tools as a legible sub-cluster (arc/grid), others collapse/dim; tool
      labels readable; auto-fit so nothing clips.
- [ ] **WS-D Sheets spacing** — Add Tool (Next overlap + keyboard), Account
      segmented control, tool-detail density; tokenize paddings.
- [ ] **WS-E Mechanics** — navigation/state-machine audit + fixes with tests.
- [ ] **WS-C 3D presentable** — spacing, no z-fight, legible labels; keep the
      Experimental badge.
- [ ] **WS-F Copy/content** — trim, fit labels, consistent terminology.
- [ ] **WS-G Final verification** — full build, unit + UI smoke, screenshot
      gallery, written summary of what changed and what needs the user.

## Guardrails
- Respect `VISUALIZATION_SPEC` + invariants; update spec when behavior changes.
- Keep changes surgical and committed in small, verified slices.
- Do not break the 2D-as-default contract or the renderer switch.
- Visual judgement calls that need the user are flagged in the final summary,
  not silently decided.

## Log

### 2026-06-26 — WS-A 2D overview redesign (landed, commit ecdbb48)
- **Progressive disclosure**: overview now emits core + categories only (no
  tool nodes), matching the 3D scene. The ~50-tool seed no longer crams the
  screen — overview reads as a clean hub-and-spoke, verified on iPhone 16 Pro,
  no edge clipping. Before/after in `screenshots/polish-sprint/baseline` vs
  `after-A`.
- **Focused tools on a ring** around their category (double-ring for dense
  branches) instead of a tall grid that marched off the top edge; labels space
  evenly. (`after-A2`.)
- **Spokes visible**: core→category edge opacity 0.14 → 0.26.
- **Top inset raised** so the overview ring clears the route/render chrome.
- Tests: `UniverseGraphLayoutTests` rewritten to the new contract; full
  `MyAIMapTests` suite green.

**Findings while auditing (good news — already fixed in current code, the stale
`screenshots/glass-surface-xcuitests` set predates them):**
- Account/Settings sheet spacing + the History pill look clean in the current
  build.
- Add Tool already has a docked, keyboard-avoiding action bar (D4 fixed).
- Onboarding copy already trimmed; state machine already single-source-of-truth.
→ WS-D / WS-E are smaller than the original audit feared. Re-scoped to: verify
  fresh captures (3D, Add Tool, History via `PolishCaptureTests`), branch-focus
  top-clip polish, and the map top-chrome stacking.

### 2026-06-26 — WS-A2 / WS-B / WS-D / WS-C verified (captures in `after-B`, `extra`)
- **WS-A2 branch focus**: ring + smaller radii + top inset → focused tools sit
  in a Coding-centred ring, clear of chrome and tappable (`after-B/02-branch`).
  Remaining nit for the joint session: the densest branch (Coding, 11 tools)
  still grazes the chrome at the very top arc — fully solving needs either a
  smarter auto-pan top-bias or capping simultaneously-shown tools.
- **WS-D sheets**: fresh captures show Add Tool (`extra/12-addtool-name`) already
  has a docked, keyboard-avoiding "Next" bar — no overlap. Account/Settings
  clean. The earlier "broken sheet" screenshots were the stale
  `glass-surface-xcuitests` set. **No WS-D code change needed.**
- **WS-B map chrome**: overview now clears the chrome via the top inset. The two
  stacked pill rows (route switch + render toggle) do not overlap each other in
  2D. **Open design question for the user** (not changed unilaterally): the
  render toggle is also in Settings → Visualization, so the on-map 2D/3D toggle
  is arguably redundant chrome; consider dropping it from the map top bar.
- **WS-C 3D** (`extra/10-3d-spatial`): renders fine, no square artifacts, labels
  legible, clearly badged Experimental. But it is flat/dim at the default camera
  (reads almost like the 2D ring) and the experimental-notice banner + "Back to
  2D" pill crowd the top toggle row. Per `VISUALIZATION_SPEC` (3D defects are
  out of scope; "readability > 3D wow"; 2D is the default), a blind RealityKit
  overhaul is deliberately **deferred to the joint session**. Concrete
  recommendations below.

## 3D recommendations (for the joint session — needs live device iteration)
1. **Default camera**: pull to a clearer 3/4 orbit with more depth separation so
   it does not read as a flat 2D ring; current framing wastes the 3D.
2. **Top chrome**: in 3D, collapse the redundant exit affordances — the render
   toggle, the "experimental" banner, and the "Back to 2D" pill currently stack.
   Keep one clear exit; move the experimental note to a quieter spot.
3. **Depth cues**: stronger fog/scale falloff and a faint ground/orbit grid so
   the planets read as positioned in space, not scattered dots.
4. **Decide its role**: is 3D a "wow" showcase or a real navigation mode? If
   showcase only, simplify it to an auto-orbiting hero view; if navigation,
   invest in label de-overlap + tap precision (the `LabelPacker` is already
   there to build on).

## Status summary
- **2D map (the core complaint): rebuilt and verified.** Overview + branch focus
  read as a clean, intuitive map; no clipping; tests green.
- **Sheets / onboarding / state machine: audited, already solid** in current
  code — minimal changes needed (one copy unification).
- **3D: assessed, documented, deferred** to the joint session by design.
