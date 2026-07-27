# Evidence bundle — catalog durability

| Check | Result | Scope / limitation |
| --- | --- | --- |
| Clean worktree | `codex/ios-catalog-durability` at `b6089b2` | User-owned dirty worktree remains untouched. |
| Static owner scan | `UniverseStore` is used by `UniverseViewModel` and tests; `DeveloperMode` and `RelationCache` are independent defaults users | Confirms migration scope only; not runtime behavior. |
| Current key surface | `universe.customTools.v1`, `universe.customCategories.v1`, `universe.hiddenToolIDs.v1`, `universe.hapticsEnabled.v1`, `universe.hasSeenOnboarding.v1`, `universe.subscription.v1` | Catalog migration moves only the first three; small preferences remain defaults. |
| Host test gate | `xcrun simctl list devices available` fails with CoreSimulatorService connection invalid / runtime discovery failure | No simulator/xcresult result is claimed for this slice. |
| Foundation write API | Current Swift Foundation docs describe `Data.write(to:options: .atomic)` as a temp-file, fsync, atomic-rename operation | Implementation must still inject filesystem failures and test backup ordering. |
