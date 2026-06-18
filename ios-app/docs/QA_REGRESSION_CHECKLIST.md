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

## Device matrix (visual)
- [ ] iPhone 17 (and a Pro Max) — no overlap/clipping.
- [ ] iPhone SE-class (small) — no overflow; controls reachable.
- [ ] iPad — layout adapts (TARGETED_DEVICE_FAMILY=1,2).
- [ ] Dynamic Type larger sizes — text scales, no truncation of key copy.
- [ ] Dark mode (app is dark-first).
