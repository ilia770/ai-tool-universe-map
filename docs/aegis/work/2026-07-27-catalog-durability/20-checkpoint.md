# Todo checkpoint — catalog durability

## Slice Card — Batch 0 baseline

- Goal: record the active v1 persistence surface and create an isolated test
  seam without changing production catalog behavior.
- Parent plan/spec: `docs/aegis/plans/2026-07-27-ios-catalog-durability.md`,
  Batch 0.
- Files: this work record; then `CatalogRepositoryTests.swift` only after the
  fixture contract is fully established.
- Boundary: no production persistence owner, UI, user defaults, Application
  Support, or user data may change in this slice.
- Verification: static caller/key scan and current targeted test command when
  CoreSimulator is healthy.
- Stop: checkpoint all keys/callers and host result; proceed to schema/repo
  only after the temporary-directory seam is specified.

## TodoCheckpointDraft

- Completed: isolated worktree created at `/private/tmp/aimap-catalog-durability`
  from `b6089b2`; required iOS docs and parent plan reread; static scan confirms
  `UniverseStore` is the combined catalog/preferences owner and only
  `UniverseViewModel` production-calls it.
- Active slice: Batch 0 legacy persistence baseline.
- Next: extract exact v1 keys/fixtures and create only the repository-test
  helper; do not migrate code yet.
- Blocked-on: simulator test/archive gate. `simctl list devices available`
  presently reports CoreSimulatorService connection invalid / runtime discovery
  failure. No restart is authorized because it can disrupt user simulators.

## DriftCheckDraft

- Intent / scope: aligned to local catalog durability.
- Compatibility: legacy keys and `UniverseViewModel` user behavior still
  unchanged.
- New owner/fallback: none introduced yet.
- Retirement: `UniverseStore` remains live until two-launch migration evidence.
- Evidence: static source baseline complete; runtime baseline
  `needs-verification` due host infrastructure.
- Decision: continue with non-destructive test-seam preparation only.
