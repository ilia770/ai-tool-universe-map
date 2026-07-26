# Task 3 — typed compact-detail route report

## Status

Implemented and committed as `a677419` (`refactor(ios): make compact detail
route typed`). The commit contains only the eleven Task 3 source, tests, and
documentation files named in the task brief; the required handoff report is
intentionally left as the requested working-tree artifact.

## Implementation

- Added `DetailRoute`, an `Identifiable`/`Equatable` value containing the
  visible tool id and exact `UniverseMode` return state.
- `UniverseViewModel` now owns `private(set) var detailRoute` and the
  `requestDetail(for:)`, `dismissDetail()`, and `replaceDetailTool(with:)`
  intents. Requests reject missing and hidden ids. Dismissal restores the
  captured mode before clearing the route. Related selection replaces the
  route and restores to the newly selected related tool.
- Replaced `UniverseMapView`'s `detailPresented` and `modeBeforeDetail`
  timing mirrors with one compact `Binding<DetailRoute?>` and native
  `.sheet(item:)`. Its binding nil write, `onDismiss`, and visible close all
  delegate to the idempotent `dismissDetail()` intent.
- Preserved existing detents, background interaction, drag indicator, corner
  radius, and sheet appearance. T-05 shared-element/hero/custom-drag work was
  not added and is explicitly blocked in the new transition catalog.
- Kept the regular-width inspector selection-derived. Kept root
  `RootShell.surface` separate from `UniverseViewModel.universeMode`.
- Kept the Detail → Account/Add handoff values unchanged: 0.22s and 0.18s.
  The lack of a global app-sheet owner is recorded as a state/service-split
  follow-up, not replaced with a view-local owner.

## TDD and test coverage

Route-state tests were added before the implementation changes for visible,
missing/hidden, cancelled-drag preservation, exact restoration, and related
tool replacement. `UniverseModeTests` covers the mode-only detail return
helper. The compact UI smoke now uses the deterministic Coding → Codex →
Claude Code relation and exercises a partial cancelled drag, visible close,
rapid reopen, related-tool replacement, and post-dismissal hittable star ids.

## Verification

- `xcodegen generate` completed successfully.
- `git diff --check` and `git diff --cached --check` completed cleanly before
  commit.
- XcodeBuildMCP was configured for `MyAIMap` on AIMapGate
  (`0645CAEE-891B-41C3-A240-AFD30E43C260`) and attempted the required focused
  `UniverseViewModelTests`, `UniverseModeTests`, and
  `UniverseUISmokeTests/testCaptureKeyStates` scope with result bundle
  `/tmp/aimap-foundation-route.xcresult`.
- The MCP test call timed out at its 300-second tool limit without streaming
  progress. It reduced free capacity from about 3.9 GiB to 773 MiB. The
  result-bundle directory remains untouched. After the timeout, its finalized
  xcresult summary reported 69 passed tests and 1 failed test (`result:
  Failed`): `MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates()` failed
  at “Branch card should expose a stable selected branch label.” The run does
  not meet the required fresh `failedTests == 0` / `passedTests > 0` gate, and
  this report makes no passing-test claim.

## Files committed

- `ios-app/Sources/MyAIMap/State/DetailRoute.swift`
- `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift`
- `ios-app/Sources/MyAIMap/Universe/UniverseMode.swift`
- `ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift`
- `ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift`
- `ios-app/Tests/MyAIMapTests/UniverseModeTests.swift`
- `ios-app/Tests/MyAIMapUITests/UniverseUISmokeTests.swift`
- `ios-app/docs/STATE_OWNERSHIP.md`
- `ios-app/docs/INTERACTION_SPEC.md`
- `ios-app/docs/NAVIGATION_SPEC.md`
- `ios-app/docs/UI_TRANSITION_CATALOG.md`

## Baseline preservation and self-review

