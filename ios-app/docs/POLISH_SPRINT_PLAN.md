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
(append per landed slice)
