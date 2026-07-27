# Architecture

## Current render path

The release map is `UniverseMapView` → `UniverseConstellationView`. Its typed
selection is `MapRendererKind.release == .constellation2D`. The constellation
owns deterministic 2D layout, category/tool presentation, and the semantic
accessibility identifiers `ConstellationCategory.<id>` and
`ConstellationStar.<id>`.

RealityKit sources remain retained legacy material: `UniverseRealityView`,
`UniverseSceneController`, `CameraRigController`, `UniverseGestureController`,
and their supporting entity/layout files. The release map constructs none of
`UniverseSceneController`, `CameraRigController`, or
`UniverseGestureController`.

The overlay supplies chrome, empty state, selection context, and system-sheet
triggers. It no longer projects labels through a legacy camera; live node
placement and labels come from the 2D constellation.

## Catalog durability and transfer boundary — 2026-07-27

`CatalogRuntimeDependencies` composes one `LocalCatalogRepository`, migration
coordinator, and preferences owner for `UniverseViewModel`. The versioned v2
catalog lives in Application Support; preferences, Keychain values, chat, and
relation cache are separate owners. Catalog mutations commit a validated
candidate before the model applies it. A corrupt primary yields an app-level,
non-dismissible recovery surface rather than a silent empty map.

Settings exports only validated catalog JSON. Import receives a security-scoped
URL, reads no more than 5 MiB plus one byte off the UI actor, validates the
schema and interactive renderer budget, then requires replacement confirmation
before backup rotation and publication. Raw corrupt recovery bytes export as
generic data rather than normal JSON. The current renderer budget is 512 tools,
64 custom categories, 64 relations per tool, 4,096 total relations, and bounded
user-controlled string fields; increasing it requires a schema/performance
decision, not a UI-only change.

## Changed files / QA done / Remaining issues

**Changed files:** Task 2 adds the typed release renderer boundary and retires
dormant RealityKit allocations from the mounted 2D path. The 2026-07-27
durability slice adds the catalog repository/document/transfer/recovery
boundary described above.

**QA done:** Automated evidence is the focused command run after `xcodegen
generate`:
`xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap -destination
'platform=iOS Simulator,id=450B0BBA-C072-4937-AE72-E04D83E64F80'
-only-testing:MyAIMapTests/RendererBoundaryTests
-only-testing:MyAIMapTests/UniverseModeTests -derivedDataPath
/tmp/aimap-foundation-dd -resultBundlePath
/tmp/aimap-foundation-renderer.xcresult`. Its xcresult summary reports 13
passed tests and 0 failed tests.

For the durability slice, all production sources emitted an iOS simulator
module and the focused catalog Swift Testing sources typechecked with Xcode's
macro plugin. An independent security diff scan finalized with zero reportable
findings after two availability fixes. These are not executed XCTest/UI
results.

**Remaining issues:** RealityKit sources are intentionally retained. The
compact-detail route is now a typed `DetailRoute` owned by
`UniverseViewModel`; AppShell-level ownership for account/add-tool sheets is a
separate state/service-split plan and remains a release gate.

Catalog durability code and focused tests have static compiler evidence only
in this worktree. Focused/full XCTest, recovery/import-export UI smoke, and
fresh xcresult inspection remain required before release closure.

## Local-first foundation evidence — 2026-07-27

The renderer and typed compact-detail route were validated in a detached clean
worktree at commit `6896759dfe1ba33aa3733f070242bc500a7befa8`. The only
generated project artifact was the ignored `MyAIMap.xcodeproj`; it was not
treated as a source change.

| Gate | Result |
| --- | --- |
| Toolchain | Xcode 26.5 (Build version 17F42) |
| Target | AIMapGate, iPhone 16 Pro, iOS Simulator 26.5 (OS build 23F77) |
| Fresh result | `/tmp/aimap-foundation-route-fix9-clean-token.xcresult` — 71 passed, 0 failed, 0 skipped; result `Passed` |
| Automated scope | Focused `UniverseMode` and `UniverseViewModel` tests plus `UniverseUISmokeTests/testCaptureKeyStates` |

This confirms the automated simulator gate for this exact clean source
revision. It does not prove the manual device matrix, VoiceOver, Dynamic Type,
Reduce Motion, physical-device performance, archive/signing, TestFlight,
privacy, or release security gates. Those remain required before an App Store
release claim.

## Release privacy/archive evidence — 2026-07-27

The application now has one checked-in declarative privacy resource at
`Sources/MyAIMap/Resources/PrivacyInfo.xcprivacy`. It declares only the local
`UserDefaults` required-reason API (`CA92.1`), with no tracking and no collected
data declaration. `plutil -lint` passed and a fresh XcodeGen project placed the
file in the app Resources build phase; it is the source-of-truth resource,
whereas `MyAIMap.xcodeproj` remains generated and ignored.

An unsigned Release archive retry failed before completion (exit 65): the host
CoreSimulatorService disconnected while `ibtool` / `actool` processed iOS
assets, then Xcode reported no available simulator runtimes and `iOS 26.5
Platform Not Installed`. Consequently, this record does not claim that an
archive contains the manifest, that signing works, or that TestFlight/App Store
gates are complete. It keeps the archive verification gate in
`TECHNICAL_DEBT.md` open.
