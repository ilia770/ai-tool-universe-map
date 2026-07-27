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

## Changed files / QA done / Remaining issues

**Changed files:** Task 2 adds the typed release renderer boundary and retires
dormant RealityKit allocations from the mounted 2D path.

**QA done:** Automated evidence is the focused command run after `xcodegen
generate`:
`xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap -destination
'platform=iOS Simulator,id=450B0BBA-C072-4937-AE72-E04D83E64F80'
-only-testing:MyAIMapTests/RendererBoundaryTests
-only-testing:MyAIMapTests/UniverseModeTests -derivedDataPath
/tmp/aimap-foundation-dd -resultBundlePath
/tmp/aimap-foundation-renderer.xcresult`. Its xcresult summary reports 13
passed tests and 0 failed tests.

**Remaining issues:** RealityKit sources are intentionally retained. The
compact-detail route is now a typed `DetailRoute` owned by
`UniverseViewModel`; AppShell-level ownership for account/add-tool sheets is a
separate state/service-split plan and remains a release gate.

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
