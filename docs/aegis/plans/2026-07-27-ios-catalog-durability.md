# iOS catalog durability implementation plan

## Outcome

Replace the current multi-key `UserDefaults` catalog persistence with one
versioned, validated, atomic local document in Application Support. Preserve
every valid v1 catalog through migration, retain a verified recovery copy,
support explicit export/import/reset, and make invalid persisted content a
visible recovery state rather than an empty universe.

This plan is for the native iOS app only. It intentionally does not introduce
accounts, sync, analytics, cloud storage, provider calls, or a new rendering
path.

## Aegis visibility

This is a stop-ship persistent-data migration: the current `UniverseStore`
writes six independent defaults keys, so a partial/corrupt state has no atomic
contract or recovery. The highest-risk error would be treating an unreadable
payload as an empty catalog or deleting v1 before a verified relaunch. The
plan keeps one canonical catalog owner, a reversible migration sequence, and
explicit destructive-action boundaries.

## Plan basis

- Product/design authority:
  `docs/superpowers/specs/2026-07-26-ios-local-first-platform-design.md` §§
  Architecture, Ownership rules, Data contract, Required release evidence, and
  Rollback policy.
- Current runtime authority: `ios-app/Sources/MyAIMap/State/UniverseStore.swift`,
  `UniverseViewModel.swift`, `MyAIMapApp.swift`,
  `UI/Settings/AccountSettingsSheet.swift`, and associated tests.
- Release gate authority: `ios-app/docs/TECHNICAL_DEBT.md` — catalog durability
  requires migration, recovery, export/import, reset, and relaunch tests plus
  a user-visible recovery decision.
- Product context: `ios-app/docs/PROJECT_CONTEXT.md` and
  `ios-app/docs/UI_STATE_MACHINE.md` — the Universe is device-local; seed data
  is opt-in; map navigation state remains separate from durable catalog state.

## BaselineUsageDraft

- Required baseline refs: project/iOS agent instructions; documents listed in
  Plan basis; current `UniverseStore`, `UniverseViewModel`, data models,
  settings UI, and existing persistence tests.
- Acknowledged before plan refs: all listed local refs.
- Cited in plan refs: all listed local refs.
- Missing refs: no cloud/account contract is relevant; exact visual language of
  a recovery screen may reuse existing settings-sheet components.
- Decision: continue.

## Requirement Ready Check

- Requirement source refs: approved local-first platform design and the
  stop-ship debt register.
- Goal/scope refs: Outcome and Scope fence below.
- User/scenario refs: a person adds, hides, restores, imports, exports, or
  resets local tools offline; a process interruption or bad file must not
  silently erase their catalog.
- Acceptance/verification criteria: migration, atomic failure/recovery,
  backup restore, invalid import, valid import, reset, and fresh-process
  relaunch tests; a recovery UI that exposes choices.
- Open questions: none material to the data contract. The plan selects a
  replace-not-merge import to avoid hidden conflict policy; future merge/sync
  is explicitly out of scope.
- Decision: ready.

## TDD Route

- Mode: off.
- Decision: light.
- Strict authority: not applicable.
- Test posture: add deterministic repository-level regression tests before
  wiring the production view model, then run focused post-change regression and
  relaunch/UI smoke tests. No RED/GREEN ceremony is prescribed.
- Reason: migration and file fault injection need test seams before changing
  the runtime owner, but the project does not request strict TDD.
- Verification: targeted `CatalogRepositoryTests`, existing
  `UniverseViewModelTests`, UI recovery/reset smoke, and a fresh xcresult with
  executed tests.

## Fact, assumption, and decision record

| Type | Record |
| --- | --- |
| Fact | `UniverseStore` stores tools, custom categories, hidden IDs, haptics, onboarding, and placeholder subscription separately in `UserDefaults`; `UniverseViewModel` loads/saves the tuple. |
| Fact | The current reset clears tool/category/hidden state and Settings says it cannot be undone. No export/import/recovery document exists. |
| Fact | `RelationCache`, developer flags, and Keychain are separate persistence/security surfaces and are not part of catalog v1 migration. |
| Decision | `CatalogDocument` v2 owns only tools, custom categories, and hidden IDs. Haptics, onboarding, and placeholder subscription remain small preferences in `UserDefaults`; secrets stay in Keychain. |
| Decision | Import validates an entire external document before it replaces local content; it is replace-not-merge. |
| Decision | Reset writes an empty valid v2 document only after explicit confirmation and preserves the former verified document as the recovery backup. Permanent deletion of that backup is a separate, explicitly named destructive action; it is not hidden behind Reset. |
| Assumption to test | Application Support supports atomic sibling replacement on all supported iOS 18 devices. The file adapter must make failure injection possible in tests. |

