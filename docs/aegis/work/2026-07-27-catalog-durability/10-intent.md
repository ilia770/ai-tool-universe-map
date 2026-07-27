# Task intent — catalog durability

## TaskIntentDraft

- Goal: replace the active multi-key catalog persistence with one validated v2
  Application Support document, safe v1 migration, recovery backup, explicit
  export/import/reset, and evidence that no valid data silently becomes empty.
- Parent plan: `docs/aegis/plans/2026-07-27-ios-catalog-durability.md`.
- Success evidence: temporary-directory migration and fault tests; two-launch
  v1 cleanup proof; view-model integration tests; recovery UI smoke; executed
  xcresult counts when the host simulator is available.
- Stop states: `done`, `needs-verification` when simulator infrastructure
  blocks runtime gates, `blocked` only after repeated external failure, or
  `scope-exceeded` for cloud/account/sync/merge/deletion-retention expansion.
- Non-goals: no production user-data deletion, sync, account, provider,
  renderer, or broad sheet-router change.

## BaselineReadSetHint / BaselineUsageDraft

Acknowledged: root and iOS agent instructions; project context, state machine,
QA checklist, technical debt; the catalog plan; existing `UniverseStore`,
`UniverseViewModel`, Settings UI, data models, and persistence tests; current
Swift Foundation documentation for `Data.write(to:options: .atomic)`.

## ImpactStatementDraft

This is a persistent-data ownership migration. The safe contract is a primary
document plus verified backup and two-launch cleanup; small preferences remain
in `UserDefaults`. A local test directory is the only allowed deletion target
in automated tests.
