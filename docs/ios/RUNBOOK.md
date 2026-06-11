# iOS Runbook

Last updated: 2026-06-11

Use this when running, verifying, or debugging the native My AI Map app.

## Baseline

- Xcode target: `ios-app/MyAIMap.xcodeproj`
- Scheme: `MyAIMap`
- Bundle id: `com.iliaturilia.myaimap`
- Display name: `My AI Map`
- Minimum iOS: 18.0
- Current local Xcode seen in this workspace: Xcode 26.5

## Quick Health Check

From the repo root:

```bash
git status --short --branch
xcodebuild -version
xcrun simctl list devices available
npm run ios:verify
```

`npm run ios:verify` runs:

1. Generic iOS Simulator app build.
2. Generic iOS Simulator `build-for-testing`.

It intentionally does not boot a simulator. Use it for safe agent/CI sanity.

## Full Simulator Tests

Only run full simulator tests when the simulator is healthy and you have a
specific device id:

```bash
xcrun simctl list devices available
npm run ios:verify -- --full-test --device-id <simulator-udid>
```

If tests get interrupted, split the flow:

```bash
npm run ios:test-build
xcodebuild -project ios-app/MyAIMap.xcodeproj \
  -scheme MyAIMap \
  -destination 'platform=iOS Simulator,id=<simulator-udid>' \
  -derivedDataPath ios-app/build \
  ENABLE_DEBUG_DYLIB=NO \
  test-without-building
```

## Run In Xcode

```bash
open ios-app/MyAIMap.xcodeproj
```

Then:

1. Select the `My AI Map` scheme.
2. Select an available iPhone simulator or connected iPhone.
3. Press `Cmd+R`.
4. Verify launch, RealityKit universe visibility, category focus, tool detail
   sheet, haptics on device, and no major layout overlap.

## Safe Simulator Cleanup

Use this when another agent leaves a simulator or test runner running:

```bash
ps -axo pid,ppid,stat,pcpu,pmem,command | rg 'xcodebuild -project|launchd_sim|Simulator|simctl' | rg -v rg || true
xcrun simctl shutdown all || true
```

Only kill `xcodebuild`/`simctl` processes that are clearly stale and related to
this project. Do not kill unrelated user work.

## Common Failure Modes

| Symptom | Likely Cause | First Action |
| --- | --- | --- |
| `xcodebuild test` hangs after boot | CoreSimulator migration or corrupt runtime | Stop the runner, run `npm run ios:test-build`, retry on a fresh simulator id |
| "device name matching is flaky" | Multiple runtimes/devices share a name | Use `id=<simulator-udid>`, not `name=...` |
| Archive/signing fails | Apple team id or profile missing | Configure signing after Apple Developer enrollment |
| RealityKit scene blank | entity/material/camera regression | Run `npm run ios:build`, then inspect `UniverseView.swift` and entities |

## Agent Rule

Do not run long simulator tests in the background. If a full simulator test is
needed, run it in the foreground, report the selected device id, and shut down
the simulator after the result.
