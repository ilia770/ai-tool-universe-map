# INTERACTION_SPEC

This document records current detail behavior from the Swift sources. It does
not reconstruct missing historical interaction material.

## Compact detail

- A visible selected map tool requests detail through
  `UniverseViewModel.requestDetail(for:)`. The model validates the id against
  `visibleAllTools`, records a `DetailRoute`, and changes `universeMode` to
  `.detail`.
- `UniverseMapView` is the compact host only: its single
  `Binding<DetailRoute?>` presents the system sheet. It does not calculate a
  fallback return mode from projected selection.
- The visible close control calls `UniverseViewModel.dismissDetail()`. The
  sheet binding's nil write and its `onDismiss` callback call the same
  idempotent model intent for a system swipe-down dismissal.
- A cancelled partial system drag sends no dismissal intent, leaving the route
  and `.detail` map state intact.
- Choosing a related visible tool requests
  `UniverseViewModel.replaceDetailTool(with:)`. The optional route's tool and
  return mode are replaced in place while its sheet-presentation identity is
  retained; there is no second compact-detail Boolean or new system sheet.

## Regular width

The iPad trailing inspector remains derived from explicit selected-tool state.
It is not a compact system sheet. If an existing route reaches a regular-width
map host, the host restores the route so the inspector can present the selected
tool without a dimmed compact-detail backdrop.

## Changed files / QA done / Remaining issues

**Changed files:** Task 3 introduces `DetailRoute` and model detail intents,
then binds the compact host to the optional route.

**QA done:** The Task 3 report records finalized automated evidence. The
clean-checkout gate covers the route unit suites and
`UniverseUISmokeTests/testCaptureKeyStates` against committed source; this
document intentionally does not depend on a transient `/tmp` result bundle.

**Remaining issues:** Account/Add sheet handoff remains on its existing
`DispatchQueue.main.asyncAfter` timings. A future state/service split needs a
global typed app-sheet owner before changing that behavior.
