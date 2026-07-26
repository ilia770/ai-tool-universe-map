# State ownership

| State | Owner | Boundary |
| --- | --- | --- |
| Root Map / Ask AI route | `RootShell.surface` | Root routing only; it is separate from map navigation. |
| Map selection and navigation | `UniverseViewModel.universeMode` | The sole stored map-navigation value; selection is projected from it. |
| Compact detail, account, and add-tool presentations | `UniverseMapView` | Temporary local presentation state until Task 3 replaces the compact-detail mirror. |

`UniverseMapView` reads and writes the model-owned `universeMode`; it does not
store a second map-selection value. The release renderer consumes that mode to
lay out the 2D constellation. The current system-sheet behavior is preserved.

## Changed files / QA done / Remaining issues

**Changed files:** Task 2 documents the current owner boundaries while
isolating the release renderer.

**QA done:** Automated evidence is the focused command run after `xcodegen
generate`:
`xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap -destination
'platform=iOS Simulator,id=450B0BBA-C072-4937-AE72-E04D83E64F80'
-only-testing:MyAIMapTests/RendererBoundaryTests
-only-testing:MyAIMapTests/UniverseModeTests -derivedDataPath
/tmp/aimap-foundation-dd -resultBundlePath
/tmp/aimap-foundation-renderer.xcresult`. Its xcresult summary reports 13
passed tests and 0 failed tests.

**Remaining issues:** Compact detail is still a local presentation mirror;
Task 3 owns its route migration. No 3D release path or completed detail-route
migration is claimed here.