Before editing, the exact user-owned visual diff in `UniverseMapView.swift`
and `UniverseOverlayView.swift` was captured at
`/private/tmp/aimap-task3-user-dirty.SeeeTf/pre-task-visual.diff` (SHA-256
`5eecfab3a41328afbdc08b9fa3589e112bf87823a56f4dc318efc4596e35d02c`,
9,081 bytes). `git apply --check --reverse` against the working tree passed
without mutation after implementation, proving the snapshot remains applicable.

Because `UniverseMapView.swift` was already dirty, a temporary alternate index
was used to derive and stage only its Task 3 diff. The pre-existing visual
hunks stayed unstaged. No reset, checkout, clean, deletion, reformat, staging,
or commit captured the baseline user work. The committed diff from base
`92bdcb0` contains only the eleven Task 3 files above.

## Remaining concerns

- Re-run the required focused scope after the user provides storage or repairs
  the simulator runner; retain the existing `/tmp` artifacts unless the user
  explicitly authorizes their removal.
- The user-owned, unstaged `UI_STATE_MACHINE.md` still contains obsolete
  `detailPresented`/`modeBeforeDetail` wording. It was not edited because it
  was pre-existing user work outside the Task 3 staged file list.
- T-05 remains blocked pending a supplied and reviewed visual reference.
- The global app-sheet ownership/state-service split remains necessary before
  removing the existing Account/Add delayed handoff.

## Fix round 1 — stale branch-card smoke assertion

**Root-cause evidence:** the first focused result reported the failure at
`app.staticTexts["PlanetInfoCard.SelectedBranch"]`. Current committed renderer
source renders `SpatialRevealCard` only for `.toolSelected`, not
`.branchFocus`; the separate user-owned visual diff can render `PlanetInfoCard`,
but its identifier is attached to a composite accessibility element rather than
a `StaticText`. This pre-detail assertion is therefore stale and independent of
the Task 3 route behavior.

**Changed expectation:** after tapping `ConstellationCategory.coding`, the
smoke now waits for and requires a hittable `ConstellationStar.codex`. That star
exists only after Coding branch focus and is immediately used by the next test
step. The obsolete SelectedBranch assertion and its now-unused category-name,
category-id, seed lookup, and graph lookup plumbing were removed. No production
accessibility or UI source was changed.

**Command:** after `xcodegen generate`, XcodeBuildMCP ran the required focused
scope on AIMapGate (`0645CAEE-891B-41C3-A240-AFD30E43C260`) with
`-only-testing:MyAIMapTests/UniverseViewModelTests`,
`-only-testing:MyAIMapTests/UniverseModeTests`, and
`-only-testing:MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates`, using
the new bundle `/tmp/aimap-foundation-route-fix1.xcresult`.

**Fresh xcresult summary:** 69 passed, 1 failed, 0 skipped (`result: Failed`).
The only failing test is `UniverseUISmokeTests/testCaptureKeyStates()` at
“Visible close should fully dismiss detail.” The stale branch-card assertion no
longer fails; the run reached compact detail. No further test run was started.

**Baseline preservation:** the snapshot at
`/private/tmp/aimap-task3-user-dirty.SeeeTf/pre-task-visual.diff` still has
SHA-256 `5eecfab3a41328afbdc08b9fa3589e112bf87823a56f4dc318efc4596e35d02c`,
and `git apply --check --reverse` still succeeds without mutation. User visual
changes remain unstaged.

## Fix round 2 — sheet-local close dismissal

**Hypothesis:** clearing the model-owned route through the computed custom
binding does not reliably dismiss the already-visible `.sheet(item:)` in this
integration. The red UI smoke evidence showed that `UniverseDetail.Close` was
tapped while `RootSheet.ToolDetail` remained visible and map nodes stayed
disabled, despite passing `UniverseViewModel.dismissDetail()` unit coverage.

