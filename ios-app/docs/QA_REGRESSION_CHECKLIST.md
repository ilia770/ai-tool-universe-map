# QA_REGRESSION_CHECKLIST

> **Current-baseline warning — 2026-07-16.** Use **Current worktree smoke
> matrix** below for the mounted 2D renderer. The initial checklist and dated
> run records preserve historical 3D/rail-era evidence; they are not proof of
> current behavior or a fresh passing run.

Run after every task. Build green + Swift Testing pass is necessary but NOT
sufficient — the visual/state items need a simulator run (iPhone 17 + an
iPhone SE-class device + iPad). Confirm tests via the xcresult `passedTests`
count, not "Executed 0 tests".

For permanent UI architecture and transition evidence, this checklist is
supplemented by `UI_QA_CHECKLIST.md` and `UI_TRANSITION_CATALOG.md`. In case of
conflict, use `SPEC_INDEX.md`/`SPEC_CONFLICTS.md` rather than treating a dated
run record as current acceptance.

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

---

## Current-worktree regression baseline — 2026-07-16

The checklist above contains historical run records. Use this section for
future patches against the current source; execute it rather than treating any
previous pass count as fresh evidence.

### Smoke checks — every patch

| Setup | Exact action | Expected visible result | Expected state result | Failure symptoms |
| --- | --- | --- | --- | --- |
| Fresh simulator, no saved data | Launch app | map with onboarding overlay | `hasSeenOnboarding == false` | chat-only launch, missing overlay, blank screen. |
| Onboarding | Tap Skip, relaunch | map remains visible; overlay stays dismissed | onboarding flag persisted | overlay repeats or blocks map. |
| Empty map | Tap “Load a sample universe” | category/tool constellation appears | seed tools persisted/visible | still empty card, duplicate tools, crash. |
| Populated map | Tap category then tool then empty space | branch, selected tool, then step-back visual changes | one coherent `UniverseMode` path | wrong tool/card, dead nodes, map does not step back. |
| Populated map compact width | Re-tap selected tool; swipe detail sheet down | detail sheet opens and dismisses cleanly | valid restored map mode | stuck dim/sheet, stale detail, multiple taps required. |
| Root switch | Open Ask AI then Back to Map | full chat then readable map | root returns map/overview | no return control, black/blank map. |
| In-map composer | Focus, type, send, collapse/reopen | dock panel is visible, then resumable | transcript changes; map remains tappable after collapse | keyboard blackout, invisible hit interceptor, lost transcript. |
| Attachment | Open paperclip, cancel then stage/remove an item | one menu/preview lane; composer stays anchored | local payload adds/removes | duplicated menu, blocked keyboard, send does nothing. |
| Add tool | Add valid name/URL to a branch; return map | new tool becomes a selected map node | persisted tool/category mutation | duplicate, wrong category, selection desync. |
| Settings | Toggle haptics, inspect history, request Reset then cancel/confirm | settings remains usable; reset confirmation clear | correct persistence / reset only on confirm | accidental reset, key shown in normal release flow. |

### Severity-based manual checks

**Stop-ship / P0:** launch, onboarding escape, map node interaction, Map/Chat
return path, Add Tool submission, detail dismissal, no blank/black surface.

**P1:** keyboard auto-grow/safe-area, attachment cancellation, tool deletion
guard, state persistence after relaunch, iPhone/iPad sheet differences, no
header/dock overlap.

**P2:** native glass/morph polish, Dynamic Type/VoiceOver, haptic feel, edge
rail only if it is intentionally mounted, dormant 3D system only after a
separate reactivation.

### Current exclusions

- Do not test a right rail as a release feature: it is unmounted.
- Do not test active 3D camera/gesture behavior as part of the current map:
  the mounted renderer is 2D.
- Test an actual PhotosPicker/FileImporter on a real simulator/device; static
  UI-test flags cannot validate the system picker.
