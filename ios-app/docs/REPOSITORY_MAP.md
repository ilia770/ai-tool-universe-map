# REPOSITORY_MAP — Safe development map

This map focuses on files a future agent needs before changing behavior. Risk
means coordination risk, not code quality judgment. “Independent” means an
agent may edit the area only when the listed shared owners are outside scope.

**Path convention:** paths beginning with `Sources/MyAIMap/`, `Tests/`,
`Resources/`, `docs/`, or a repository-root file are literal. Every other
Swift path in this table is shorthand relative to `Sources/MyAIMap/`.

| Path | Responsibility | Main types | Dependencies | Risk | Notes |
| --- | --- | --- | --- | --- | --- |
| `project.yml` | Canonical XcodeGen app/test configuration | targets, scheme | XcodeGen, all source trees | Critical | Generated `.xcodeproj` is not the edit target. |
| `Sources/MyAIMap/MyAIMapApp.swift` | App boot, model lifetime, UI-test flags | `MyAIMapApp` | `UniverseViewModel`, `RootShell` | Critical | One model per scene; do not duplicate environment model. |
| `Sources/MyAIMap/RootShell.swift` | Root Map/Ask AI route, onboarding, root sheets, flight transitions | `RootShell`, `RootSurface` | model, map, chat, sheets | Critical | Root surface is distinct from map `UniverseMode`. |
| `State/UniverseViewModel.swift` | Catalog, map mode, assistant, mutations, persistence trigger | `UniverseViewModel` | store, seed, search, assistant | Critical | Large coupled owner; inspect all intents before changing state. |
| `State/UniverseStore.swift` | UserDefaults serialization contract | `UniverseStore` | `Tool`, categories, subscription | Critical | v1 keys have no migration layer. |
| `State/UniverseSelection.swift` | Mode-adjacent value types and placeholder state types | `UniverseSelection`, `AssistantMessage` | view model, views | High | `UniverseSelection` is a computed projection, not storage. |
| `Universe/UniverseMode.swift` | Map navigation state machine and visual derivatives | `UniverseMode` | model, map, overlay | Critical | Changes fan out into map, detail, chat and tests. |
| `Universe/UniverseMapView.swift` | Current map composition, map sheets, compact/regular detail behavior | `UniverseMapView` | model, constellation, overlay | Critical | Owns local sheet flags and legacy controller instances. |
| `Universe/UniverseConstellationView.swift` | Current mounted 2D map renderer | `UniverseConstellationView` | layout, mode, planets | Critical | **Current worktree file is untracked.** Avoid concurrent edits. |
| `Universe/UniverseConstellationLayout.swift` | Pure deterministic 2D placement | `UniverseConstellationLayout` | `PlanetData`, mode | High | **Current worktree file is untracked.** Tests guard layout. |
| `Universe/UniverseOverlayView.swift` | Map chrome, empty state, map dock hosting, inactive rail hooks | `UniverseOverlayView` | model, SearchDock, map callbacks | High | Legacy projected labels and rail support are defined but disabled/unmounted. |
| `Universe/RightUniverseRail.swift` | Hold/drag rail implementation | `UniverseRailView` | category data, haptics | High | Present but not mounted by current overlay. |
| `UI/Sheets/CategoryRail.swift` | Alternative accessible category control | `CategoryRail` | model | Medium | Also has no current production caller. |
| `Universe/UniverseRealityView.swift` | Legacy RealityKit view and gestures | `UniverseRealityView` | scene/camera/gesture controllers | Critical | No current map call site; separate reactivation task only. |
| `Universe/UniverseSceneController.swift`, `CameraRigController.swift`, `UniverseGestureController.swift`, `Entities/`, `PlanetEntityFactory.swift`, `SatelliteBranch.swift` | Retained spatial scene/camera/entity system | RealityKit controllers/entities | `PlanetData`, mode, visual style | Critical | Dormant under current 2D composition; do not “clean up” opportunistically. |
| `Universe/PlanetData.swift`, `UniverseSpatialLayout.swift` | Model-to-map/spatial layout projection | `PlanetData`, `LabelPacker` | tools/categories | High | Shared by current derived planet list and legacy spatial code. |
| `UI/Search/SearchDock.swift` | In-map assistant composer, local attachment/collapse/focus state | `SearchDock`, attachment payload | model, PhotosUI, file importer | Critical | Local state drives in-map `chatOpen`; no conventional visible search field. |
| `UI/Search/ChatScreen.swift` | Full root chat surface and transcript | `ChatScreen` | model, RootShell callbacks | High | Shares transcript with dock but has separate scroll/chrome state. |
| `UI/Search/SearchCore.swift`, `UniverseAssistantCore.swift` | Deterministic search/assistant rules | `SearchCore`, `ComposerLogic`, `UniverseAssistantCore` | visible tools, knowledge | High | Pure logic; broad behavior impact but easy to unit-test. |
| `UI/Settings/AddToolSheet.swift` | Tool/branch creation form | `AddToolSheet`, `AddToolLogic` | model, modal host | High | Form state is local; committed mutations belong to model. |
| `UI/Settings/AccountSettingsSheet.swift` | Settings, reset, developer-only key UI | `AccountSettingsSheet` | model, Keychain | High | Holds independent modal section/confirmation state. |
| `UI/Sheets/RootSheet.swift`, `ToolDetailSection.swift` | Detail host and tool actions | `RootSheet`, `ToolDetailSection` | model, browser sheet | High | Delete/focus flows feed map navigation. |
| `Data/` and `Resources/ai-tool-universe.seed.json` | Bundled model schema, seed catalog, enrichment, assets | `Tool`, `ToolCategory`, `UniverseSeed` | model, map, assistant | Critical | Seed is not initial persisted user state. |
| `Services/KeychainStore.swift`, `DeepSeekClient.swift` | Secret storage and debug-only optional network path | keychain/client | Security, URLSession | High | Never expose/store the key in UserDefaults. |
| `Universe/Constellation/` | Connection/relation utilities | resolver/cache/AI parser | tools, UserDefaults, DeepSeek | Medium | Relation cache/AI are not wired to the live renderer. |
| `UI/Theme/`, `UI/Effects/`, `UI/Components/Glass/` | Shared visual tokens, glass, motion, haptic styles | `Brand*`, `glassSurface`, `GlassMorphCluster` | all view layers | High | Changes affect multiple features and OS/accessibility fallbacks. |
| `Tests/MyAIMapTests/` | Swift Testing unit/pure-core coverage | 43 source files currently | app target | Medium | Tests are broad but do not prove live visual behavior. |
| `Tests/MyAIMapUITests/` | XCUITest smoke and screenshots | four test files | deterministic launch flags | Medium | Screenshots are capture harnesses, not golden-image assertions. |
| `docs/` | Specs, history, QA, process | Markdown | source/tests | Medium | Use baseline docs for current facts; historic reports stay evidence. |

## Safe parallelization

| Work area | Can run independently with | Must not overlap with |
| --- | --- | --- |
| Pure 2D layout tests | Assistant content or documentation | constellation layout/view edits |
| Assistant matching rules | RealityKit work | `UniverseViewModel` mutation/persistence edits |
| Detail-only visual copy | Map geometry (after checking mode contract) | `UniverseMode`, shared glass primitives |
| Documentation research | All implementation work | Documentation files being actively rewritten |
| Legacy spatial audit | 2D code review | Any renderer switch/re-enable work |

## Generated and historical material

- Do not edit `MyAIMap.xcodeproj`; regenerate it from `project.yml` only when a
  future implementation task explicitly requires it.
- Ignore `build-ui-polish/`, screenshots, and other build/capture output for
  architecture authority.
- Treat older `UNIVERSE_*`, sprint, queue, and implementation-report documents
  as dated evidence. They are not safe substitutes for source inspection.
