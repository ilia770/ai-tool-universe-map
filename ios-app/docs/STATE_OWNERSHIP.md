# State ownership

| State | Owner | Boundary |
| --- | --- | --- |
| Root Map / Ask AI route | `RootShell.surface` | Root routing only; it is separate from map navigation. |
| Map selection and navigation | `UniverseViewModel.universeMode` | The sole stored map-navigation value; selection is projected from it. |
| Compact detail route | `UniverseViewModel.detailRoute` | Optional typed route carrying `toolID`, the exact `UniverseMode` to restore, and a stable sheet-presentation identity. The compact map host owns the single binding only. |
| Account and add-tool presentations | `UniverseMapView` | Local system-sheet flags remain until the state/service split establishes one app-sheet owner. |

`UniverseMapView` reads and writes the model-owned `universeMode`; it does not
store a second map-selection value. `requestDetail(for:)`, `dismissDetail()`,
and `replaceDetailTool(with:)` are the only compact-detail intents. The release
renderer consumes `universeMode` to lay out the 2D constellation, while the
compact sheet observes `detailRoute` through one `Binding<DetailRoute?>`.
Related-tool replacement retains the route's presentation identity, so it
updates sheet content without dismissing or presenting a second system sheet.

`DetailRoute.returnMode` is not persisted. It captures only the live map state
needed to restore the selected tool after a compact detail dismissal. Root Ask
AI remains a `RootShell.surface` concern and must not be represented as
`UniverseMode.chatOpen`.

## Changed files / QA done / Remaining issues

**Changed files:** Task 3 adds `State/DetailRoute.swift`, moves compact-detail
route ownership into `UniverseViewModel`, and changes the compact map sheet to
observe that typed route rather than local timing mirrors.

**QA done:** The Task 3 report is the canonical record of finalized automated
evidence. Clean-checkout validation covers `UniverseViewModelTests`,
`UniverseModeTests`, and the compact UI smoke against committed source; this
document intentionally does not depend on a transient `/tmp` result bundle.

**Remaining issues:** Account/Add still use their existing local flags and
delayed handoff after detail dismissal. Do not replace that timing in this task:
the next state/service split needs a single app-sheet presentation owner.
