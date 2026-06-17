# iOS Viz Overhaul + App-Quality + Intelligence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Each task's bite-sized detail (interface, tests, approach, done-criteria) lives in its per-task spec under `docs/superpowers/specs/2026-06-16-ios-viz-overhaul-tasks/`; the subagent reads that spec first, then works TDD. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Turn the iOS "My AI Map" into a legible, premium, top-tier Apple app — fix the broken 3D map, the app-quality bugs, redesign the shell around an account circle, and add a Claude-backed intelligence layer that classifies/connects/converses with real judgment.

**Architecture:** Overlay-Native Universe (RealityKit = ambient backdrop only; SwiftUI+Canvas screen-space overlay owns all legibility) + a `IntelligenceService` actor calling the Claude Messages API via raw `URLSession` with a user-pasted Keychain key and graceful offline fallback.

**Tech Stack:** Swift 6 / SwiftUI / RealityKit / Canvas, Swift Testing (`@Suite`/`@Test`/`#expect`), Claude Messages API (`/v1/messages`), Keychain.

**Spec:** `docs/superpowers/specs/2026-06-16-ios-viz-overhaul-design.md` · **Task specs (25):** `docs/superpowers/specs/2026-06-16-ios-viz-overhaul-tasks/`

---

## Open decisions to confirm before execution

1. **Claude model for the app.** Task specs default to `claude-opus-4-8`. Recommendation: **Sonnet (`claude-sonnet-4-6`) for identify/place/connect** (cheap, fast, high-volume), **Opus (`claude-opus-4-8`) for chatCreate** (reasoning-heavy). Lock per-call in `IntelligenceConfig`.
2. **Anti-blanket clamp values.** `inferConnections` reuses the existing `RelationshipIntelligence` guards (`confidenceThreshold = 0.4`, `maxEdgesPerKind = 4`). Keep or tune.
3. **"User-added" tracking.** No `userAdded` flag on `Tool` today (delete is soft-delete via `removedToolIDs`). S-manage-delete-tools scopes to all deletable tools unless we add a flag — confirm.

## File structure (new dirs)

- `Sources/MyAIMap/Universe/Overlay/` — screen-space render layer: `UniverseProjection`, `NodeBadge`, `ConnectionCanvas`, `OrbLayer`, `DeclutterRule`, `UniverseMotion`, layout strategies.
- `Sources/MyAIMap/Intelligence/` — `IntelligenceService`, `ClaudeClient`, `IntelligenceModels`, `IntelligenceConfig`, per-job extensions.
- `Sources/MyAIMap/Settings/` (or extend existing `SettingsSheet`) — account screen, history list, manage/delete, API-key field; `APIKeyStore` Keychain wrapper.
- Existing RealityKit `Universe/` tree stays but is demoted to ambient backdrop.

## Dependency graph (keystones → leaves)

- **R-projection** → R-node-badge, R-connection-canvas, R-orb-layer; **R-declutter + R-motion** feed all three; **R-viz-switcher** composes them + links to settings.
- **S-keychain-api-key** → I-intelligence-service-core → identify/infer/place/chat/guards.
- **S-account-settings-screen** → top-bar-circle, language, history-clickable, manage-delete, and hosts viz-switcher.
- **Phase A** mostly independent bug fixes; A-dead-button-audit + S-history-clickable both touch Settings→History (coordinate, single owner).

## Execution batches (parallel within a batch, gate between batches)

### Batch 1 — Foundations (parallel)
- [ ] **R-projection** — `R-projection.md` (pure projector; keystone)
- [ ] **S-keychain-api-key** — `S-keychain-api-key.md` (`APIKeyStore`; unblocks Phase I)
- [ ] **S-account-settings-screen** — `S-account-settings-screen.md` (NavigationStack IA shell)
- [ ] **A-black-launch** — `A-black-launch.md` (mount existing `ProgressOrb` behind `onSceneReady`)
- [ ] **A-chat-scroll** — `A-chat-scroll.md` (ScrollViewReader bottom anchor)
- [ ] **A-composer-persistence** — `A-composer-persistence.md` (stop conditional-mount draft loss)
- [ ] **Gate 1:** `swift test` (or xcodebuild test) green; web npm untouched.

