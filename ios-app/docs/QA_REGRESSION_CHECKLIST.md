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

## Navigation glass run - 2026-06-22

**Automated**
- [x] `git diff --check` clean.
- [x] `xcodebuild -project ios-app/MyAIMap.xcodeproj -scheme MyAIMap
      -destination 'platform=iOS Simulator,id=EAC2C682-5C38-44DB-8FEC-034E296E8EEA'
      -only-testing:MyAIMapTests test` passed: 242 tests / 29 suites.
- [x] `xcodebuild ... -only-testing:MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates
      test` passed: map-first launch, Ask AI route, Map route, graph taps,
      detail, account, input focus, attachment menu.

**Still needs visual QA**
- [ ] Real-device check that Map <-> Ask AI top pill morphs without flicker.
- [ ] Real-device check that Collapse Chat <-> Show Chat feels continuous.
- [ ] Add Tool / Account toolbar glass controls do not collide with Dynamic
      Island/status bar on physical devices.
