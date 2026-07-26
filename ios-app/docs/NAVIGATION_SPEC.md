# NAVIGATION_SPEC

This is a current-source navigation contract for the mounted SwiftUI map. It
does not infer missing historical navigation specifications.

## Independent route domains

`RootShell.surface` owns the root Map / Ask AI switch. It remains separate from
`UniverseViewModel.universeMode`, which owns map selection and map-local
backdrop states. Root Ask AI must never be encoded as `.chatOpen`; that case is
only the in-map assistant context.

Compact detail is a model-owned `DetailRoute`. Its `returnMode` restores the
selected map tool after dismissal, while the optional route drives the compact
system sheet through one map-host binding. Related-tool replacement retains the
route's presentation identity so the reading content changes without a sheet
dismissal/re-presentation. It does not replace `RootShell` or persist a new
map-selection value.

On regular width, the detail reading surface is the trailing inspector derived
from explicit selected-tool state. The compact route is restored rather than
presented as a second sheet.

## Sheet coordination boundary

There is not yet a global typed owner for Account/Add/detail sheets. Detail to
Account/Add retains the current `DispatchQueue.main.asyncAfter` handoff (0.22s
and 0.18s respectively) to avoid overlapping SwiftUI sheets. Moving that
handoff is deferred to the state/service split plan; this task adds no
view-local replacement owner.

## Changed files / QA done / Remaining issues

**Changed files:** Task 3 records the compact-detail route boundary without
changing root Map / Ask AI routing.

**QA done:** The focused automated evidence source is
`/tmp/aimap-foundation-route.xcresult`, covering `UniverseViewModelTests`,
`UniverseModeTests`, and the compact UI smoke. The MCP call timed out at 300
seconds, but the finalized bundle subsequently reported 69 passed and 1 failed
test: the compact UI smoke stopped at its branch-card assertion. The Task 3
report records the exact failure. No visual pilot or physical-device evidence
is claimed.

**Remaining issues:** App-wide presentation ownership remains unresolved until
the planned state/service split. The existing Account/Add delayed handoff is
intentionally preserved.