### Batch 2 — Render layers + shell sections + intelligence core (parallel)
- [ ] **R-node-badge** — `R-node-badge.md` · dep: R-projection
- [ ] **R-connection-canvas** — `R-connection-canvas.md` · dep: R-projection
- [ ] **R-orb-layer** — `R-orb-layer.md` · dep: R-projection
- [ ] **R-declutter** — `R-declutter.md` · dep: R-projection
- [ ] **R-motion** — `R-motion.md` (wraps existing `BrandMotion.resolved`)
- [ ] **S-top-bar-account-circle** — `S-top-bar-account-circle.md` (strip sparkles tile + tools pill; keep `AccountButton`)
- [ ] **S-language-ru-en** — `S-language-ru-en.md` (L10n key coverage + live-flip)
- [ ] **S-history-clickable** — `S-history-clickable.md` (dismiss-then-focusTool sequencing)
- [ ] **S-manage-delete-tools** — `S-manage-delete-tools.md`
- [ ] **A-chat-discoverability** — `A-chat-discoverability.md`
- [ ] **A-dead-button-audit** — `A-dead-button-audit.md` (coordinate with S-history-clickable)
- [ ] **A-add-tool-fab** — `A-add-tool-fab.md`
- [ ] **I-intelligence-service-core** — `I-intelligence-service-core.md` · dep: S-keychain-api-key
- [ ] **Gate 2:** tests green; simulator screenshot — overview legibility (badges readable, edges visible).

### Batch 3 — Composition + intelligence jobs (parallel)
- [ ] **R-viz-switcher** — `R-viz-switcher.md` · dep: all R layers + S-account-settings-screen (A/K/N/O incl. 3D Force N)
- [ ] **I-identify-tool** — `I-identify-tool.md` · dep: service-core (refuses unknowns)
- [ ] **I-infer-connections** — `I-infer-connections.md` · dep: service-core (pinpoint, no blanket)
- [ ] **I-place-category** — `I-place-category.md` · dep: service-core (existing-or-propose)
- [ ] **I-chat-create** — `I-chat-create.md` · dep: service-core (wired through `ChatThreadStore`)
- [ ] **I-guards** — `I-guards.md` · dep: identify/place (single choke point pre-commit)
- [ ] **Gate 3:** tests green; intelligence tests pass against mocked Claude (refuses-unknown, pinpoint-not-blanket, new-category fallback).

### Batch 4 — Integration + release gate
- [ ] Wire intelligence into the add-tool/intake flow (FAB → identify → place → guards → connections → commit).
- [ ] Full chain: web npm unchanged · iOS xcodebuild test on ClaudeGate · Swift 6 (no isolated-conformance).
- [ ] Simulator screenshots: overview · pocket · each viz style (A/K/N/O) · chat · account/settings · history tap → tool window · add-tool flow.
- [ ] Verify product invariants: no blank canvas, no text overlap, tool details present, no focus trap (per CLAUDE.md release rules).

## Self-review (coverage vs spec)

- Render overhaul → Batch 1–3 R-tasks ✓ · viz switcher incl. N ✓
- App-quality (scroll/discoverability/composer/launch/dead-buttons/FAB) → Phase A ✓
- Shell (account circle, settings IA, RU/EN, clickable history, manage/delete, Keychain) → Phase S ✓
- Intelligence (identify/connect/place/chat/guards, no-hallucinate, confirm-giants, new-category) → Phase I ✓
- Gates + invariants → Batch 4 ✓
- No placeholders: per-task code/interfaces live in the 25 task specs (each grounded in real `file:line`).
