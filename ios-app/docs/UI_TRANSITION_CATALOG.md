# UI_TRANSITION_CATALOG

This catalog states the transitions that current source implements. It does not
reconstruct absent visual-reference documentation.

| ID | Transition | Current implementation | Status |
| --- | --- | --- | --- |
| T-03 | Compact map tool → detail | `DetailRoute` drives one native `.sheet(item:)` binding at `UniverseMapView`; dismissal restores the captured `UniverseMode`. | Implemented in Task 3. |
| T-04 | Detail → related tool | `replaceDetailTool(with:)` replaces tool content and return mode while retaining the route's sheet-presentation identity; no second flag or new system sheet. | Implemented in Task 3. |
| T-05 | Shared-element map/detail hero | No `matchedTransitionSource`, shared-element host, custom drag progress, or hero transition is introduced. | **Blocked** until the required visual reference is supplied and reviewed. |

T-03 retains the current system-sheet presentation: fraction-0.72 and large
detents, background interaction through the fraction detent, visible drag
indicator, corner radius 42, and existing sheet appearance. This task is a
route-ownership improvement only, not a visual-transition pilot.

## Changed files / QA done / Remaining issues

**Changed files:** Task 3 adds this source-grounded catalog and routes compact
detail through the model-owned `DetailRoute`.

**QA done:** The focused automated evidence source is
`/tmp/aimap-foundation-route.xcresult` for the route unit tests and compact UI
smoke. The MCP call timed out at 300 seconds, but the finalized bundle
subsequently reported 69 passed and 1 failed test: the compact UI smoke stopped
at its branch-card assertion. The Task 3 report records the exact failure. No
visual pilot or physical-device evidence is claimed.

**Remaining issues:** T-05 remains explicitly blocked pending a supplied and
reviewed visual reference. Account/Add timing remains deferred to the
state/service split's single presentation owner.
