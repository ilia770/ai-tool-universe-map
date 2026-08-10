# UI_TRANSITION_CATALOG — Current transitions and required contracts

**Status:** baseline catalog, 2026-07-17.  
**Acceptance rule:** every important transition must answer: what is the same
object, what is new, what moves/resizes/materializes, who owns progress, what
happens on interruption, and where accessibility focus goes.

| ID / class | Trigger and route | Same object / stable identity | Current owner and mechanism | Baseline status / required evidence |
| --- | --- | --- | --- | --- |
| T-01 Presentation | first launch → onboarding | none; `onboarding.firstRun` is an overlay | persisted model flag; overlay | Current; verify escape, completion, focus. |
| T-02 Navigation | Map ↔ Ask AI | route context only; no shared object claimed | `RootShell.surface`, asymmetric dive transition | Current; test restoration and Reduce Motion. |
| T-03 Reordering/focus | overview → category branch | category `ToolCategoryId.rawValue` | `UniverseViewModel.universeMode` + constellation layout/motion | Current; no hero claim. |
| T-04 Component state | branch → selected tool | tool `Tool.id`, AX `ConstellationStar.<id>` | `UniverseViewModel.universeMode` + layout | Current; tool identity stable, no destination continuity. |
| T-05 Presentation/shared element/interactive dismissal | selected map tool → compact detail | should be `ToolDetailTransitionID.tool(<Tool.id>)` | **currently split** across mode/local sheet flags; system sheet | **Pilot target.** Current implementation lacks source reservation, reverse progress, and shared identity. |
| T-06 Content replacement | detail → related tool | destination tool `Tool.id` | detail callback/model mode | Current behavior; exclude from pilot until route semantics are formalized. |
| T-07 Presentation | Map account trigger → account | `ChromeMorphID.account` | map local flag + matched source/zoom sheet | Partial current pair; record reverse system dismissal evidence. |
| T-08 Presentation | Map add trigger → add tool | `ChromeMorphID.addTool` | map local flag + matched source/zoom sheet | Partial current pair; draft cleanup required on dismiss. |
| T-09 Presentation | Chat account/add trigger → sheets | same ChromeMorph IDs in a distinct namespace/host | root local flags + zoom sheet | Partial current pair; duplicate host is an audit issue. |
| T-10 Search activation | in-map dock collapsed ↔ composer/transcript | semantic assistant session, no formal transition ID | local dock state plus map callback/mode | Current local/global feedback loop; verify keyboard, cancel, focus. |
| T-11 Shared-looking flight | Chat matched tool → Map target | intended `Tool.id`, currently temporary request UUID/frame snapshot | `RootShell` ghost overlay + timer | Decorative one-way effect only; not continuity acceptance evidence. |
| T-12 Component feedback | glass cluster option changes | currently selected index; must become semantic option ID | local binding + glass/matched geometry fallback | Existing behavior; no new positional IDs. |
| T-13 Transient feedback | copy/add/validation result → toast | transient event token | local view state | Current; no navigation or hero semantics. |
| T-14 Unmounted | rail gesture / category rail | category ID | source exists but is not mounted | Excluded from current product/QA paths. |

## Required transition fields for future entries

Every new or materially changed row must additionally name:

- namespace and API (system navigation, matched geometry, glass, custom host,
  or ordinary replacement);
- animation/motion role and Reduce Motion fallback;
- gesture owner, interruption and cancellation behavior;
- source/destination lifetime and clipping/z-order policy;
- accessibility focus/announcement behavior; and
- deterministic recording, key frames, and reference-comparison evidence.

## Controlled pilot: T-05 — constellation tool node → compact tool detail

**Why this transition:** it is a core user journey with an existing stable
domain source (`Tool.id` and `ConstellationStar.<toolID>`), a destination that
shows the same tool, and a current architectural defect small enough to prove
the model before broad migration. Account/Add already exercise a partial zoom
pattern; Chat-to-map is a timer-driven cross-root effect and is not an
appropriate first proof.

