# STATE_OWNERSHIP — Canonical and local state matrix

Scope: current working tree. “Canonical owner” identifies storage, not every
writer. A derived value is not a second source of truth. Runtime verification
is required where static code cannot establish presentation timing.

**UI architecture links:** state changes follow `UI_APPLE_NATIVE_SPEC.md`;
semantic IDs belong in `UI_COMPONENT_IDENTITY.md`; transition owners and
lifecycles are cataloged in `UI_TRANSITION_CATALOG.md` and
`UI_COMPONENT_LIFECYCLE.md`; runtime proof uses `UI_QA_CHECKLIST.md`.

| State | Canonical owner | Readers | Writers | Persistence | Lifecycle / risk |
| --- | --- | --- | --- | --- | --- |
| Environment model | `MyAIMapApp.@State model` | all environment consumers | app bootstrap | No | Per SwiftUI scene; high global impact. |
| Root primary surface | `RootShell.surface` | root switch, `RootSurfaceSwitch` | root actions/onboarding | No | `.universe` or `.chat`; separate from map mode. |
| Map navigation | `UniverseViewModel.universeMode` | map, overlay, detail, model projection | model intents, map view, UI-test boot | No | **Critical.** Cases: overview, branch, tool, detail, chat. |
| Semantic selection | Derived `UniverseViewModel.selection` | rail/chips/detail/add forms | Derived from map mode | No | Not storage. Fallback first-tool behavior can differ from explicit `mode.selectedToolID`. |
| Selected explicit tool | `UniverseMode.toolSelected/detail/chatOpen` associated value | map/detail/camera hooks | model/map view | No | Empty on overview/branch; do not mirror in a `@State`. |
| Pending cross-surface detail | `UniverseViewModel.pendingDetailToolID` | `UniverseMapView` | `requestToolDetail`, map consumer | No | One-shot memory handoff; must be cleared after consumption. |
| Compact detail presentation | `UniverseMapView.detailPresented` plus `modeBeforeDetail` | sheet host | map view/sheet dismissal | No | **Duplicate presentation boundary:** synchronized with `.detail`; high desync risk. |
| Regular-width detail inspector | Derived in `UniverseMapView.inspectorPanel` | iPad map composition | selection/mode changes | No | Does not need `.detail`; chat coexistence requires runtime verification. |
| Root Account/Add sheets | `RootShell.accountPresented`, `addToolPresented`, draft | root sheets | root/chat/onboarding actions | No | Route-specific presentation owner. |
| Map Account/Add sheets | `UniverseMapView` local flags/draft | map sheets | map/overlay actions | No | Independent of root sheet flags; no shared sheet router. |
| Current map planets | `UniverseMapView.planets` cache | constellation/overlay/camera | `rebuildPlanets()` | No | Derived from visible tools/categories; stale-cache risk when inputs grow. |
| 2D ambient breathing | `UniverseConstellationView.breath` | 2D view | view appear/animation | No | Local visual-only, disabled for Reduce Motion/static tests. |
| Legacy camera/scene/gesture objects | `UniverseMapView` local `@State` controllers | legacy-only code | map focus hooks/gestures | No | **Dormant currently** because RealityView is unmounted. |
| In-map rail active/hover | `UniverseOverlayView.isRailActive` / `UniverseRailView.gestureState` | unused rail hooks | rail gesture | No | **Inactive:** rail is not mounted. |
| Assistant transcript | `UniverseViewModel.assistantMessages` | dock, full chat | assistant/starter prompt code | No | Shared across two chat surfaces; lost on relaunch. |
| Assistant composer text | `UniverseViewModel.assistantQuery` | dock/full chat's shared composer | text binding, model send | No | Shared across surfaces; no persisted draft. |
| Conventional search query/results | `UniverseViewModel.searchQuery` / derived `searchResults` | tests/model | no current visible input found | No | **Unused UI path:** do not presume search is shipped. |
| In-map input focus | `SearchDock.fieldFocused` | dock and chat activity callback | local text field/UI | No | Local keyboard state; must not become global selection state. |
| Attachment menu/payload/pickers | `SearchDock` local state | dock | local controls/system pickers | No | Photo bytes may be read locally for size and file metadata is read for preview; attachment bytes are not sent to the assistant. |
| Collapsed in-map transcript | `SearchDock.conversationCollapsed` | dock | local controls/mode changes | No | Destroyed when dock unmounts. |
| Full-chat scroll/jump/copy UI | `ChatScreen` local state | full chat | scroll/copy callbacks | No | Separate from in-map dock. |
| User tools / categories / hidden IDs | `UniverseViewModel` private sets | map, forms, assistant | model add/delete/restore/reset | Yes | UserDefaults v1; **critical product data**. |
| Onboarding completion | `UniverseViewModel.hasSeenOnboarding` | `RootShell` | model onboarding intents | Yes | Explicitly separate from empty catalog. |
| Haptics setting | `UniverseViewModel.hapticsEnabled` | app/root/map/haptics | settings binding | Yes | Feeds global `BrandHaptics.isEnabled`. |
| Placeholder subscription | `UniverseViewModel.subscription` | settings | assistant send/model | Yes | No billing/period reset. |
| Activity history | `UniverseViewModel.activityHistory` | settings/assistant | model intents | No | Volatile; settings history resets on relaunch. |
| App language choice | `UniverseViewModel.appLanguage` | disabled settings picker | binding if enabled | No | No localization behavior; do not treat as language support. |
| Visualization style | `UniverseViewModel.visualizationStyle` | retained spatial renderer | no live visible owner | No | Legacy/dormant tuning, not current map setting. |
| DeepSeek key | Keychain service/account | debug settings/client | KeychainStore | Keychain | Never duplicate in model/UserDefaults. |
| Developer mode | `UserDefaults.standard` key | backend resolver | debugger/tests | Yes, DEBUG only | Not consumer-facing in release. |
| Relation cache | `RelationCache` UserDefaults key | no live renderer reader | unused cache API | Yes | Experimental/unwired. |
| Root flight anchors/ghosts | `RootShell` local states/preferences | root overlays | root callbacks/geometry | No | Decorative transition state, not catalog state. |
| Glass/morph namespaces | view-local `@Namespace` | paired source/destination controls | SwiftUI | No | Identity must remain scoped to its owner view. |

