# TECHNICAL_DEBT — Observed risks, not implementation instructions

This is a factual backlog. None of these items authorize a refactor.

## TD-01 — Renderer direction is unresolved in the current worktree

- **Severity:** Critical
- **Evidence:** `UniverseMapView` mounts untracked `UniverseConstellationView`;
  retained `UniverseRealityView`/scene code has no current call site. HEAD and
  historical reports describe a RealityKit-first direction.
- **Affected files:** `UniverseMapView.swift`, untracked constellation files,
  RealityKit/camera/entity files, renderer docs/tests.
- **Current impact:** code, tests, and documentation can describe different
  products.
- **Likely future impact:** accidental reactivation/deletion or release of an
  uncommitted renderer.
- **Safe remediation boundary:** explicit renderer-decision task with version
  control, source cleanup plan, compact/iPad/device verification.
- **Prerequisites:** product decision and fresh comparison evidence.
- **Regression risks:** selection, detail, labels, performance, accessibility,
  UI-test identifiers.

## TD-02 — Compact detail has synchronized local and global presentation state

- **Severity:** High
- **Evidence:** `UniverseMapView.detailPresented`/`modeBeforeDetail` synchronize
  with `UniverseMode.detail` through `onChange`.
- **Affected files:** `UniverseMapView.swift`, `UniverseMode.swift`, detail UI.
- **Current impact:** dismissal timing is more complex than a single owner.
- **Likely future impact:** stale sheet, wrong restored mode, iPad divergence.
- **Safe remediation boundary:** map-navigation-only task; retain separate
  compact/regular acceptance tests.
- **Prerequisites:** simulator evidence for interactive dismiss and related-tool
  flow.
- **Regression risks:** sheet detents, map dimming, pending detail handoff.

## TD-03 — Root Chat and in-map chat share data but not navigation semantics

- **Severity:** High
- **Evidence:** `RootShell.surface` mounts `ChatScreen`; `SearchDock` drives
  `UniverseMode.chatOpen`; root return resets overview.
- **Affected files:** `RootShell.swift`, `UniverseMapView.swift`, `SearchDock.swift`, `ChatScreen.swift`.
- **Current impact:** users can see the same transcript with different return
  and keyboard/collapse behavior.
- **Likely future impact:** accidental navigation “fix” changes the other chat
  surface.
- **Safe remediation boundary:** explicit information-architecture task,
  preserving transcript ownership and testing both routes.
- **Prerequisites:** product decision on desired restoration semantics.
- **Regression risks:** blank chat, blacked-out map, lost focus, stale overlay.

## TD-04 — Right rail exists but is unmounted

- **Severity:** Medium
- **Evidence:** `UniverseOverlayView.rightUniverseRail` is never inserted;
  `CategoryRail` has no production caller.
- **Affected files:** overlay, `RightUniverseRail.swift`, `CategoryRail.swift`, rail tests/spec.
- **Current impact:** historical specs/QA overstate available navigation.
- **Likely future impact:** dead code or a rushed reintroduction without
  accessibility/touch arbitration.
- **Safe remediation boundary:** one rail activation/removal decision task.
- **Prerequisites:** decide if rail is product requirement; map touch test plan.
- **Regression risks:** edge hits, keyboard resignation, VoiceOver alternative.

## TD-05 — Legacy spatial objects are allocated under the 2D host

- **Severity:** High
- **Evidence:** `UniverseMapView` creates scene/camera/gesture controllers and
  invokes camera focus, while no `UniverseRealityView` is mounted.
- **Affected files:** `UniverseMapView.swift`, legacy spatial system.
- **Current impact:** dead-path cost and misleading architecture behavior.
- **Likely future impact:** unexpected resource/performance or stale assumptions.
- **Safe remediation boundary:** renderer decision only; do not delete as a
  cleanup side effect.
- **Prerequisites:** confirm retained spatial path intent.
- **Regression risks:** future 3D reactivation, tests, transition ownership.

## TD-06 — View model combines several domains

- **Severity:** High
- **Evidence:** 685-line `UniverseViewModel` owns persistence, catalog edits,
  selection, assistant routing, activity, onboarding and subscription.
