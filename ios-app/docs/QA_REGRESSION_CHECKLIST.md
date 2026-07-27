# QA_REGRESSION_CHECKLIST

Run after every task. Build green + Swift Testing pass is necessary but NOT
sufficient — the visual/state items need a simulator run (iPhone 17 + an
iPhone SE-class device + iPad). Confirm tests via the xcresult `passedTests`
count, not "Executed 0 tests".

## Build / test gate
- [ ] `xcodegen generate` clean
- [ ] `xcodebuild test` → BUILD SUCCEEDED, 0 compiler errors/warnings (ours)
- [ ] xcresult `passedTests` ≥ prior count, `failedTests == 0`

## State machine (single source of truth)
- [ ] Selected category matches across: 3D map, bottom chips, right rail,
      bottom card.
- [ ] Selected tool matches across map highlight and detail card.
- [ ] No state where detail and chat are both the primary overlay.
- [ ] Dismiss chat returns to the exact previous map mode + selection.
- [ ] Dismiss detail returns to the previous map mode + selection.

## Input / chat
- [ ] Focus input → keyboard rises, universe dims slightly, NOT black/empty.
- [ ] Attachment icon: paperclip (empty) → menu → file pill (attached).
- [ ] Attachment menu appears above input, dismisses on outside tap, not stuck
      after send/remove.
- [ ] Remove attachment available only when attached; resets to paperclip.
- [ ] Send disabled with no text + no attachment; enabled otherwise; clears on
      successful send.
- [ ] Exactly one Add-tool and one Attach-files control visible per state.
- [ ] Missing-tool suggestion chip opens Add Tool with that tool name and
      branch prefilled.

## Add Tool
- [ ] Adding an already-visible tool by same name/domain focuses it instead of
      creating a suffixed duplicate.
- [ ] Adding a hidden tool by same name/domain restores and focuses it.
- [ ] `http://` website input is stored/opened as `https://`.

## Right rail
- [ ] Rail is edge-only, never a wide panel; does not cover the map.
- [ ] Active rail does not coexist with an open keyboard.
- [ ] Release over a category focuses that branch; highlight matches selection.

## Universe map
- [ ] No overlapping/clipped labels; selected node unambiguous.
- [ ] No "bubble soup" (labels appear around focus, not all at once).
- [ ] OpenSwarm (core satellite) appears + is focusable when selected.
- [ ] Smooth gestures (no per-frame label-reprojection jank on low-end device).

## Detail
- [ ] Logo fallback renders (no broken-image box) for tools without a logo.
- [ ] Card shows the same tool as the map highlight.
- [ ] Reads as a product card, not an admin dashboard.
- [ ] Related tools update compact detail in-place.
- [ ] On iPad, related tools update the trailing inspector without dimming the
      map.

## UI smoke
- [ ] Launch smoke with `-uitestStatic -uitestSampleUniverse` so graph mode is
      deterministic and populated.
- [ ] Prefer accessibility labels (`Category node,...`, `Tool node,...`) over
      stale 3D coordinates for functional taps.

## Catalog durability / native transfer
- [ ] Cold-launch a corrupt v2 primary: app shows non-dismissible recovery,
      does not render an implicit empty map, and can restore a verified backup.
- [ ] Export a populated catalog; import it through the native picker; verify
      explicit replacement confirmation and backup rotation before publication.
- [ ] Reject malformed, over-5-MiB, and over-interactive-budget imports without
      changing the visible catalog or its verified backup.
- [ ] Export a raw recovery copy, cancel/fail the exporter, and confirm Start
      Empty remains blocked until exporter completion and reports failure.
- [ ] Start empty only after destructive confirmation; relaunch and verify no
      interrupted migration marker returns the app to recovery.

## Device matrix (visual)
- [ ] iPhone 17 (and a Pro Max) — no overlap/clipping.
- [ ] iPhone SE-class (small) — no overflow; controls reachable.
- [ ] iPad — layout adapts (TARGETED_DEVICE_FAMILY=1,2).
- [ ] Dynamic Type larger sizes — text scales, no truncation of key copy.
- [ ] Dark mode (app is dark-first).

## Stabilization run - 2026-06-21

**Automated**
- [x] `git diff --check` clean before verification.
- [x] `npm run ios:test-build` passed after the final visualization cleanup.
- [x] Clean focused unit run passed on iPhone 17 Pro:
      `xcodebuild ... -derivedDataPath ios-app/build-final-test
      -only-testing:MyAIMapTests test`; 178 tests passed, 0 failed.
