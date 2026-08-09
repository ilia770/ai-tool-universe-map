# TESTING_STRATEGY — Current coverage and gaps

This documents tests present in the current worktree; it does not claim a
fresh passing run. The current 2D constellation files/tests are uncommitted,
so their coverage is not yet a durable release baseline.

For transition-specific simulator recordings, interactive dismissal, and
supplied-reference comparison, use `UI_QA_CHECKLIST.md` with
`UI_TRANSITION_CATALOG.md`. Screenshot existence alone is not continuity
evidence.

## Test structure

- `Tests/MyAIMapTests/`: Swift Testing (`@Suite`, `@Test`) pure and model tests.
  Current source snapshot: 43 test files and 371 test annotations.
- `Tests/MyAIMapUITests/`: XCTest UI/capture harnesses: `UniverseUISmokeTests`,
  `GlassSurfaceRealSurfaceUITests`, `GlassMorphClusterUITests`, and
  `PolishCaptureTests`. The approved T-05 pilot will add
  `ToolDetailTransitionUITests` as the sole owner of its drag/key-frame/video
  evidence.
- Project scheme builds both targets. Root CI configuration has an iOS workflow
  that generates/builds, runs simulator unit tests, then invokes a named smoke
  test.
- Test flags (`-uitestStatic`, `-uitestSampleUniverse`, `-uitestSeedChat`,
  `-uitestOnboarding`, `-uitestFocusTool`) are coordinated by `MyAIMapApp`,
  and some are also consumed directly by renderers or `SearchDock`.

## Feature-to-test matrix

| Feature | Existing tests | Missing tests | Recommended level | Risk |
| --- | --- | --- | --- | --- |
| Model ownership / selection | `UniverseViewModelTests`, `UniverseModeTests`, `UniverseSelectionTests` | full root/map mode + local sheet race coverage | unit + UI | Critical |
| Current 2D constellation | `UniverseConstellationLayoutTests` | committed baseline, node tap/empty-tap UI assertions, actual visual comparison | unit + UI/device | Critical |
| Legacy RealityKit | scene registry/signature, layout, gesture/phase tests | decision-level test proving which renderer is active | unit + runtime | High |
| Add/custom branch | `AddToolLogicTests`, model tests | schema migration/corrupt data, full custom branch UI flow | unit + UI | High |
| Persistence | model/store behavior indirectly | relaunch, corrupt JSON, migration, reinstall/keychain boundary | unit + manual | High |
| Assistant/search | `UniverseAssistantCoreTests`, `SearchCoreTests`, `ComposerLogicTests` | real async HTTP mock integration, UI error/latency states | unit + UI | High |
| Attachments/keyboard | composer logic + UI smoke selections | real PhotosPicker/FileImporter, keyboard/auto-grow on device | UI + manual | High |
| Navigation/sheets | mode/RootShell motion tests, UI smoke | compact interactive dismissal, iPad inspector/chat coexistence | UI + manual | High |
| T-05 map tool → detail pilot | `UniverseViewModelTests`, `UniverseModeTests`, `UniverseConstellationLayoutTests` | `ToolDetailTransitionUITests`: source identity, 25/50/75% partial drag, cancel/finish, rapid reopen, after-scroll, focus return, Reduce Motion and video manifest | unit + UI + simulator | Critical |
| Onboarding | RootShell tests and UI tests | repeat relaunch/manual persistence check | UI + manual | Medium |
| Detail/browser/delete | pricing/logo/copy tests and smoke | system Safari/search errors, deletion from all modes | unit + UI + manual | Medium |
| Glass/motion/haptics | token/morph/haptic tests and capture tests | actual iOS 26 native glass, physical haptic, reduced settings visual audit | UI + physical device | Medium |
| Rail | pure gesture-state test, best-effort smoke gesture | mounted rail functionality/accessibility test | UI + manual | Medium; inactive now |
| Localization/billing/sync | none | only after those features exist | N/A | N/A |

## Verification hierarchy

1. Run narrow pure tests for touched logic.
2. Run relevant UI test(s) with deterministic launch flags.
3. Build the application/scheme from `project.yml`/generated project.
4. Perform simulator checks from `QA_REGRESSION_CHECKLIST.md`.
5. For glass, keyboard, haptics, and performance-sensitive work, validate on
   appropriate physical/device variants before release.

## Current command guidance

The iOS `AGENTS.md` records the project’s expected XcodeGen/xcodebuild gate.
Use a disposable `-derivedDataPath` and result bundle for future verification;
do not interpret the legacy XCTest “Executed 0 tests” line as Swift Testing
coverage. Inspect `xcresult` counts instead. Current repository docs contain
historic test totals that must not be quoted as fresh evidence.

## Important coverage limitations

- UI capture tests are not golden-image/snapshot comparisons.
- A full suite command was attempted for this investigation, but it did not
  produce a completed `xcresult` (the shared simulator/test runner stalled and
  the run was stopped). No fresh suite pass/fail is claimed.
- No production relation-AI integration test exists because the feature is not
  live.
- Network tests cover request/decode helpers and injected responder behavior,
  not a live service.
- System pickers, Keyboard/Focus behavior, native glass, haptics, app
  reinstallation, and actual device performance need manual/runtime evidence.
