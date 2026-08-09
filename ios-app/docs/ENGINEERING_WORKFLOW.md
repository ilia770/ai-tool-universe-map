# ENGINEERING_WORKFLOW — Spec-first change protocol

Use this for every implementation task. It is deliberately short enough to be
used, but it prevents a visual patch from silently becoming a renderer or
persistence rewrite.

## UI architecture preflight

Before UI work, read `PRODUCT_SPEC.md`, `UI_APPLE_NATIVE_SPEC.md`,
`UI_COMPONENT_IDENTITY.md`, `UI_TRANSITION_CATALOG.md`, and the relevant
feature specification in that order. Start from `SPEC_INDEX.md` if authority
is unclear and log conflicts in `SPEC_CONFLICTS.md`. The transition/visual
verification plan must follow `UI_QA_CHECKLIST.md`.

## Required task brief

```markdown
## Problem
What is currently wrong or missing? State only observable behavior.

## Evidence
Which current source paths, test names, screenshots, logs, or runtime
observations prove it? Label inference separately.

## Intended behavior
What must happen for the user, including success, empty, loading, error,
cancellation, and accessibility behavior where applicable?

## Non-goals
What must stay unchanged? List unrelated renderer, navigation, persistence,
or visual systems explicitly.

## Scope
Allowed files and the single domain being changed.

## Protected scope
Files/systems that must not change. Include relevant rows from
`REPOSITORY_MAP.md`.

## State ownership
Which canonical state is read or mutated? Why is no second source of truth
introduced? Cite `STATE_OWNERSHIP.md`.

## Acceptance criteria
Observable, testable outcomes — not implementation preferences.

## Test plan
Narrow automated tests, relevant UI test, and exact simulator/manual path.

## Rollback strategy
How to revert the patch without erasing unrelated work or persisted data.

## Documentation impact
Which current-owner documents change after the behavior is verified? Use the
mapping in `CHANGELOG_DOCUMENTATION.md`; update every affected owner without
creating a competing spec.
```

## Execution sequence

1. **Research.** Read `AGENTS.md`, `PROJECT_CONTEXT.md`, `ARCHITECTURE.md`,
   `STATE_OWNERSHIP.md`, relevant feature spec, cited source, and tests.
2. **Plan.** State one coherent patch boundary. If evidence points to two
   domains (for example renderer and keyboard), split the work unless coupling
   is unavoidable and explicitly approved.
3. **Implement.** Change the smallest coherent set of files. Preserve the
   current owner and current visual behavior outside acceptance criteria.
4. **Test.** Run the narrowest falsifiable test first, then relevant unit/UI
   tests and build. Use fresh result evidence, not an old docs pass count.
5. **Runtime verification.** Exercise the manual path on the appropriate
   simulator/device, especially map taps, sheets, keyboard, glass, and
   persistence boundaries.
6. **Document.** Update every current-owner document listed by
   `CHANGELOG_DOCUMENTATION.md` for the changed behavior. Add dated evidence to
   a history document only when it remains useful; do not create a competing
   spec.

## Project-specific guardrails

- Do not change `RootShell.surface` and `UniverseMode` in one “small” task
  without saying how root/full-chat and in-map-chat semantics remain distinct.
- Do not add storage for a value that is currently derived from `UniverseMode`.
- Do not change `UniverseStore` keys or `Tool` Codable shape without a
  migration/corruption plan and tests.
- Treat `UniverseMapView` as a renderer boundary: current 2D constellation,
  dormant RealityKit code, and map overlay hooks must not be mixed casually.
- Do not revive the rail, camera, or 3D gestures as a by-product of cosmetic
  work. They need explicit interaction/accessibility/runtime acceptance.
- Do not infer attachment understanding, cloud sync, billing, localization, or
  a hosted assistant from placeholder types/UI.
- Preserve existing dirty worktree changes owned by other people. Never reset,
  reformat, delete, or regenerate files outside the task.

## Completion standard

A task is ready to report only when it has fresh evidence for its stated
acceptance criteria, no unrelated tracked files changed, current behavior has
been manually exercised where automation cannot prove it, and the appropriate
documentation is updated. A passing build alone does not validate glass,
keyboard, touch, or state-restoration behavior.
