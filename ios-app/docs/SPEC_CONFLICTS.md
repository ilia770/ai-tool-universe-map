# SPEC_CONFLICTS — iOS specification conflict register

**Status:** living register, initialized 2026-07-17.  
**Protocol:** record a conflict before choosing an interpretation. Resolve it
through product intent and the smallest safe implementation change; keep both
the evidence and decision visible.

| ID | Conflicting evidence | Decision / status | Required follow-up |
| --- | --- | --- | --- |
| SC-001 | Earlier `PROJECT_CONTEXT.md` hierarchy treated current source as first authority; the permanent UI architecture hierarchy places explicit product intent and project specifications above source. | **Resolved.** Source remains the factual baseline; product specs decide what, `UI_APPLE_NATIVE_SPEC.md` decides how future UI is built. | Keep `PROJECT_CONTEXT.md` factual; do not use it to override product intent. |
| SC-002 | Historical iOS and RealityKit documents describe an active 3D universe; current `UniverseMapView` mounts `UniverseConstellationView`. | **Resolved for baseline.** 2D constellation is current live renderer; RealityKit is retained/dormant. | Make a separate renderer-boundary decision before reactivating/removing 3D. |
| SC-003 | `UniverseViewModel.universeMode` is presented as canonical map state, while compact detail also uses `detailPresented` and `modeBeforeDetail` in `UniverseMapView`. | **Open architectural defect.** The current app works as a baseline but does not meet one-owner transition-state policy. | The first pilot removes this split from its path; see `UI_TRANSITION_CATALOG.md`. |
| SC-004 | Root Ask AI and in-map assistant share transcript data but have distinct surface/navigation restoration behavior. | **Resolved policy.** They are separate semantic route domains until a product decision explicitly unifies them. | Document parent/restoration semantics before any consolidation. |
| SC-005 | Root README calls repository screenshots “visual references”; `TESTING_STRATEGY.md` says captures are not golden comparisons. The supplied attachment contains only text, no PNG/MOV/Figma reference. | **Open acceptance blocker.** Existing artifacts are baseline evidence only, not the supplied visual reference. | Obtain a named reference asset/device/OS contract before final pilot visual acceptance. |
| SC-006 | `DESIGN_SYSTEM.md`, `LIQUID_GLASS_VISUAL_SPEC.md`, `DESIGN_SYSTEM_RUBRIC.md`, and older audits overlap in material/motion guidance. | **Resolved governance.** Permanent catalogs own architecture-level policy; older documents remain component guidance or history. | Add links rather than deleting historical material. |
| SC-007 | `AdaptiveLayout.sheetDetents`/`AdaptiveDetailContainer` define a shared policy, while live `UniverseMapView` hard-codes different detail detents. | **Open implementation divergence.** No visual change is authorized in this phase. | Resolve as part of a scoped detail architecture change after the pilot design is accepted. |
| SC-008 | Historical QA records report passed suites/captures, while current baseline docs say no fresh full-suite result exists for this dirty worktree. | **Resolved evidence policy.** Historical runs are historical only. | Record fresh result bundles before making release-quality claims. |

## Blocker rule

SC-005 blocks only the pilot's final visual-reference comparison. It does not
block documentation, build, component inventory, transition inventory, or the
pilot design. Do not substitute an old screenshot for a supplied reference and
claim equivalence.

