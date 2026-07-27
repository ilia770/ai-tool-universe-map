# Todo checkpoint — catalog durability

## Slice Card — Batch 2 v1 migration and preferences split

- Goal: make existing v1 catalog data safely readable by v2 and separate the
  remaining small preference owner; do not change the live `UniverseViewModel`
  owner or UI yet.
- Parent plan/spec: `docs/aegis/plans/2026-07-27-ios-catalog-durability.md`,
  Batch 2.
- Files: `LegacyCatalogV1.swift`, `CatalogMigrationCoordinator.swift`,
  `UserDefaultsPreferences.swift`, catalog protocol/test seam updates, and
  focused migration tests.
- Boundary: no ViewModel/App composition, legacy combined-store deletion, UI,
  import/export, or destructive backup operation in this slice.
- Verification: pure Swift/iOS static typecheck, parser check for the test
  suite, independent source review, and XCTest when CoreSimulator is healthy.
- Stop: commit the reviewed migration seam before routing production startup
  through it.

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
- Completed: Batch 1 committed as `43c84e7` in the isolated catalog branch.
- Completed pending runtime verification: `LegacyCatalogV1` treats any partial,
  malformed, duplicate-hidden-ID, or semantically invalid three-key v1 payload
  as recovery rather than silently replacing missing values with empty arrays.
- Completed pending runtime verification: the coordinator writes v2 before its
  pending marker, records a SHA-256 fingerprint of the exact migrated v1
  bytes, samples that marker only at construction, and removes exactly the
  three catalog keys only after a later coordinator/repository initialization
  loads valid v2 and finds the fingerprint unchanged. A missing primary with a
  pending marker is recovery, never a fresh empty universe; a rollback-build
  v1 rewrite is also recovery, never an implicit delete.
- Completed pending runtime verification: `UserDefaultsPreferences` owns only
  haptics, onboarding, and placeholder subscription keys, retaining their v1
  defaults and excluding Keychain, DeveloperMode, and RelationCache.
- Completed: two independent migration/source reviews found no remaining
  Critical or Important defect after the version-skew fingerprint fix. The
  latter is covered by an A → migration → rollback-build B → next-init test.
- Completed: static iOS production typecheck and full static Swift Testing
  macro/typecheck of the Batch 1/2 catalog suites exit cleanly; `git diff
  --check` is clean.
- Completed: Batch 2 committed as `730d24b` in the isolated catalog branch.
- Completed pending runtime verification: production startup now composes a
  single `LocalCatalogRepository`, v1 migration coordinator, and
  `UserDefaultsPreferences` in `MyAIMapApp`; `UniverseViewModel` receives those
  owners rather than the combined store. Existing `UniverseStore` is retained
  only behind an explicit test-compatibility initializer.
- Completed pending runtime verification: catalog intents use commit-before-
  apply; failed writes leave visible arrays/activity/seed registry unchanged.
  A top-level non-dismissible native recovery sheet blocks map/chat actions,
  supports verified-backup restore, explicit start-empty confirmation, and
  continuation with the last verified primary after a transient save failure.
- Completed pending runtime verification: explicit start-empty clears only the
  technical pending marker after publication, never v1 bytes; it rotates a
  valid existing v2 primary through the regular backup protocol.
- Active slice: Batch 3 export/import/recovery-copy operations and their UI.
- Next: add replace-only native import/export and recovery-copy export without
  weakening the current recovery/backup boundaries.
- Blocked-on: simulator test/archive gate. `simctl list devices available`
  presently reports CoreSimulatorService connection invalid / runtime discovery
  failure. No restart is authorized because it can disrupt user simulators.

## DriftCheckDraft

- Intent / scope: aligned to local catalog durability; the v2 owner is now the
  only production catalog writer, while UI remains local-first and native.
- Compatibility: legacy combined-store behavior remains only for legacy unit
  tests; production startup uses the new composition root. No old key is
  deleted outside the two-launch migration or an explicit recovery policy.
- New owner/fallback: `LocalCatalogRepository`, migration coordinator, and
  preferences owner are active; invalid v1/v2 is a blocking typed recovery,
  never an implicit empty fallback.
- Retirement: `UniverseStore` remains live until two-launch migration evidence.
- Evidence: all production sources typecheck with Xcode Observation/Preview
  macro plugins; catalog/migration/ViewModel test suites typecheck with the
  Xcode Swift Testing macro plugin. Runtime XCTest remains
  `needs-verification` due host infrastructure.
- Decision: commit the reviewed integration/recovery slice, then implement
  import/export before declaring Batch 3 complete.
