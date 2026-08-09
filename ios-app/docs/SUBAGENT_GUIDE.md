# SUBAGENT_GUIDE — Safe delegation for My AI Map

## Rules for every delegated task

- Give one narrow domain, concrete file boundaries, and a clear completion
  boundary. Research agents may inspect broadly but must not edit code.
- A subagent must not redefine product requirements from a TODO, historical
  spec, or preferred architecture.
- Do not have two agents edit the same shared state, renderer, visual primitive,
  root shell, or documentation file concurrently.
- Tell an implementation agent which state owner it may read/mutate and which
  source paths are protected.
- Require the agent to inspect current source, not only historical docs. The
  worktree presently contains a 2D/legacy-3D transition.

## Recommended roles

| Role | Narrow responsibility | Typical non-editing output |
| --- | --- | --- |
| Repository investigator | inventory/config/history/current dirty-state facts | paths, target/scheme, authority conflicts. |
| Architecture analyst | bootstrap, dependency/state/navigation trace | owner matrix and diagrams. |
| SwiftUI implementation agent | one explicitly listed UI feature | small patch, tests, simulator evidence. |
| 2D map specialist | current constellation renderer/layout only | layout/tap/accessibility evidence. |
| RealityKit specialist | dormant spatial scene only | reactivation risk and runtime plan; no broad deletion. |
| State-management reviewer | `UniverseViewModel` / mode/persistence boundary | duplicate source/transition findings. |
| Test author | named missing test seam only | test scope, false-positive/negative analysis. |
| UI regression reviewer | one device/surface matrix | screenshots/observations, not speculative design changes. |
| Documentation reviewer | factual consistency/path validation | contradictions, unlabeled inference, stale claims. |

## Required return format

Every subagent return must include:

```markdown
## Findings
## Evidence (paths, types, tests, or runtime observations)
## Files inspected
## Files changed (or “none”)
## Assumptions / labels (CONFIRMED, INFERRED, UNKNOWN)
## Risks and follow-up boundaries
## Verification performed and result
```

## Conflict matrix

| Area A | Area B | Safe in parallel? | Reason |
| --- | --- | --- | --- |
| Pure constellation-layout tests | Assistant wording/unit tests | Yes | no shared production owner. |
| Documentation research | Read-only renderer audit | Yes | no writes; combine evidence afterward. |
| RootShell route change | ChatScreen transition change | No | shared root/full-chat semantics and namespaces. |
| UniverseViewModel mutation | AddToolSheet behavior | No by default | sheet commits through model/persistence. |
| UniverseMode change | UniverseMapView / SearchDock | No | mode drives both map and in-map chat. |
| Current constellation renderer | Legacy RealityKit reactivation | No | competing renderer ownership/selection semantics. |
| Shared glass primitive | Any feature visual change | No | primitive affects all consumers. |
| Right rail revival | Map gesture work | No | touch priority/accessibility coupling. |
| Detail content copy | Assistant pure logic | Usually | verify they do not both touch `UniverseViewModel`. |
| Persistence migration | Any catalog/UI mutation | No | one storage/schema source of truth. |

## Delegation examples

Good: “Inspect only `UniverseConstellationLayout.swift` and its tests. Return
whether the selected-node visual frames can overlap at 393×852; do not edit.”

Good: “Add one unit test for a documented `UniverseStore` corrupt-payload
behavior. Do not change `UniverseViewModel`, `project.yml`, or UI.”

Not safe: “Make navigation and 3D interactions better.” It spans root route,
map mode, dormant renderer, gestures, and accessibility without an owner.
