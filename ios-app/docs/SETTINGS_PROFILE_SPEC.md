# SETTINGS_PROFILE_SPEC

Owner domain: account/settings sheet controls and settings-backed model fields.
Primary file: `UI/Settings/AccountSettingsSheet.swift`.

Do not use this spec to edit chat/input, tool detail, Add Tool, or universe
renderer internals beyond wiring settings to real state.

## Visualization Setting

The visualization setting is a real renderer switch backed by
`UniverseViewModel.renderMode`:
- `2D Graph` — stable default.
- `3D Spatial` — labelled Experimental.

Changing the setting swaps the renderer live and persists through
`UniverseStore`. The current map selection is preserved because both renderers
read the same `UniverseMode`, `PlanetData`, and model intents.

The old `VisualizationStyle` A/K/N/O presets are not exposed as enabled
settings. They remain only as internal 3D renderer tuning values.

## Existing Settings

Language, haptics, sample universe, reset universe, and hidden-tool restore are
outside the visualization task. Their existing behavior is intentionally left
unchanged by Agent 9.

## Acceptance Criteria

- Tapping `2D Graph` selects the graph renderer.
- Tapping `3D Spatial` selects the RealityKit renderer and shows it as
  Experimental.
- Selection persists across model reloads / app relaunch.
- No enabled visualization control remains that has no visible effect.
- Build and tests pass.

## Changed files / QA done / Remaining issues

### Agent 9 — visualization setting wiring (landed)

**Changed files**
- `UI/Settings/AccountSettingsSheet.swift` — replaced old visualization preset
  rows with `UniverseRenderMode` rows.
- `Universe/UniverseOverlayView.swift` — top badge reports current renderer and
  points users to Settings for switching.
- `State/UniverseSelection.swift`, `State/UniverseViewModel.swift`,
  `State/UniverseStore.swift` — model and persistence backing.
- `Tests/MyAIMapTests/UniverseViewModelTests.swift` — render mode default and
  persistence coverage.

**QA done**
- `git diff --check` clean before verification.
- `npm run ios:verify` succeeded, including XcodeGen project generation,
  app build, and build-for-testing.
- Focused `xcodebuild test` on `iPhone 17 Pro` simulator succeeded for
  `UniverseGraphLayoutTests` and render-mode persistence tests.
- `.xcresult`: `result` Passed, `passedTests` 5, `failedTests` 0,
  `skippedTests` 0.

**Remaining issues**
- Manual QA should verify relaunch persistence on simulator/device.

### Codex follow-up - settings behavior stabilization (2026-06-21)

**Mode chip.** The overlay render-mode chip is now tappable and opens Account
settings. It uses subtle status copy (`Tap to switch`) instead of looking like
a dead primary control.

**Language.** Manual language selection is disabled until implemented. The
sheet explains that System follows the device language, so the setting no
longer appears functional when it is not.

**Haptics.** The haptics toggle now persists through `UniverseStore`, and the
view model reloads the saved value on app/model startup.

**QA done**
- Manual simulator check switched 2D/3D from settings and verified the language
  explanatory copy and haptics toggle presence.
- Unit coverage verifies haptics persistence across model reloads.
