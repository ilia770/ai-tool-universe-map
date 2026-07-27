# Evidence bundle — catalog durability

| Check | Result | Scope / limitation |
| --- | --- | --- |
| Clean worktree | `codex/ios-catalog-durability` at `b6089b2` | User-owned dirty worktree remains untouched. |
| Static owner scan | `UniverseStore` is used by `UniverseViewModel` and tests; `DeveloperMode` and `RelationCache` are independent defaults users | Confirms migration scope only; not runtime behavior. |
| Current key surface | `universe.customTools.v1`, `universe.customCategories.v1`, `universe.hiddenToolIDs.v1`, `universe.hapticsEnabled.v1`, `universe.hasSeenOnboarding.v1`, `universe.subscription.v1` | Catalog migration moves only the first three; small preferences remain defaults. |
| Host test gate | `xcrun simctl list devices available` fails with CoreSimulatorService connection invalid / runtime discovery failure | No simulator/xcresult result is claimed for this slice. |
| Foundation write API | Current Swift Foundation docs describe `Data.write(to:options: .atomic)` as a temp-file, fsync, atomic-rename operation | Implementation must still inject filesystem failures and test backup ordering. |
| Production source typecheck | `xcrun --sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios18.0-simulator -parse-as-library` over the catalog source closure exits `0` | Static iOS compiler evidence for the Batch 1 production types; not an app build or XCTest run. |
| Test source parser | `swiftc -parse ios-app/Tests/MyAIMapTests/CatalogRepositoryTests.swift` exits `0` | Confirms Swift syntax only. Full test typecheck/run needs Xcode's `TestingMacros` plugin, unavailable while simulator/Xcode services are disconnected. |
| Repository contract review | Two independent source reviews found no remaining critical or important issue after fixes for deterministic decode, equality, validator coverage, fault coverage, bounded quarantine, and the A → B → failed C backup policy test | Static review only; runtime behavior remains to be executed in XCTest. |
| Native runtime harness attempt | Not executable on macOS because app models correctly import UIKit; the exact sources typecheck only against the iOS SDK | No host substitute is presented as iOS runtime evidence. |
