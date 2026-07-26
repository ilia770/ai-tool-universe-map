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
  `UniverseViewModel.replaceDetailTool(with:)`. The optional route is replaced
  in place; there is no second compact-detail Boolean.

## Regular width

The iPad trailing inspector remains derived from explicit selected-tool state.
It is not a compact system sheet. If an existing route reaches a regular-width
map host, the host restores the route so the inspector can present the selected
tool without a dimmed compact-detail backdrop.

## Changed files / QA done / Remaining issues

**Changed files:** Task 3 introduces `DetailRoute` and model detail intents,
then binds the compact host to the optional route.

**QA done:** The automated evidence source is the focused xcresult at
`/tmp/aimap-foundation-route.xcresult` for the route unit tests and
`UniverseUISmokeTests/testCaptureKeyStates`. The MCP call timed out at 300
seconds, but the finalized bundle subsequently reported 69 passed and 1 failed
test: the compact UI smoke stopped at its branch-card assertion. The Task 3
report records the exact failure. This document does not claim a visual pilot
or physical-device run.

**Remaining issues:** Account/Add sheet handoff remains on its existing
`DispatchQueue.main.asyncAfter` timings. A future state/service split needs a
global typed app-sheet owner before changing that behavior.