- [x] UI smoke passed:
      `UniverseUISmokeTests/testCaptureKeyStates`; 1 test passed, 0 failed.

**Manual simulator states checked**
- [x] Fresh launch in 2D Graph with no black side strip.
- [x] Input focus keeps composer above the keyboard.
- [x] Attachment Photo/Files popover stays anchored above the input.
- [x] General chat send does not return the missing-service fallback.
- [x] Add Tool sheet keeps Name/Website reachable with keyboard open.
- [x] Auto/Manual branch controls update visible state correctly.
- [x] Mode chip opens Account settings.
- [x] Settings switch changes 2D Graph <-> 3D Spatial.
- [x] 3D Experimental view no longer shows square background artifacts.

**Still needs real-device QA**
- [ ] iPhone TestFlight pass for the full checklist above.
- [ ] iPhone SE-class small-width visual pass.
- [ ] iPad regular-width detail/related-tool pass.

## First-run / Liquid Glass navigation check - 2026-06-22

**Automated**
- [x] All required UX specs were present before code review:
      `FIRST_RUN_SPEC.md`, `LAYERING_AND_NAVIGATION_SPEC.md`,
      `LIQUID_GLASS_VISUAL_SPEC.md`, `CHAT_INPUT_SPEC.md`,
      `CHAT_AI_SPEC.md`, `ADD_TOOL_SPEC.md`,
      `SETTINGS_PROFILE_SPEC.md`, `IMPLEMENTATION_ROADMAP.md`.
- [x] `git diff --check` clean before verification.
- [x] Targeted composer-state regression passed:
      `xcodebuild ... -only-testing:MyAIMapTests/ComposerLogicTests test`;
      25 tests passed, 0 failed.
- [x] Full unit gate passed through the project script:
      `bash scripts/ios-verify.sh --run-tests --device-id
      EAC2C682-5C38-44DB-8FEC-034E296E8EEA`; 263 tests passed in 32 suites,
      0 failed.
- [x] UI smoke passed:
      `UniverseUISmokeTests/testCaptureKeyStates`; 1 test passed, 0 failed.

**States covered by UI smoke**
- [x] Fresh launch exposes the map-first route and the Ask AI control.
- [x] Ask AI opens the chat composer.
- [x] Map control returns from chat to the map.
- [x] Category and tool graph nodes are tappable.
- [x] Tool detail opens from the selected card.
- [x] Settings opens from the chat surface.
- [x] Input focus works; attachment menu opens, dismisses on outside tap, then
      reopens and selects Files.

**Still needs real-device QA**
- [ ] Liquid Glass morph smoothness on a physical iPhone.
- [ ] TestFlight pass for collapsed chat: collapse with transcript, then tap/pan
      the map and confirm no transparent chat layer blocks gestures.
- [ ] Real-device attachment pass: Photo opens Photos picker, Files opens the
      system file importer, selected items render the floating glass preview,
      and removal clears the staged attachment. UI smoke uses deterministic
      picker payloads under `-uitestStatic` to avoid system modal flake.

## Follow-up stabilization pass - 2026-06-22

**Implemented**
- [x] Chat attachments now use production `PhotosPicker` / `fileImporter`
      entry points instead of only placeholder enum staging. The assistant still
      answers honestly that it cannot read attachment contents yet.
- [x] 3D Spatial default tuning is calmer while it remains Experimental:
      fewer background stars, smaller/lower-opacity stars, weaker orbit/link
      lines, and reduced default node/glow scale.
- [x] Tool Detail and Settings removed the remaining heavy category-colored
      filled panels from website, pricing, upgrade, and render-mode controls.

**Automated**
- [x] `xcodebuild ... -only-testing:MyAIMapTests/ComposerLogicTests test`;
      25 tests passed, 0 failed.
- [x] `xcodebuild ... -only-testing:MyAIMapTests/UniverseSelectionTests test`;
      6 tests passed, 0 failed.
- [x] `scripts/ios-verify.sh --run-tests --device-id EAC2C682-5C38-44DB-8FEC-034E296E8EEA`;
      265 tests / 32 suites passed.
- [x] `xcodebuild ... -only-testing:MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates test`;
      1 UI smoke test passed, 0 failed.

