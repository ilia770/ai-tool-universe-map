# SPEC_INDEX — iOS specification map

**Status:** current document map, 2026-07-17.  
**Use:** start here after `ios-app/AGENTS.md` to determine which documents own
a decision. This index is not a substitute for source inspection.

## Read order and authority

1. `PRODUCT_SPEC.md` for current product behavior and acceptance boundaries.
2. `PROJECT_CONTEXT.md` and `ARCHITECTURE.md` for the source-verified baseline.
3. `UI_APPLE_NATIVE_SPEC.md` for permanent UI implementation architecture.
4. The relevant state/navigation/component/transition catalog.
5. The relevant feature specification and cited source/tests.

The full authority hierarchy is defined in `UI_APPLE_NATIVE_SPEC.md`.
`SPEC_CONFLICTS.md` records unresolved or deliberately deferred conflicts.

## Current normative documents

| Document | Purpose and owned decisions | Dependencies / current status |
| --- | --- | --- |
| `PRODUCT_SPEC.md` | Product behavior, user journeys, feature acceptance. | Current factual reconstruction; linked to UI architecture. |
| `PROJECT_CONTEXT.md` | Repository facts, current renderer, worktree caveats. | Source-verified baseline; not a future UI-design authority. |
| `ARCHITECTURE.md` / `REPOSITORY_MAP.md` | Composition, module boundaries, renderer boundary. | Current baseline; renderer migration remains open. |
| `STATE_OWNERSHIP.md` / `UI_STATE_MACHINE.md` | Stored vs derived state, root/map/overlay state machines. | Contains known detail-presentation risk; see SC-003. |
| `NAVIGATION_SPEC.md` / `INTERACTION_SPEC.md` | Actual routes, sheets, gestures, restoration, visible behavior. | Current behavior; pilot will amend detail transition. |
| `UNIVERSE_MAP_SPEC.md` | Current 2D map contract and historical renderer context. | Current renderer addendum takes precedence over older sections. |
| `DESIGN_SYSTEM.md` / `LIQUID_GLASS_TRANSITIONS.md` | Existing tokens, visual primitives, current glass transitions. | Component guidance; superseded for architecture rules by this set. |
| `TESTING_STRATEGY.md` / `QA_REGRESSION_CHECKLIST.md` | Automated/manual regression evidence and coverage limits. | Historical run counts are not fresh baseline evidence. |
| `ENGINEERING_WORKFLOW.md` / `SUBAGENT_GUIDE.md` | Contribution protocol, scope control, delegation. | Must enforce the mandatory UI pre-read. |
| `DATA_AND_PERSISTENCE.md`, `TECHNICAL_DEBT.md`, `OPEN_QUESTIONS.md` | Data boundaries, risks, unresolved decisions. | Supporting authority for affected changes. |

## Permanent UI-architecture documents

| Document | Owns | Status |
| --- | --- | --- |
| `UI_APPLE_NATIVE_SPEC.md` | Architecture principles, governance, mandatory agent rules. | Normative. |
| `UI_COMPONENT_IDENTITY.md` | Canonical component names, semantic identities, variants, ownership. | Baseline inventory; update with each new/replaced component. |
| `UI_COMPONENT_LIFECYCLE.md` | Transition lifecycle, restoration, interruption and focus rules. | Baseline inventory. |
| `UI_TRANSITION_CATALOG.md` | Meaningful transitions and their acceptance evidence. | Baseline inventory; tool-detail pilot is planned, not implemented. |
| `UI_MOTION_TOKENS.md` | Semantic motion roles and accessibility fallback. | Baseline mapping. |
| `UI_LAYOUT_SYSTEM.md` | Semantic layout/safe-area/adaptive contracts. | Baseline mapping and gaps. |
| `UI_TYPOGRAPHY.md` | Semantic typography and Dynamic Type contract. | Baseline mapping and gaps. |
| `UI_ACCESSIBILITY.md` | Cross-cutting accessibility contract and current coverage. | Baseline mapping and gaps. |
| `UI_QA_CHECKLIST.md` | Visual/transition verification and recording matrix. | Normative for future UI changes. |
| `UI_APPLE_NATIVE_AUDIT.md` | First-execution findings, top ten issues, remediation phases. | Audit evidence, not a product roadmap. |
| `UI_IMPLEMENTATION_REPORT.md` | What this first execution changed and did not change. | Audit/plan completion record. |
| `SPEC_CONFLICTS.md` | Conflicting sources, resolutions, and blockers. | Living conflict register. |

## Historical or narrow documents

Feature reports, older RealityKit material, prior audits, loop logs, and
`docs/superpowers/` are preserved as evidence. They must not override the
current product/source baseline merely because their title says “spec”,
“implemented”, or “QA”. `DOCUMENTATION_INDEX.md` maps those records to their
current owner.

## Document maintenance rule

When a change adds a UI component, transition, state owner, material policy,
or verification requirement, update this index only if authority changes;
otherwise update the owning catalog and relevant feature spec. Never fork a
parallel `Docs/` tree or silently replace a historical record.