## Target contract and invariants

### Canonical owner

`CatalogRepository` is the only owner of user catalog content. It exposes a
`CatalogDocument` snapshot and mutation operations; it does not own navigation,
assistant transcript, provider/network transport, secrets, or visual state.
`UniverseViewModel` is a feature façade and delegates catalog persistence to
the repository. `UserDefaultsPreferences` owns the remaining small settings.

### Catalog document v2

```swift
struct CatalogDocument: Codable, Sendable, Equatable {
    static let currentSchemaVersion = 2
    let schemaVersion: Int
    var tools: [Tool]
    var customCategories: [ToolCategory]
    var hiddenToolIDs: Set<String>
}
```

Location (private):
`Application Support/com.ilyatur.myaimap/catalog/catalog-v2.json`.
Sibling paths: `catalog-v2.backup.json` and uniquely named temporary files;
invalid content is copied/moved to a timestamped quarantined sibling before a
recovery state is presented. None of these paths are user-visible API.

Validation before every write/import/migration/load acceptance:

- schema version is exactly supported (unknown future versions are not
  downgraded or overwritten);
- tool IDs are unique and non-empty;
- categories have unique IDs; custom category IDs do not collide with built-ins;
- every tool references an existing built-in or custom category;
- hidden IDs refer to known tools and never include
  `PlanetData.centralCoreToolID`;
- relation IDs do not refer to absent tools; malformed URLs/decoding are
  rejected rather than repaired by data loss.

### Atomic and migration protocol

1. On load, if a valid v2 document exists, decode and validate it; retain its
   last valid backup.
2. If no v2 document exists, decode v1 defaults into a `LegacyCatalogV1`
   adapter, validate it, encode v2 to a unique temporary sibling, fsync/write,
   and atomically replace/create the v2 document. Keep v1 keys intact.
3. Store a tiny `pendingV1Cleanup` preference only after the v2 write succeeds.
   On the *next* cold repository initialization, validate/reload v2. Only then
   remove the v1 catalog keys and pending marker. A failed or interrupted
   migration leaves v1 untouched.
4. Before replacing any valid v2 document (save, import, reset), preserve the
   previous validated bytes as the recovery backup, then atomically replace the
   primary. Do not alter the primary on validation or write failure.
5. If v1/v2 cannot decode or validate, never start with an empty catalog. Keep
   the original/quarantined bytes and return a typed `CatalogRecoveryState`
   with restore-backup, export-recovery-copy, and start-empty-by-explicit-reset
   options. The UI presents those choices.

### Import, export, reset, and recovery

- Export serializes the validated v2 document with a stable, documented file
  type/filename and shares it using the native file exporter. It contains no
  Keychain secrets, API keys, raw prompts, attachment bytes, or assistant
  transcript.
- Import uses the native file importer, validates fully, then asks the person
  to replace the current catalog. It preserves a verified backup first; invalid
  or unsupported content leaves the live catalog unchanged and explains why.
- Reset is an explicit Settings confirmation that replaces the current catalog
  with an empty valid v2 document and leaves the prior verified document
  available through recovery. “Delete recovery copy” is a separately named,
  confirmation-gated destructive action and is not required for this migration
  slice.
- Recovery state names the failed source (`legacy`, `primary`, or `import`),
  never displays raw private payload contents, and offers: Restore verified
  backup, Export recovery copy, Start a new empty catalog (destructive
  confirmation), and Cancel. It must be accessible and reachable after a cold
  launch.

## File map

