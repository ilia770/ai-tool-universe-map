# UI_APPLE_NATIVE_AUDIT — First execution audit

> **Findings kept, programme not adopted — 2026-08-09.** The inventory in this
> document — what exists, what is wired, which issues were found — is accurate
> and worth keeping. The five-phase remediation programme it proposes was not
> accepted and does not schedule any work. It is preserved because several
> documents link here for the findings.


**Status:** audit and plan only, 2026-07-17. No production UI was modified.  
**Scope:** native iOS source, tests, existing specifications, build baseline,
components, transitions, and visual-verification readiness.

## Evidence collected

- Inspected the iOS specification set and current-source baseline; the
  authority map is in `SPEC_INDEX.md` and contradictions in `SPEC_CONFLICTS.md`.
- Built the actual dirty snapshot successfully for iOS Simulator.
- Mapped the live shell: `MyAIMapApp` → `RootShell` (Map/Ask AI) →
  `UniverseScreen` → `UniverseMapView` → `UniverseConstellationView` with
  `UniverseOverlayView`, compact detail sheet or regular inspector.
- Inventoried major components and transitions in
  `UI_COMPONENT_IDENTITY.md` and `UI_TRANSITION_CATALOG.md`.
- Tried to capture a fresh simulator baseline. The available iOS 18 simulator
  service failed during install/launch; the iOS 26.5 fallback did not provide
  an admissible rendered baseline. This is not evidence of an app defect.
- The supplied attachment contains no visual PNG/MOV/Figma reference. Existing
  repository artifacts cannot be promoted to supplied-reference evidence.

## Application shell and navigation map

```text
MyAIMapApp
  └─ UniverseViewModel (app lifetime)
       └─ RootShell.surface
            ├─ Map: UniverseScreen → UniverseMapView
            │    ├─ UniverseConstellationView (live 2D renderer)
            │    ├─ UniverseOverlayView / SearchDock
            │    └─ compact RootSheet OR regular inspector
            └─ Ask AI: ChatScreen / SearchDock
```

`UniverseViewModel.universeMode` is the canonical stored map-navigation value;
`selection` is a derived projection. The compact detail path adds local
presentation mirrors, which is the principal transition-state defect.

## Top ten architectural UI problems

Line references are baseline evidence in a dirty worktree and may shift. No
finding authorizes an unrelated implementation change.

