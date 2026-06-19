# IMPLEMENTATION_ROADMAP

Sequential plan for the 2026-06-19 feedback. **No parallel code edits on shared
files.** Claude owns architecture/specs/state; Codex owns isolated iOS tasks
AFTER the relevant spec exists. Each phase = its own branch + PR + green CI.

## Shared files that MUST be serialized (one owner at a time)
- `State/UniverseViewModel.swift` — Claude (Phase 1). Everything data-related waits on it.
- `Universe/UniverseSceneController.swift`, `PlanetEntityFactory.swift` — visualization (Phase 7).
- `Universe/UniverseOverlayView.swift` — hosts rail + bottom controls + empty-state (Phases 2/6 coordinate; not simultaneous).
- `UI/Search/SearchDock.swift` — chat input (Phase 2) then chat chips (Phase 3).
- `UI/Sheets/ToolDetailSection.swift` — detail (Phase 5).
- `UI/Settings/AccountSettingsSheet.swift` — settings (Phase 8).

Pure helpers (`PricingPlans`/`PriceTier`, `ToolClassifier`, label/layout math)
are isolated, unit-tested, and SAFE to build in parallel with anything.

---

## Phase 0 — Docs only (DONE, this PR)
- Owner: Claude. Files: `ios-app/docs/*.md`. No Swift.
- Acceptance: 9 specs exist + this roadmap; triage severities + order agreed.

## Phase 1 — State / source-of-truth stabilization
- Owner: **Claude**. Files: `State/UniverseViewModel.swift`, `State/UniverseSelection.swift` (read), `State/UniverseStore.swift` (render-mode persistence).
- Do: fix **C-1** (added tool real in search/chat/map/detail — verify every consumer reads `visibleAllTools`); decide + implement the **duplicate-name policy** (`ADD_TOOL_SPEC.md`); add the `UniverseRenderMode` field (persisted) used by Phases 6/8; ensure `searchResults`/assistant inputs are the live set.
- Do NOT touch: views (SearchDock/ToolDetail/scene), rail, settings UI.
- Acceptance: a tool added in-session is found by search + named by Ask AI + has a planet + opens detail; adding a duplicate name focuses the existing tool; `UniverseRenderMode` persists.
- QA: add PostHog (new) → appears everywhere; add a dup name → focuses existing.

