# Todo checkpoint — catalog durability

## Slice Card — Batch 1 schema and local repository

- Goal: introduce the v2 catalog schema and isolated local persistence seam;
  do not migrate legacy data or change the live `UniverseViewModel` owner yet.
- Parent plan/spec: `docs/aegis/plans/2026-07-27-ios-catalog-durability.md`,
  Batch 1.
- Files: `CatalogDocument.swift`, `CatalogRepository.swift`,
  `UniverseIdentity.swift`, model equality conformances, and focused
  repository tests.
- Boundary: no `UserDefaults` keys, migration cleanup, UI, import/export, or
  production composition changes in this slice.
- Verification: pure Swift/iOS static typecheck, parser check for the test
  suite, source review, and XCTest when CoreSimulator is healthy.
- Stop: commit the reviewed schema/repository seam before beginning v1
  migration.

## TodoCheckpointDraft

- Completed: isolated worktree created at `/private/tmp/aimap-catalog-durability`
  from `b6089b2`; required iOS docs and parent plan reread; static scan confirms
  `UniverseStore` is the combined catalog/preferences owner and only
  `UniverseViewModel` production-calls it. The exact v1 keys/ownership are
  captured in `90-evidence.md`.
- Completed: v2 schema validates every durable reference, uses a domain-level
  protected core identity, rejects malformed duplicate hidden IDs on decode,
  and serializes hidden IDs deterministically.
- Completed: local repository stages candidates, verifies and publishes a
  backup before publishing a replacement primary, returns typed safe recovery
  for invalid primary content, and never mutates that primary during recovery.
- Completed: fault-injection tests cover first save, replacement, candidate/
  backup staging, backup/primary publishing, directory/read failures, invalid
  existing primary, quarantine failure, and verified-backup detection.
- Active slice: final static validation and review of Batch 1.
- Next: commit this seam, then begin the separate v1 migration/preferences
  slice; do not wire it into production before migration tests exist.
- Blocked-on: simulator test/archive gate. `simctl list devices available`
  presently reports CoreSimulatorService connection invalid / runtime discovery
  failure. No restart is authorized because it can disrupt user simulators.

## DriftCheckDraft

- Intent / scope: aligned to local catalog durability; only the future owner
  and test seam were added.
- Compatibility: legacy keys and `UniverseViewModel` user behavior are still
  unchanged; the new repository is not composed into the app yet.
- New owner/fallback: `LocalCatalogRepository` is available but inactive;
  invalid v2 is typed recovery, never an implicit empty fallback.
- Retirement: `UniverseStore` remains live until two-launch migration evidence.
- Evidence: production-source typecheck and test parser checks pass; runtime
  XCTest remains `needs-verification` due host infrastructure.
- Decision: finish review/commit of Batch 1, then continue to read-only v1
  adapter work without changing the active persistence path.
