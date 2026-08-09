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
compact-detail route still uses the existing local presentation mirror pending
Task 3; this is not a completed detail-route migration.