| Contract | Pilot requirement |
| --- | --- |
| Scope | Map-origin tool detail on compact width only. Exclude Chat origin, related-tool drill-down, and regular-width inspector. |
| Stable source | `ToolDetailTransitionID.tool(tool.id)` derived solely from `Tool.id`; existing AX ID remains test evidence. |
| Continuity | A persistent map transition host owns one namespace. The source node remains reserved/represented through opening, presentation, cancel, and completion. The destination header/logo receives the same semantic ID. |
| One state owner | A typed detail-route/transition state owned by `UniverseViewModel` (or a documented single derived route projection from it). The pilot path removes local mirrored `detailPresented`/`modeBeforeDetail` ownership. |
| API decision | Prefer a system navigation zoom only if simulator proof shows source reservation and acceptable interactive return. Otherwise use a custom shared-hero overlay with explicit progress; do not use a normal sheet merely because it compiles. |
| Reverse interaction | Drag continuously drives owner progress. Distance and velocity select finish/cancel. Custom close, VoiceOver escape, and gesture converge on the same state transition. Finish restores `.toolSelected(category, toolID)`; cancel leaves the detail presented. |
| Motion/accessibility | Use semantic hero/settle tokens; Reduce Motion retains route meaning with reduced spatial travel. Focus enters the detail title on open and returns to `ConstellationStar.<toolID>` after complete dismissal. |
| Acceptance recording | Seed `-uitestSampleUniverse -uitestFocusTool figma`; record opening, 25/50/75% drag, cancel, finish, rapid reopen, after-scroll case, and Reduce Motion. Capture key frames and assert the return source is `ConstellationStar.figma`. |
| Visual comparison | Compare on the named supplied visual reference, same device/OS/appearance. This gate is blocked until the reference asset is provided; existing screenshots cannot substitute. |

## T-05 pilot change manifest — exact scope after approval

This manifest is the sole file-scope authority for the future pilot. It is a
plan, not approval to edit production UI. The common files below change in
either implementation branch:

| Path | Planned responsibility |
| --- | --- |
| `Sources/MyAIMap/State/UniverseViewModel.swift` | Own the typed detail route/transition state and all finish/cancel/close intents. |
| `Sources/MyAIMap/Universe/UniverseMode.swift` | Represent the route transition without parallel presentation booleans. |
| `Sources/MyAIMap/Universe/UniverseMapView.swift` | Remove the pilot path's mirrored `detailPresented` / `modeBeforeDetail` ownership and mount the single transition context. |
| `Sources/MyAIMap/Universe/UniverseConstellationView.swift` | Attach `ToolDetailTransitionID.tool(tool.id)` to the semantic source node and reserve it while the transition is active. |
| `Sources/MyAIMap/Universe/UniverseConstellationLayout.swift` | Preserve the selected source's frame/representation during `.detail`; it must not disappear solely because layout changes. |
| `Sources/MyAIMap/UI/Sheets/RootSheet.swift` | Route the compact map-origin destination through the authoritative detail state. |
| `Sources/MyAIMap/UI/Sheets/ToolDetailSection.swift` | Mark the destination hero/header with the same semantic identity and route all close affordances through the owner. |
| `Tests/MyAIMapTests/UniverseViewModelTests.swift` | Assert the typed state machine, restoration, and a single close path. |
| `Tests/MyAIMapTests/UniverseModeTests.swift` | Assert route/selection invariants for open, cancel, and finish. |
| `Tests/MyAIMapTests/UniverseConstellationLayoutTests.swift` | Assert source reservation and stable selected-tool geometry. |
| `Tests/MyAIMapUITests/ToolDetailTransitionUITests.swift` *(new)* | Drive `ConstellationStar.figma` through open, 25/50/75% drag, cancel, finish, rapid reopen, after-scroll, focus restoration, and Reduce Motion; own the pilot video/key-frame attachments. |

The implementation choice is deliberately gated by a runtime API spike:

| Branch | Additional exact path | Selection rule |
| --- | --- | --- |
| System navigation zoom | None | Use only when an iOS 18+ simulator proves source reservation and acceptable interactive return. |
| Custom shared-hero host | `Sources/MyAIMap/Universe/ToolDetailTransitionHost.swift` *(new)* | Use when zoom cannot provide the specified progress-driven reverse dismissal or exact source restoration. |

The branch is mutually exclusive; do not add the custom host merely as a
fallback tree. Neither branch changes `Sources/MyAIMap/RootShell.swift`,
`Sources/MyAIMap/UI/Search/SearchDock.swift`, Account/Add sheets, the
regular-width inspector, or `project.yml` (its existing globs already include
the named test paths). Chat-origin detail and related-tool drill-down remain
out of scope.
