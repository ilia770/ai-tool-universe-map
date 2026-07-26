# My AI Map iOS — Local-First Platform Design

**Status:** approved direction, 2026-07-26  
**Decision owner:** product + iOS architecture  
**Scope:** native iPhone/iPad application only

## Decision

Ship a **2D-first, local-first** My AI Map. The application must open and let
a person browse, add, remove, export, and restore their own catalog without
an account or network connection. A cloud account, synchronization, and hosted
AI are opt-in extensions behind stable repository/service interfaces; they are
not dependencies of the first App Store release.

The live renderer is the SwiftUI `UniverseConstellationView`. RealityKit is not
part of the release runtime. It remains only in a separate, historical branch
until a new ADR, device measurements, accessibility evidence, and TestFlight
approval justify a distinct renderer experiment.

## Options considered

| Option | Result | Reason |
| --- | --- | --- |
| Restore RealityKit-first map | Rejected | The saved baseline reports a long first shader/PSO warm-up and the present product contract prioritizes readable, tappable tool relationships. |
| 2D-first local app with optional cloud adapters | Selected | Fastest reliable native path; works offline; has ordinary SwiftUI accessibility semantics; does not pre-commit the product to a server architecture. |
| Build global sync, accounts, graph, and hosted AI now | Deferred | It would introduce privacy, account recovery, conflict resolution, abuse, cost, and availability requirements before the local product has a proven release loop. |

## Architecture

```text
MyAIMapApp
├─ AppShell
│  ├─ AppRoute: map | askAI
│  └─ AppSheetRoute: detail | addTool | account
├─ Universe feature
│  ├─ UniverseNavigationState: one map-selection source
│  └─ UniverseConstellationView: one mounted 2D renderer
├─ Catalog feature
│  ├─ CatalogRepository protocol
│  ├─ CatalogDocument v2 + preferences
│  └─ atomic local file, migration, backup, export/import
├─ Assistant feature
│  ├─ LocalAssistantService
│  └─ HostedAssistantService (unavailable in v1 release)
└─ Release evidence
   ├─ unit/UI/device performance and accessibility gates
   └─ privacy manifest, policy, provenance, TestFlight checklist
```

### Ownership rules

| Concern | Owner | Explicit non-owner |
| --- | --- | --- |
| Map versus Ask AI surface | `AppShell` | `UniverseMode` |
| Current category/tool and map visual mode | `UniverseNavigationState` | view-local `@State` mirrors |
| Detail/Add/Account presentation | one typed `AppSheetRoute` at `AppShell` | competing map/root Boolean flags |
| User catalog, hidden IDs, custom categories | `CatalogRepository` document | individual `UserDefaults` JSON keys |
| Small preferences | `UserDefaults` | catalog document |
| Secrets | Keychain | catalog document and `UserDefaults` |
| Local assistant transcript/session | `AssistantSession` | persistence unless a person explicitly enables it |

`UniverseViewModel` becomes a feature façade during migration. It may compose
the catalog, navigation, and assistant services temporarily, but it must not
remain the persistence engine, root router, network transport, and UI state
owner simultaneously.

## Data contract

`CatalogDocument` is a versioned, validated JSON file in Application Support.
It contains the user-owned tool list, custom categories, hidden IDs, and a
schema version. It does not contain API keys, token data, raw AI prompts, or
ephemeral UI state.

Write protocol:

1. Validate domain invariants, including the protected core identity.
2. Encode the full document to a unique temporary sibling file.
3. Atomically replace the current document.
4. Keep the last verified document as a recovery backup.
5. Delete legacy v1 `UserDefaults` blobs only after successful migration and
   relaunch verification.

Invalid v1 or v2 data never means “start empty.” The repository must quarantine
the payload, expose recovery/export choices, and preserve the previous file.

## AI and network boundary

The first release uses `LocalAssistantService` only. All developer-provider
code must be compiled out of Release or removed from its target. In particular,
the release cannot contain a path that sends the user query or catalog to a
third-party provider.

If a hosted service is approved after v1, the path is:

```text
iOS consent + app auth token
  → API gateway (auth, quota, abuse controls)
  → prompt minimizer + audit metadata without prompt text
  → provider credential held only by server
  → response + local fallback
```

It requires a separate threat model covering consent, deletion, retention,
rate limits, App Attest strategy, incident response, and regional data policy.

## Scalability boundary

The client must support deterministic layouts and searches at 1,000 local
tools before sync is considered. A future sync platform is additive:

```text
CatalogRepository
  ↕ opt-in idempotent sync operations
Auth / API gateway → tenant catalog/graph store → change-log queue → workers
```

The local document remains readable and editable while offline. Conflict policy,
account deletion, tenancy, regional deployment, SLOs, and cost limits are
separate ADRs; no speculative “billions of users” backend is built in the
native hardening project.

## Required release evidence

- One mounted renderer and no dormant renderer/controller initialization.
- Atomic catalog migration, recovery, export/import, reset, and relaunch tests.
- Fresh `xcresult` evidence from unit tests and UI smoke tests; a test command
  with zero executed tests is a failure of the verification gate.
- Compact iPhone, current iPhone, and iPad checks; Dynamic Type, VoiceOver,
  Reduce Motion, keyboard, partial and complete sheet dismissal.
- Release-device cold/warm launch, first map interaction, map selection,
  search typing, chat opening, memory, CPU, battery, and frame-pacing trace.
- Accurate `PrivacyInfo.xcprivacy`, App Store privacy declaration, in-app
  privacy policy, support URL, licenses/provenance, signing/archive check, and
  staged TestFlight rollout.

## Foundation evidence record — 2026-07-27

The automated foundation gate was run from the detached clean worktree at
commit `6896759dfe1ba33aa3733f070242bc500a7befa8`. The only generated project
artifact was the ignored `MyAIMap.xcodeproj`; no source change was included in
the evidence.

| Field | Recorded value |
| --- | --- |
| Xcode | Xcode 26.5 (Build version 17F42) |
| Simulator | AIMapGate — iPhone 16 Pro, iOS Simulator 26.5, OS build 23F77 |
| xcresult | `/tmp/aimap-foundation-route-fix9-clean-token.xcresult` |
| Outcome | 71 passed, 0 failed, 0 skipped, result `Passed` |
| Automated coverage | Focused `UniverseMode` and `UniverseViewModel` tests plus `UniverseUISmokeTests/testCaptureKeyStates` |

This is fresh automated simulator evidence for the exact source revision, not
a claim of release-device quality. The compact/current iPhone and iPad manual
journeys; Dynamic Type, VoiceOver, and Reduce Motion; and SwiftUI/Time Profiler
traces on low-end and current physical iPhones were **not run** because this
task had neither a manual pass nor physical-device performance traces.

The following gates therefore remain open: catalog migration/recovery and
export/import; AppShell sheet-router migration; release-only assistant,
privacy, and security review; clean archive/signing; and staged TestFlight
validation. No performance improvement is claimed without matched
before/after traces from the same device and build.

## Rollback policy

Every implementation task is one branch/PR with a fresh reviewer gate. A
catalog migration preserves source data until it has passed a relaunch check.
The release rollback is a phased-release halt plus a previously signed build;
it never discards or downgrades a user’s local document without a tested
recovery path.