| Rank / severity | Exact evidence and observed behavior | Architecture cause | Smallest safe remediation / verification |
| --- | --- | --- | --- |
| 1 — P1 | `UniverseMapView.swift` local `detailPresented`/`modeBeforeDetail` (lines 12–13, 132–162) mirror `UniverseViewModel.universeMode`; `pendingDetailToolID` is another entry path (`UniverseViewModel.swift` 275–286). | One semantic detail transition has multiple owners and a one-shot request channel. | Pilot a single typed detail route/transition owner; assert programmatic open, drag dismiss, delete, and restoration all converge. |
| 2 — P1 | `ConstellationStar.<toolID>` exists (`UniverseConstellationView.swift` 147), but map tool → `RootSheet` has no shared transition ID. `UniverseConstellationLayout.swift` 136–148 removes the selected-tool state for `.detail`. | Source and destination are replaced rather than held as one conceptual object. | Use `ToolDetailTransitionID.tool(tool.id)`, source reservation, a shared namespace/host, and record reverse return to the same star. |
| 3 — P1 | `UniverseConstellationView.swift`, `UniverseConstellationLayout.swift`, and focused tests are untracked while tracked `UniverseMapView.swift` mounts them. | The active renderer cannot be reproduced by a clean checkout even though code/tests depend on it. | Before broad UI work, include the renderer/tests in the project's normal version-control change. This audit does not stage or alter user work. |
| 4 — P1 | Live `UniverseMapView.swift` mounts 2D at line 58 but still creates RealityKit scene/camera/gesture controllers at lines 9–11 and calls camera lifecycle code. | Two renderer lifecycles are coupled in one live host, even though only one renderer is visible. | Make an explicit renderer-boundary decision after the pilot: detach dormant controller lifecycle or isolate a deliberate renderer strategy. |
| 5 — P1 | `RootShell.surface` owns root Chat while `UniverseMode.chatOpen` and `UniverseMapView.setChatOpen` own an in-map assistant state. | One user intent spans two navigation graphs with different restore/cancel semantics. | Preserve them as explicit distinct typed routes for now; define parent/restoration model before consolidation. |
| 6 — P1 | `SearchDock.swift` derives `chatIsActive` from local focus/collapse (107–115), calls upward (193–196), then mutates local state from global mode (215–234); `submit` contains a timing workaround (977–985). | A local/global feedback loop rather than a clear ownership boundary. | Later define a session route contract: model owns route/session intent; view owns only ephemeral focus/gesture details. Verify keyboard/collapse/reopen. |
| 7 — P2 | Both `RootShell.swift` (125–127, 202–212) and `UniverseMapView.swift` (14–20, 163–173) host Account/Add flags and sheets. | Same semantic presentation is duplicated by active surface. | After the pilot, select a typed sheet router or document strict host-local boundary; test dismissal/draft cleanup from both roots. |
| 8 — P2 | `AdaptiveLayout.swift` defines shared detail detents/container, but `UniverseMapView.swift` 156–162 uses independent hard-coded detents. | Adaptive policy is split between a helper and production composition. | Fold into an approved detail architecture decision; verify compact/regular/iPad behavior without blindly normalizing values. |
| 9 — P2 | `LiquidGlassCard.swift`, `PlanetInfoCard.swift`, and portions of overlay use glass/content-like surfaces; `GlassMorphCluster.swift` defaults public AX IDs to `base.<index>`. | Material layer policy and reusable semantic identity API are incomplete. | Catalog functional vs content surfaces, replace positional public IDs with semantic option IDs, then scope material cleanup separately. |
| 10 — P1 | UI tests capture static screenshots (`UniverseUISmokeTests.swift`, `PolishCaptureTests.swift`) but do not record video, partial drag/cancel, or source-return identity; no supplied visual reference exists. | Verification proves existence, not continuity, progress ownership, or visual match. | Make the recording/reference matrix a pilot gate; do not accept “Apple-like” from compilation or old screenshots. |

## Additional baseline observations

- The 2D renderer is thin, callback-driven, deterministic, and has stable
  category/tool accessibility IDs. These are strong pilot foundations.
- The current Account/Add zoom pair demonstrates iOS 18 source/destination
  API usage, but it does not prove the map-detail interaction.
- `UniverseRailView`, `CategoryRail`, and portions of spatial UI are present
  but unmounted; they are not active product navigation/accessibility paths.
- `BrandMotion`, `BrandSpacing`, and `BrandTypography` are useful existing
  centralization points, but their current values/limits remain project
  decisions requiring visual/accessibility evidence.

## Phased remediation plan

| Phase | Scope | Gate before proceeding |
| --- | --- | --- |
| 0 — completed | Documentation, baseline build, inventories, audit, pilot plan. | No production UI change; audit review. |
| 1 — state and identity pilot | Compact map tool → detail only; one owner, stable IDs, continuity, reverse interactive dismissal. | Deterministic recordings, source-return assertion, Reduce Motion pass, supplied-reference comparison. |
| 2 — renderer/reproducibility | Version-control active 2D renderer/tests; decide/detach legacy RealityKit lifecycle. | Clean checkout build and renderer-boundary tests. |
| 3 — navigation and presentation | Resolve root/in-map assistant boundaries; Account/Add presentation ownership; related-tool route behavior. | Typed-route and restoration tests per affected domain. |
| 4 — component/material/layout | Semantic `GlassMorphCluster` IDs, functional glass policy, shared adaptive detail policy, Dynamic Type/safe-area fixes. | Device/type/accessibility matrix plus visual review. |
| 5 — verification and cleanup | Expand transition catalog coverage, record all meaningful transitions, remove obsolete paths only after evidence. | Fresh result bundles, simulator artifacts, and updated documentation. |

## Recommended pilot

Implement exactly **selected constellation tool node → compact Tool Detail**
after review. It is the narrowest representative transition that proves stable
source identity, source-to-destination continuity, reverse interactive
dismissal, one state owner, simulator recording, and visual-reference
comparison. The full implementation/verification contract and exact future
file manifest are in `UI_TRANSITION_CATALOG.md`; this phase intentionally
stops before it.