## GitHub CI QA gates - 2026-06-25

**Now automated in GitHub Actions**
- [x] Web verify: typecheck, lint, Vitest, production audit, production build,
      bundle budget.
- [x] Web visual smoke: Playwright desktop/tablet/mobile Chromium projects,
      with CI screenshots, traces/report, and `test-results` uploaded as the
      `playwright-visual-smoke` artifact.
- [x] iOS compile gate: `xcodegen generate` +
      `scripts/ios-verify.sh --test-build-only` on `macos-26`.
- [x] iOS simulator unit gate:
      `scripts/ios-verify.sh --run-tests --device-id <sim-id>` with
      `MyAIMapTests.xcresult` and summary uploaded.
- [x] iOS UI smoke gate:
      `scripts/ios-verify.sh --run-ui-tests --device-id <sim-id>` running
      `MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates`; screenshots
      and accessibility trees are kept in `MyAIMapUITests.xcresult`.

**Still human-reviewed**
- [ ] Screenshot/design judgement: CI captures the evidence, but a human still
      reviews screenshots for taste, hierarchy, overlap, and TestFlight polish.
- [ ] Real-device QA: physical iPhone, SE-class, and iPad behavior remains a
      release gate because simulator screenshots do not prove touch feel,
      system picker behavior, or RealityKit/device performance.

## Local-first foundation evidence — 2026-07-27

### Automated clean-worktree gate

This is fresh, run-specific evidence for the local-first renderer and typed
compact-detail route. It is **not** a substitute for the manual matrix below.

| Field | Evidence |
| --- | --- |
| Source | Detached, clean worktree at `6896759dfe1ba33aa3733f070242bc500a7befa8` (`fix(ios): add constellation typography tokens`). The generated `MyAIMap.xcodeproj` is ignored and was not a source change. |
| Run window | 2026-07-27 02:05:48–02:08:38 MSK |
| Xcode | Xcode 26.5 (Build version 17F42) |
| Simulator | AIMapGate — iPhone 16 Pro, iOS Simulator 26.5, OS build 23F77 (`0645CAEE-891B-41C3-A240-AFD30E43C260`) |
| Result bundle | `/tmp/aimap-foundation-route-fix9-clean-token.xcresult` |
| xcresult summary | `passedTests: 71`, `failedTests: 0`, `skippedTests: 0`, `result: Passed` |

The result bundle covers the focused `UniverseMode` and `UniverseViewModel`
tests plus `UniverseUISmokeTests/testCaptureKeyStates`. The UI test is an
automated simulator smoke gate only; it does not constitute a manual visual,
accessibility, or physical-device sign-off.

### Manual device and accessibility matrix

All items below are **not run** in this task. No manual simulator pass,
physical device, or performance trace was supplied for this evidence update;
therefore no launch, interaction, accessibility, or performance claim is
inferred from the automated result bundle.

| Check | Status | Reason |
| --- | --- | --- |
| Compact iPhone / SE-class: cold and warm launch; map category/tool/empty taps; Map ↔ Ask AI; keyboard and attachment cancel; detail cancel/finish/reopen | Not run | No compact-device manual pass in this task. |
| Current iPhone: same journey | Not run | AIMapGate supplied automated iPhone 16 Pro simulator coverage only; no manual or physical-device pass was performed. |
| iPad regular width: same journey and inspector behavior | Not run | No iPad simulator or physical-device pass in this task. |
| Dynamic Type | Not run | No manual larger-text-size pass in this task. |
| VoiceOver | Not run | No VoiceOver traversal or announcement pass in this task. |
| Reduce Motion | Not run | No setting-specific behavior pass in this task. |
| Instruments on supported low-end and current physical iPhones | Not run | No physical devices or SwiftUI/Time Profiler traces were available in this task. |

### Remaining release gates

- Run and record the manual matrix above before release approval.
- Measure cold/warm launch-to-interactive, first map interaction, branch
  selection, chat opening, typing, CPU, memory, and frame pacing with matching
  before/after Instruments traces on physical supported low-end and current
  iPhones.
- Complete a clean release archive, signing validation, TestFlight pass,
  privacy manifest/labels/policy review, and security release review before
  submission.
- Deliver the separately planned catalog durability, root sheet-router, and
  release-only assistant hardening before treating this foundation as an App
  Store-ready architecture.