## Explicit ownership rules

1. `UniverseViewModel.universeMode` is the only stored map selection/navigation
   source. Use its intents or a narrowly justified write; never add parallel
   selected-category/tool state.
2. `UniverseViewModel.selection` is a projection. A non-`nil`
   `selection.selectedToolID` does not mean a tool is explicitly selected;
   inspect `universeMode.selectedToolID` when that distinction matters.
3. Root Map/Ask AI routing belongs to `RootShell.surface`. Do not collapse it
   into `UniverseMode.chatOpen` without a cross-surface migration plan.
4. `UniverseStore` is the persistence authority for user catalog data. New
   persisted fields need a version/migration decision, tests, and this matrix.
5. Input focus, attachment staging, scroll position, and press animation stay
   local unless product behavior explicitly needs restoration/shareability.

## Duplicate, mirrored, or unclear boundaries

| Finding | Evidence | Risk / safe remediation boundary |
| --- | --- | --- |
| Detail exists as mode plus Boolean sheet | `UniverseMapView` synchronizes `detailPresented` with `.detail`. | High. Change detail routing only as a map/navigation task with compact/iPad QA. |
| Account/Add sheet flags occur in two route hosts | `RootShell` and `UniverseMapView` each own local flags. | Medium. Intentional route-local presentation today, but a cross-route flow needs a router decision. |
| Root Chat vs in-map chat are separate contexts | `RootShell.surface == .chat` versus `UniverseMode.chatOpen`. | High. They share transcript but do not restore the same navigation context. |
| Derived fallback selection can look explicit | `selection` chooses first category/core tool when mode has none. | Medium. Detail/analytics code must distinguish projection from explicit focus. |
| Legacy camera state is still allocated | map creates controllers while current renderer is 2D. | High transition debt; do not delete/re-enable without renderer decision. |
| Rail state is implemented but unreachable | overlay defines rail property without mounting it. | Medium; document as inactive rather than adding another rail owner. |
| Search state has no visible current input | `searchQuery` and `focusFirstSearchMatch` lack a live caller. | Medium; do not wire a new search UI accidentally while fixing assistant composer. |

## State mutation trace examples

```text
Add Tool submit
  AddToolSheet local draft
    → UniverseViewModel.createBranch? / addCustomTool
    → UniverseStore.save + UniverseSeed custom-category registration
    → UniverseViewModel.universeMode = toolSelected
    → UniverseMapView observes visible IDs and rebuilds planets

In-map assistant send
  SearchDock TextField → model.assistantQuery
    → UniverseViewModel.askAssistant
    → local reply (or DEBUG DeepSeek fallback)
    → assistantMessages + volatile activityHistory
    → SearchDock/ChatScreen redraw
```

See `TECHNICAL_DEBT.md` for remediation risks. This document intentionally
does not prescribe a refactor.