## Phase 2 — Chat / input layout
- Owner: **Codex**. Spec: `CHAT_INPUT_SPEC.md`. Files: `UI/Search/SearchDock.swift` + its bubble subviews.
- Do: content-fit user bubbles; assistant markdown; fix focus-darkening (respect `UniverseMode` contract, don't change its values); attachment icon/menu/state; remove duplicate add/attach controls; fix collapse↔expand to preserve `assistantMessages` + scroll; correct plus↔send.
- Do NOT touch: `UniverseViewModel` selection logic, scene, rail, `UniverseMode` values.
- Acceptance: per `CHAT_INPUT_SPEC.md`. QA: that spec's steps 1–6.

## Phase 3 — Ask AI data intelligence
- Owner: **Claude** (core logic in `UI/Search/UniverseAssistantCore.swift` + shared `PriceTier` parser) → **Codex** (chip rendering in the Phase-2 bubbles).
- Depends on: Phase 1 (live data) + Phase 2 (bubble host).
- Do: structured recommendations (have/missing/paid-free/fast-slow/tradeoffs); typed `chips` payload; intents; no-match → curated popular `.add` chips; unit tests.
- Do NOT touch: scene, rail, detail layout. Codex chip UI must not alter `UniverseViewModel`.
- Acceptance: per `CHAT_AI_SPEC.md`. QA: that spec's steps 1–5.

## Phase 4 — Add Tool flow
- Owner: **Claude** (classifier + post-add already in Phase 1 state) → **Codex** (Auto/Manual segmented control UI).
- Spec: `ADD_TOOL_SPEC.md`. Files: `UI/Settings/AddToolSheet.swift`, pure `ToolClassifier`.
- Do: fix inverted Auto/Manual via an explicit segmented control; classification name+website+context; show classification reason in detail.
- Do NOT touch: chat, detail layout, scene.
- Acceptance: tapping a segment selects it; Auto hides category, Manual shows it; classifier unit-tested. QA: `ADD_TOOL_SPEC.md` steps 1–4.

## Phase 5 — Detail screen / icons / pricing
- Owner: **Codex**. Spec: `TOOL_DETAIL_SPEC.md`. Files: `UI/Sheets/ToolDetailSection.swift`, `RootSheet.swift`, `UI/Sheets/ToolLogoView.swift`, pure `PricingPlans` parser (shared with Phase 3).
- Do: one block component; pricing plan table; real logo + monogram fallback; consistent headings; quiet metadata; clear primary CTA. Reads model read-only.
- Do NOT touch: `UniverseViewModel`, chat, scene, rail.
- Acceptance: per `TOOL_DETAIL_SPEC.md`. QA: that spec's steps 1–5.

## Phase 6 — Right rail
- Owner: **Codex**. Spec: `RIGHT_RAIL_SPEC.md`. Files: `Universe/RightUniverseRail.swift`, its mount in `UniverseOverlayView.swift`.
- Do: edge-pinned inactive; long-press+drag; right-aligned text with edge-anchored offset hierarchy; light scrim (not black-out); smooth scrub; release fly-to; no map-pan swallow; selection sync.
- Do NOT touch: scene rendering, chat, detail, bottom-controls layout beyond the rail mount.
- Acceptance: per `RIGHT_RAIL_SPEC.md`. QA: that spec's steps 1–5.

## Phase 7 — Visualization: 2D fallback + 3D cleanup
- Owner: **Claude** (mode architecture, reads Phase-1 `UniverseRenderMode`) → **Codex** (2D graph renderer + 3D defect fixes).
- Spec: `VISUALIZATION_SPEC.md`. Files: NEW `Universe/UniverseGraph2DView.swift`, `UniverseSceneController.swift`, `PlanetEntityFactory.swift`, `UniverseSpatialLayout.swift`.
- Do: build 2D graph mode (default), fix 3D overlap/rotation/artifacts/clipping/labels.
- Do NOT touch: chat, detail, settings logic (just read the mode), `UniverseViewModel` writes.
- Acceptance: per `VISUALIZATION_SPEC.md` no-defect bar. QA: that spec's steps 1–5.

## Phase 8 — Profile / settings
- Owner: **Codex**. Spec: `SETTINGS_PROFILE_SPEC.md`. Files: `UI/Settings/AccountSettingsSheet.swift`.
- Depends on: Phase 7 (render mode exists to wire the Visualization control).
- Do: wire Visualization 3D/2D; retire-or-differentiate presets; clarify/disable Language; audit Haptics flag; disable any dead control.
- Do NOT touch: scene, chat, detail, rail.
- Acceptance: per `SETTINGS_PROFILE_SPEC.md`. QA: that spec's steps 1–5.

## Phase 9 — Regression QA
- Owner: Claude (coordination) + Codex. Run `QA_REGRESSION_CHECKLIST.md` across iPhone + iPad, Reduce Motion, empty + populated universe; full `ios-verify.sh --full-test`; visual screenshots of each fixed domain.
- Acceptance: all per-phase acceptance still green together; no cross-domain regressions.

---

## Recommended order (condensed)
0 docs → **1 state (C-1, fix-first)** → 2 chat input → 3 Ask AI → 4 add-tool → 5 detail/pricing/logos → 6 rail → 7 visualization → 8 settings → 9 QA.

## First Codex-safe task
**The pure `PricingPlans` / `PriceTier` parser** (`TOOL_DETAIL_SPEC.md` §Pricing
+ `CHAT_AI_SPEC.md` §Pricing parsing) — an isolated, unit-tested helper that
touches no shared file and unblocks both detail (Phase 5) and Ask AI (Phase 3).
Codex can build it in parallel with Claude's Phase 1, with zero conflict risk.
(Runner-up safe task: the **Auto/Manual segmented-control UI** in `AddToolSheet`
— isolated view, but coordinate so it lands after Phase 1's classifier hook.)

## What must NOT be parallelized
- Two agents editing `UniverseViewModel.swift` — Phase 1 is Claude-exclusive; no
  other domain edits it concurrently.
- Phase 2 and Phase 6 both touching `UniverseOverlayView.swift` at once — rail
  (6) and chat/bottom-controls (2) must land sequentially, not in parallel.
- Phase 3 chip UI and Phase 2 bubble layout in the same `SearchDock` file
  simultaneously — Phase 2 lands first, Phase 3 builds on it.
- Phase 7 and any other phase editing `UniverseSceneController`/`PlanetEntityFactory`.
- Detail (5) and chat (3) both redefining the `PriceTier`/`PricingPlans` parser —
  define it ONCE (first Codex-safe task), both import it.
