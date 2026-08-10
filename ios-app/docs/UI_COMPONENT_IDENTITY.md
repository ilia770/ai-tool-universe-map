# UI_COMPONENT_IDENTITY — Canonical iOS component catalog

**Status:** current-baseline inventory, 2026-07-17.  
**Rule:** a data ID, accessibility ID, and transition ID may have different
representations, but each must derive from the same semantic object. This
catalog records the canonical identity before any UI is created or replaced.

## Identity vocabulary

| Level | Contract |
| --- | --- |
| Domain identity | `Tool.id`, `ToolCategoryId.rawValue`, a route case, or a documented control role. |
| Render identity | Stable `ForEach`/view identity derived from the domain ID. |
| Accessibility identity | Human-testable identifier derived from the semantic role and domain ID. |
| Transition identity | Namespace-scoped ID that identifies the same conceptual object on both sides of a transition. |
| Event identity | A `UUID()` is permitted for transient messages/activity/toast events; it must never become a persistent component or shared-transition source ID. |

## Current reusable and important components

| Canonical component | Source / data identity | Current states and environments | Accessibility / transition / material | Owner and duplication policy |
| --- | --- | --- | --- | --- |
| `AppRoot` | `MyAIMapApp.swift`; semantic ID `app.root` | cold start, seeded visual QA | no shared transition | App owns one `UniverseViewModel`; never duplicate. |
| `RootSurface` | `RootShell.surface`: `map` / `chat` | root Map/Ask AI, onboarding overlay | controls identify their semantic route; custom dive is not a shared-object transition | `RootShell`; one active root surface. |
| `RootSurfaceSwitch` | role `rootSurface.map` / `rootSurface.chat` | selected/unselected, compact/regular | functional control layer; current glass/morph candidate | `RootShell`; use variants, not a second switch. |
| `UniverseMap` | `UniverseMapView`; semantic ID `universe.map` | compact sheet host / regular inspector host | background/content layer, not a glass control | Map composition; one live renderer at a time. |
| `ConstellationCategoryNode` | `ToolCategoryId.rawValue`; render `category.<id>` | overview, context, focused, selected | AX `ConstellationCategory.<id>`; no current hero transition | `UniverseViewModel.universeMode`; no index-derived copy. |
| `ConstellationToolNode` | `Tool.id`; render `tool.<id>` | branch, selected, dimmed/detail backdrop | AX `ConstellationStar.<toolID>`; **future pilot source** `ToolDetailTransitionID.tool(<tool.id>)` | `UniverseViewModel.universeMode`; retain source reservation during pilot. |
| `ConstellationCoreNode` | special `ToolCategoryId.core` | overview / chat-context display | non-interactive visual anchor | Map renderer; not an ordinary tool replacement. |
| `UniverseOverlay` | semantic ID `universe.overlay` | top chrome, labels, map controls, dock | mixed functional chrome; glass only for controls | Map composition; do not fork overlay for a presentation. |
| `PlanetInfoCard` | selected category/tool identity: `map.info.<category>.<tool?>` | category/tool/empty variants; Dynamic Type capped today | AX IDs are role-specific; content surface, not default glass | derived from model mode; variants allowed, duplicated card tree not. |
| `SearchDock` | semantic session plus host: `assistant.dock.map` / `assistant.dock.chat` | collapsed, focused, attachments, transcript, keyboard | functional control layer; no shared transition contract yet | Local focus/gesture state + model transcript; host duplication is an audit issue. |
| `ChatScreen` | `root.chat`; tool cards use `Tool.id` | empty/transcript/loading-ish/local-reply | AX `ChatScreen.ToolCard.<toolID>` and semantic chips | `RootShell.surface` + model; a root surface, not map-detail source. |
| `ToolChip` / `BranchChip` / `ActionChip` | tool/category/action role | normal, pressed, selected, disabled | IDs must derive from caller role plus domain ID, not screen label alone | Reusable primitive; extend variants rather than make copies. |
| `ToolDetailSheet` | current `RootSheet.ToolDetail`; destination should be `detail.tool.<tool.id>` | compact sheet; regular inline inspector | current sheet has no source continuity; content material is appropriate | Current ownership split is prohibited for the pilot target. |
| `ToolDetailSection` | selected `Tool.id`; header currently `.id(selectedTool.id)` | detail content, expanded groups, browser sheet | AX `ToolDetailSection.Title`; destination must expose pilot transition identity | Model selection + local expansion; replace content, not whole route. |
| `AccountControl` / `AccountSettingsSheet` | `ChromeMorphID.account` | enabled/sheet presented | `matchedTransitionSource` + zoom on current paths; functional glass | Two hosts today (`RootShell`/map); do not add a third. |
| `AddToolControl` / `AddToolSheet` | `ChromeMorphID.addTool` / suggestion slug | empty/draft/validation/presented | current zoom source/destination pair; functional glass trigger | Two hosts today; draft is presentation-local. |
| `GlassMorphCluster` | must be `cluster.<role>.<option semantic ID>` | selected/unselected, compact/expanded | current default `base.<index>` is positional and must not be used for new public IDs | Local selected option binding; semantic-ID API required before transition use. |
| `LiquidGlassButton`, `LiquidGlassInput`, `LiquidGlassPill` | `control.<role>.<scope>` | normal/pressed/disabled/focused | eligible functional glass; fallback through `glassSurface` | Reusable primitives; never duplicate solely for another screen. |
| `OnboardingOverlay` | `onboarding.firstRun` | presented, skip, complete | AX names are role based; system presentation/transient layer | persisted onboarding flag; one overlay. |
| `CopyToast` | transient event token, not persistent UI identity | shown/hidden/kind | announcement + transient visual feedback | local host state; separate hosts allowed because events are ephemeral. |
| `InAppBrowserSheet` | URL identity | presented/dismissed | system sheet; no hero assumption | detail-local route. |
| `UniverseRailView` / `CategoryRail` | category IDs if reactivated | currently unmounted | not current navigation or accessibility evidence | dormant; do not duplicate/revive without separate spec. |
| RealityKit renderer/controller family | entity/category/tool model IDs | retained legacy path, not live renderer | not current UI-transition participant | dormant; explicit renderer decision required. |

## Identity obligations for new work

1. State the component's canonical name, domain identity, render identity,
   accessibility identifier, owner, supported states, layout contract, material
   role, and transition participation before adding it.
2. A component changing role may preserve identity only when product semantics
   genuinely continue (for example, a selected segment or a morphing account
   trigger). Unrelated controls receive normal insertion/removal.
3. A source/destination pair cannot claim continuity until both register the
   same documented transition identity in a single owned namespace.
4. `ConstellationStar.<toolID>` is stable test evidence today, but it alone is
   not a matched transition identity. The planned tool-detail pilot must add
   the explicit `ToolDetailTransitionID` contract.

