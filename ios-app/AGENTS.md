# iOS App — Agent Routing

Scope: the native SwiftUI/RealityKit app under `ios-app/`. This file routes
domain-specific work. It does NOT replace the repo-root `AGENTS.md`
(symlinked to `.agent/INSTRUCTIONS.md`) — that one still governs coordination,
build commands, and git etiquette. Read both.

## Every agent must read before making changes
- `ios-app/docs/PROJECT_CONTEXT.md`
- `ios-app/docs/UI_STATE_MACHINE.md`
- `ios-app/docs/QA_REGRESSION_CHECKLIST.md`

### Mandatory UI architecture pre-read

Before creating or modifying any UI, read in this exact order:

1. [PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md);
2. [UI_APPLE_NATIVE_SPEC.md](docs/UI_APPLE_NATIVE_SPEC.md);
3. [UI_COMPONENT_IDENTITY.md](docs/UI_COMPONENT_IDENTITY.md);
4. [UI_TRANSITION_CATALOG.md](docs/UI_TRANSITION_CATALOG.md); and
5. the relevant feature specification.

Start with [SPEC_INDEX.md](docs/SPEC_INDEX.md) when authority is unclear.
Record document conflicts in [SPEC_CONFLICTS.md](docs/SPEC_CONFLICTS.md);
never silently resolve a conflict from historical material. Use
[UI_QA_CHECKLIST.md](docs/UI_QA_CHECKLIST.md) for simulator/visual acceptance
and [CONTRIBUTING.md](CONTRIBUTING.md) for the contributor protocol.

## Documentation-first baseline (current repository snapshot)

Before changing code, every agent must also:

1. Read this file, then `docs/PROJECT_CONTEXT.md`, `docs/ARCHITECTURE.md`,
   and `docs/STATE_OWNERSHIP.md`; UI work additionally follows the mandatory
   pre-read above.
2. Read the relevant feature specification (`UNIVERSE_MAP_SPEC.md`,
   `RIGHT_RAIL_SPEC.md`, `INPUT_CHAT_SPEC.md`, `INTERACTION_SPEC.md`, or the
   corresponding current-baseline document). `DETAIL_SCREEN_SPEC.md` is
   historical context, not the current detail contract.
3. Inspect the implementation files and tests named by that documentation;
   documentation never replaces source inspection.
4. State the intended edit scope, state owner, protected files, acceptance
   criteria, and verification plan before editing.

Follow this boundary for all feature work:

`Research → Plan → task boundary → implementation → tests → runtime verification → documentation update`.

One task should address one domain. Do not combine a renderer, navigation,
data-model, and visual-system change in one patch without an explicit task
boundary. Do not introduce a second owner for selection, navigation, or
persisted universe data.

### Current-source rule

The current Swift source and generated Xcode project are the primary evidence
for behavior. Several older documents contain historical plans and completed
work reports; where they disagree with `PROJECT_CONTEXT.md`'s current-snapshot
addendum or the source files it names, record the discrepancy and follow the
current code until runtime verification resolves it.

### Path convention

Unless a path explicitly starts with `Sources/MyAIMap/`, `Tests/`,
`Resources/`, or the repository root, a source-file path in this document is
relative to `ios-app/Sources/MyAIMap/`. For example,
`Universe/UniverseMapView.swift` means
`ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift`.

### Protected shared systems

Coordinate before editing these systems, and do not have two agents edit the
same row concurrently:

- app composition and root route ownership: `MyAIMapApp.swift`, `RootShell.swift`;
- universe navigation/persistence: `State/UniverseViewModel.swift`,
  `State/UniverseStore.swift`, `Universe/UniverseMode.swift`;
- current map renderer boundary: `Universe/UniverseMapView.swift`,
  `Universe/UniverseConstellationView.swift`, `Universe/UniverseConstellationLayout.swift`;
- legacy RealityKit boundary: `Universe/UniverseRealityView.swift`,
  `Universe/UniverseSceneController.swift`, camera/entity/gesture files;
- assistant/input lifecycle: `UI/Search/SearchDock.swift`, `UI/Search/ChatScreen.swift`;
- Xcode generation and release configuration: `project.yml`.

## Domain routing

**Editing Universe Map**
- read `ios-app/docs/UNIVERSE_MAP_SPEC.md`
- do not edit chat/input or the rail unless explicitly asked

**Editing Right Rail**
- read `ios-app/docs/RIGHT_RAIL_SPEC.md`
- do not edit universe map rendering unless explicitly asked

**Editing Chat / Input**
- read `ios-app/docs/INPUT_CHAT_SPEC.md`
- do not edit universe map rendering or the rail unless explicitly asked

**Editing Detail**
- read `ios-app/docs/INTERACTION_SPEC.md`, `NAVIGATION_SPEC.md`, and
  `STATE_OWNERSHIP.md`; use `DETAIL_SCREEN_SPEC.md` only as dated context
- do not edit chat/input/rail unless explicitly asked

## Rules
- Do not make broad redesigns in bugfix tasks.
- Do not change more than one functional area per task.
- The single source of truth for navigation state is defined in
  `UI_STATE_MACHINE.md`. Do not add a second copy of `selectedCategory`,
  `selectedTool`, or the map mode.
- Update the relevant `.md` after every change.
- End every task with a `## Changed files / QA done / Remaining issues`
  section in the relevant spec.
- If a fix requires changing another domain, STOP and ask for a separate task.

## Verify before declaring done (per repo root AGENTS.md)
```
cd ios-app && xcodegen generate
xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/aimap-dd -resultBundlePath /tmp/aimap.xcresult
xcrun xcresulttool get test-results summary --path /tmp/aimap.xcresult \
  | grep -E '"(passedTests|failedTests|result)"'
```
"Executed 0 tests" from the legacy XCTest reporter is expected — tests use
Swift Testing; trust the xcresult `passedTests` count.