- **Affected files:** `State/UniverseViewModel.swift` and all consumers.
- **Current impact:** small changes have broad regression surface.
- **Likely future impact:** coupling grows as sync/network features arrive.
- **Safe remediation boundary:** no action now; first establish stable renderer
  and product contracts before a bounded extraction proposal.
- **Prerequisites:** test characterization and explicit architecture approval.
- **Regression risks:** data loss, selection desync, assistant behavior.

## TD-07 — Persistence has no migration/recovery contract

- **Severity:** High
- **Evidence:** `UniverseStore` uses v1 JSON keys and silent decode fallback.
- **Affected files:** `UniverseStore.swift`, model/data Codable types.
- **Current impact:** malformed or changed payload can silently look like empty
  data.
- **Likely future impact:** data loss during schema evolution.
- **Safe remediation boundary:** storage-only migration/recovery task.
- **Prerequisites:** sample legacy payloads and user-data retention policy.
- **Regression risks:** custom tools/categories, hidden tool semantics.

## TD-08 — Volatile chat/activity history can surprise users

- **Severity:** Medium
- **Evidence:** messages/activity are model-only; Settings exposes history.
- **Affected files:** `UniverseViewModel.swift`, chat/settings views.
- **Current impact:** history disappears after relaunch.
- **Likely future impact:** inconsistency with user expectation of “History.”
- **Safe remediation boundary:** product decision on persistence/privacy first.
- **Prerequisites:** retention/deletion and storage design.
- **Regression risks:** privacy, storage size, test isolation.

## TD-09 — Placeholder language and visualization state imply unsupported features

- **Severity:** Medium
- **Evidence:** `appLanguage` is disabled/unpersisted with no localization;
  `visualizationStyle` drives dormant spatial code only.
- **Affected files:** state/settings/spatial docs.
- **Current impact:** settings/docs can imply shipped capabilities that are not
  live.
- **Likely future impact:** users/developers make incorrect assumptions.
- **Safe remediation boundary:** product-facing setting decision; not a visual
  cleanup.
- **Prerequisites:** localization/renderer roadmap.
- **Regression risks:** settings UI and persisted contract if enabled.

## TD-10 — Experimental relation AI/cache is unreachable

- **Severity:** Medium
- **Evidence:** `RelationAI`/`RelationCache` are referenced by tests/source but
  no live production caller.
- **Affected files:** `Universe/Constellation/`, DeepSeek client/tests.
- **Current impact:** maintained code/network capability without product path.
- **Likely future impact:** unauthorized network behavior if accidentally wired.
- **Safe remediation boundary:** explicit relation-feature decision; either wire
  with privacy/error UX or retire with approval.
- **Prerequisites:** renderer/product and consent decisions.
- **Regression risks:** key handling, network, map connections.

## TD-11 — Historical documentation conflicts with source

- **Severity:** High
- **Evidence:** prior specs claim mounted rail, active 3D, non-persistent
  onboarding, old selection owners, and 2D/3D setting paths absent from current source.
- **Affected files:** many legacy `docs/*.md`, README/TestFlight materials.
- **Current impact:** agents can edit wrong systems.
- **Likely future impact:** duplicate implementations and regression risk.
- **Safe remediation boundary:** documentation ownership/archival task; do not
  rewrite historic reports without preserving their date/context.
- **Prerequisites:** renderer decision.
- **Regression risks:** none to runtime; high operational risk if unaddressed.

## TD-12 — Runtime evidence has gaps

- **Severity:** High
- **Evidence:** current worktree docs have historic pass claims, but this
  documentation task did not execute a new app/test run.
- **Affected files:** current 2D renderer, sheets, input, physical-device paths.
- **Current impact:** no fresh proof of current worktree behavior.
- **Likely future impact:** release claims based on stale results.
- **Safe remediation boundary:** verification-only task after renderer source is
  committed/stabilized.
- **Prerequisites:** an available simulator/device and clean generated project.
- **Regression risks:** false confidence, no code change needed.