**Exact change:** `UniverseMapView` now places a dedicated
`DetailCloseControl` inside its presented-sheet overlay. The control reads
`@Environment(\.dismiss)` and, in one tap handler, calls
`model.dismissDetail()` followed by local `dismiss()`. The model route remains
authoritative. The existing idempotent optional-route binding setter and
`onDismiss` reconciliation remain unchanged. No state mirror, detent,
appearance, or user-owned visual source changed.

**Command:** XcodeBuildMCP was run on AIMapGate for the same required focused
scope using the new result path `/tmp/aimap-foundation-route-fix2.xcresult`.

**Fresh result status:** the MCP call hit its 300-second tool timeout. The new
bundle is preserved but remains incomplete (contains `Data` and `Staging`, with
no `Info.plist`), so `xcresulttool` cannot produce a summary. No additional
test run was started. At the final read-only check, free disk capacity was
about 2.7 GiB.

**Baseline preservation:** the pre-task visual snapshot SHA is unchanged and
the non-mutating reverse-apply check still passes. User visual changes remain
unstaged.

## Fix round 3 — close control inside sheet content

**Root cause:** read-only accessibility inspection identified the previous
`UniverseDetail.Close` as a RootSheet overlay using the iOS 26 glass path with
an 11.84 × 11.84 AX hit envelope. The close action could therefore be missed
even when the test addressed its identifier.

**Exact change:** `RootSheet` now accepts optional `onClose` ownership. Only
the compact `UniverseMapView` sheet supplies it; the regular-width inspector
continues without a phantom close control. When supplied, RootSheet renders the
same visual close treatment in its scroll-content header as a normal Button
with Button-level `frame(width: 44, height: 44)` and `contentShape(Circle())`.
The handler invokes the injected `model.dismissDetail()` callback and RootSheet
local `@Environment(\.dismiss)`; no new route or presentation flag was added.
The existing binding setter, `onDismiss`, detents, background, drag indicator,
and corner radius are unchanged. The UI smoke now asserts the close is hittable
before it taps, and separates the basic close check from the cancelled-drag
check.

**Command:** XcodeBuildMCP ran the required focused
`UniverseViewModelTests`, `UniverseModeTests`, and
`UniverseUISmokeTests/testCaptureKeyStates` scope on AIMapGate with existing
derived data and `/tmp/aimap-foundation-route-fix4.xcresult`.

**Fresh xcresult summary:** 69 passed, 1 failed, 0 skipped (`result: Failed`).
The prior close assertion passed. The sole failure is later in the same UI
smoke: “Related-tool selection should replace the visible detail tool.” No
further test run was started. Free capacity after the run was about 621 MiB.

**Baseline preservation:** the pre-task visual snapshot still reverse-applies
without mutation and user visual changes remain unstaged.

## Fix round 4 — sheet-scoped related-tool smoke

**Root-cause evidence:** the finalized fix-4 activity log showed the global
`More` query existed but was not hittable. Its coordinate fallback tapped the
application at normalized Y `1.31`, then the test tapped the underlying
`ConstellationStar.claude-code` rather than a related-tool control inside the
sheet. The resulting title remained Codex, so that run did not exercise the
model's related-route replacement path.

**Exact change:** `UniverseUISmokeTests` now scopes both the `More` disclosure
and the Claude Code relation to `RootSheet.ToolDetail` button descendants. It
scrolls only until `More` both exists and is hittable, asserts hittability for
both controls, then uses direct element taps. The cancelled partial-drag and
all route-restoration assertions remain intact. No production source changed;
the compact route implementation remains as committed in `1a9c3c4`.

**Command:** XcodeBuildMCP ran exactly one fresh target test on AIMapGate
(`0645CAEE-891B-41C3-A240-AFD30E43C260`) with existing derived data:
`MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates`, writing
`/tmp/aimap-foundation-route-fix5.xcresult`.

**Fresh xcresult summary:** 1 passed, 0 failed, 0 skipped (`result: Passed`).
The finalized bundle contains `Info.plist`; no further test run was started.

**Baseline preservation:** the pre-task visual snapshot still reverse-applies
without mutation and user visual changes remain unstaged.