| File | Responsibility |
| --- | --- |
| `ios-app/Sources/MyAIMap/Catalog/CatalogDocument.swift` | v2 schema, validation errors, deterministic invariants. |
| `ios-app/Sources/MyAIMap/Catalog/CatalogRepository.swift` | protocol, typed load/recovery/mutation/export/import contracts. |
| `ios-app/Sources/MyAIMap/Catalog/LocalCatalogRepository.swift` | Application Support paths, atomic writes, backup, quarantine, v1 migration. Inject a file-system abstraction for tests. |
| `ios-app/Sources/MyAIMap/Catalog/LegacyCatalogV1.swift` | Read-only adapter for the six current defaults keys; cleanup only through the migration protocol. |
| `ios-app/Sources/MyAIMap/State/UserDefaultsPreferences.swift` | haptics/onboarding/subscription preference owner, separated from catalog. |
| `ios-app/Sources/MyAIMap/State/UniverseStore.swift` | Retire as the active combined store; either remove after callers/tests migrate or narrow it to a deprecated compatibility shim with no production writes. |
| `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift` | Inject repository/preferences; map typed recovery state to presentation intent; preserve existing public user intents and map state. |
| `ios-app/Sources/MyAIMap/MyAIMapApp.swift` | Compose the real repository/preferences once and inject the model; no test-only production bypass. |
| `ios-app/Sources/MyAIMap/UI/Settings/AccountSettingsSheet.swift` | Native export/import/reset/recovery entry points and confirmation copy. |
| `ios-app/Sources/MyAIMap/UI/Settings/CatalogRecoverySheet.swift` | New focused recovery UI with accessible action identifiers and no raw payload display. |
| `ios-app/Tests/MyAIMapTests/CatalogRepositoryTests.swift` | Temporary-directory repository contract, migration, fault, import/export, recovery, and relaunch tests. |
| `ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift` | Preserve existing user flows across repository reload and reset. |
| `ios-app/Tests/MyAIMapUITests/CatalogRecoveryUITests.swift` | Cold-launch recovery, explicit destructive confirmation, and Settings export/import entry smoke. |
| `ios-app/docs/ARCHITECTURE.md`, `TECHNICAL_DEBT.md`, `QA_REGRESSION_CHECKLIST.md` | Update ownership/evidence/risk only after actual implementation evidence. |

## Implementation batches

### Batch 0 — pre-change safety baseline

1. In a new clean worktree from the accepted privacy/evidence commit, locate all
   `UniverseStore` and `UserDefaults` catalog callers. Record exact legacy keys
   and a fixture for an existing valid v1 universe, including a hidden tool and
   custom category.
2. Capture the current targeted persistence tests and their xcresult. Add no
   runtime changes in this batch.
3. Add a `CatalogRepositoryTests` temporary-directory fixture/helper that can
   simulate failed write/replace operations without using a real app-support
   directory.

Verification: `rg -n 'UniverseStore|universe\.(customTools|customCategories|hiddenToolIDs)'`; run the current focused
`UniverseViewModelTests` and confirm executed-test count is non-zero.

### Batch 1 — schema and local repository

1. Implement `CatalogDocument` and pure validation. Write tests for every
   invariant and unsupported version; do not encode default/empty fallbacks for
   invalid data.
2. Implement `LocalCatalogRepository` against injected file operations. A
   successful save must write a unique sibling temp, validate/encode, create or
   rotate recovery backup from verified primary bytes, and atomically replace
   primary.
3. Test first save, replace, forced write failure, forced replace failure,
   backup preservation, corrupt primary quarantine, and empty valid document.

Verification: focused `CatalogRepositoryTests` shows each mutation leaves a
valid primary or the prior valid primary; no test accesses the production app
support path.

### Batch 2 — v1 migration and preferences split

1. Implement a read-only `LegacyCatalogV1` decoder for current tools,
   categories, and hidden-ID keys. It must preserve present v1 data verbatim
   until v2 has survived the next repository initialization.
2. Add `UserDefaultsPreferences` for haptics, onboarding, and placeholder
   subscription; do not migrate Keychain, DeveloperMode, or `RelationCache`.
3. Implement migration-pending marker/relaunch cleanup and tests for successful
   migration, process interruption, corrupt v1, invalid v2, and cleanup only
   after second valid load.

Verification: test creates v1 defaults, initializes one repository, creates a
new repository over the same directory/defaults, then proves v2 content and
only then v1-key removal.

### Batch 3 — façade and UI integration

1. Replace `UniverseViewModel`'s combined-store dependency with catalog and
   preferences dependencies. Preserve its public `loadSampleUniverse`, add,
   hide/restore, custom-branch, onboarding, haptics, subscription, and reset
   behavior, plus its typed map/detail state.
2. Compose dependencies in `MyAIMapApp`. Make an initial repository recovery
   state observable but keep the map/UI navigation owner unchanged.
3. Add the Settings export/import actions and a focused recovery sheet. Import
   is replace-only and confirmation-gated; reset gets truthful recovery-copy
   wording. Add accessible labels and identifiers.

Verification: existing view-model persistence tests adapt to a temporary
repository; a new cold-launch recovery test proves no blank universe appears
without a person choosing reset.

### Batch 4 — end-to-end evidence and retirement

1. Add export/import byte round-trip, invalid import non-replacement, reset
   plus backup restore, and recovery decision tests. Add UI smoke for recovery
   and destructive confirmation.
2. Run focused unit tests, full unit tests, and UI smoke on a known booted
   simulator only after checking CoreSimulator health. Inspect xcresults and
   record passed/failed/executed counts.
3. Retire production `UniverseStore` only when every production caller uses the
   repository/preferences split and migration/relaunch evidence passes. If a
   compatibility shim remains, restrict it to test/migration scope and name its
   deletion trigger in `ARCHITECTURE.md`.
4. Update debt/QA/architecture docs with exact evidence; obtain independent
   spec and code-quality review before merging the migration branch.

## Compatibility and retirement

- Preserve current tool/category IDs, Codable payload semantics, hidden-tool
  behavior, protected core tool rule, custom category registration, seed
  reload behavior, and empty-by-default experience.
- Preserve `UserDefaults` for small preferences; do not migrate relation cache,
  provider flags, secrets, chat transcript, or attachments under the catalog
  label.
- Never silently merge imported catalogs or resolve conflicts; sync is a future
  additive design.
- Legacy v1 keys are retained until migration has crossed a second valid cold
  initialization. No `UserDefaults` catalog key deletion may be hidden in a UI
  reset or a generic cleanup.
- Backup cleanup/deletion requires a separately named, scoped destructive
  confirmation; do not infer it from “continue” or from reset confirmation.

## Risks and stop conditions

- Stop for a user decision if a requirement expands to cross-device sync,
  account deletion, retaining backup duration, merge semantics, or importing
  data from another app/service.
- Stop/replan if `Tool`/`ToolCategory` decoding is not stable enough for a v2
  file, rather than creating lossy repair logic.
- If the host still has CoreSimulator instability, record source-level unit
  evidence where possible and leave UI/archive/device gates open; never claim a
  release pass from zero executed tests.
- Do not delete user data, backups, or v1 keys during planning or tests outside
  isolated temporary directories.

## Plan pressure and complexity check

- Canonical owner: one repository document; `UniverseViewModel` is not a
  persistence engine after the migration.
- Architecture integrity: the preferences split prevents a new file repository
  from coexisting with a still-live multi-key production writer.
- Complexity budget: several new small, focused types are safer than growing
  `UniverseViewModel` or `UniverseStore`; each batch has a distinct seam.
- Projected risk: high for data loss, controlled by temp-directory tests,
  two-launch cleanup, backups, explicit recovery, and review gates.
- Recommendation: add dedicated catalog owner files; do not edit-in-place a
  larger combined store.

## Execution Readiness View

- Intent Lock: migrate only local catalog durability; preserve user data and
  current visible flows.
- Scope Fence: no cloud, auth, sync, analytics, billing, provider transport,
  renderer change, or broad sheet-router refactor.
- Baseline Lock: local-first design owns the v2 document/atomic/recovery
  contract; current source defines existing behavior to preserve.
- Approved Behavior: offline use, valid migration, explicit recovery, native
  import/export, and a guarded reset.
- Owner / Contract Constraints: exactly one production catalog writer;
  preferences/Keychain/relation cache keep their current boundaries.
- Compatibility Boundary: v1 stays readable until a verified relaunch; old
  IDs and selection behavior survive migration.
- Retirement Boundary: remove active `UniverseStore` writes only with passing
  migration/relaunch tests and a fresh reviewer gate.
- Test Obligations: pure validation, injected file failures, migration two-load
  proof, import/export/reset/recovery tests, focused/full unit results, UI
  recovery smoke, and later device matrix.
- Review Gates: independent spec review after Batch 2 and code-quality review
  after Batch 4; Critical/Important findings block advance.
- Drift / Rewind Rules: new account/cloud/conflict/retention decision stops the
  task; any migration failure preserves old state and returns recovery rather
  than retrying destructively.
- Evidence Required Before Completion: passing executed tests, inspected
  xcresult, recovery UI evidence, docs update, and explicit remaining device /
  archive risks.
- Advisory Boundary: method-pack execution guidance only; not release or data
  deletion authority.
