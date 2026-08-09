# DATA_AND_PERSISTENCE — Models, storage, and network boundaries

## Domain models

| Model | Location | Identity/relationships | Current use |
| --- | --- | --- | --- |
| `Tool` | `Data/Tool.swift` | string `id`; category, stage, orbit, angle, optional URL/logo domain, relation IDs | user catalog, map, assistant, detail. |
| `ToolCategoryId` / `ToolCategory` | `Data/ToolCategory.swift` | extensible string ID; built-ins plus runtime custom values | category branch identity and visual metadata. |
| `UniverseLink` | `Data/Tool.swift` | source/target strings, strength, optional confidence | decoded seed link data; current 2D map does not visibly render it. |
| `UniverseMode` / derived `UniverseSelection` | `Universe/UniverseMode.swift`, `State/UniverseSelection.swift` | category/tool associated values | map navigation and projection, never persisted. |
| `AssistantMessage`, `UniverseActivity`, `SubscriptionState` | `State/UniverseSelection.swift`, `SubscriptionState.swift` | UUID session messages/activity; local usage counter | transcript/activity volatile; subscription persisted. |

## Bundled and derived data

- **CONFIRMED:** `Resources/ai-tool-universe.seed.json` is decoded by
  `UniverseSeed` once per process. Current resource comment/test contract is
  nine categories, 53 tools, and seven workflow links; `founder-os` is the
  central/core identity.
- **CONFIRMED:** seed data is not automatically the user's persisted universe.
  `loadSampleUniverse()` explicitly copies seed tools into user data.
- **CONFIRMED:** `ToolKnowledgeBook` is a static local enrichment table;
  unknown/custom tools receive cautious fallback knowledge.
- **CONFIRMED:** custom categories are registered in a process-global seed
  lookup dictionary after load/mutation so common code can resolve them.

## Persistent storage matrix

| Storage | Key / identifier | Data | Default / semantics |
| --- | --- | --- | --- |
| `UserDefaults` | `universe.customTools.v1` | JSON `[Tool]` | empty catalog. |
| `UserDefaults` | `universe.customCategories.v1` | JSON `[ToolCategory]` | empty list. |
| `UserDefaults` | `universe.hiddenToolIDs.v1` | JSON `[String]` | empty; core ID is sanitized out on load. |
| `UserDefaults` | `universe.hapticsEnabled.v1` | Bool | defaults true. |
| `UserDefaults` | `universe.hasSeenOnboarding.v1` | Bool | absent defaults false, so onboarding appears. |
| `UserDefaults` | `universe.subscription.v1` | JSON `SubscriptionState` | `.free` placeholder. |
| `UserDefaults` | `developer.modeEnabled` | Bool | used only in DEBUG. |
| `UserDefaults` | `constellation.aiRelations.v1` | JSON relation map | `RelationCache`; currently no live caller. |
| Keychain | service `com.ilyatur.myaimap.secrets`, account `deepseek.apiKey` | developer DeepSeek key | `AfterFirstUnlockThisDeviceOnly`; never place it in UserDefaults. |

### Mutation and deletion semantics

- Add tool normalizes an HTTPS URL, deduplicates by slug/host where possible,
  may restore a hidden match, then focuses the result.
- Hide/delete adds an eligible non-core ID to `hiddenToolIDs`; it does not
  remove the tool record. Restore removes that ID.
- Reset clears custom tools/categories/hidden IDs and returns map mode to
  overview. It does not claim to clear Keychain API keys.
- Custom branches can be created and persisted but have no independent
  rename/delete/migration API.
- Serialization failures are silently decoded as defaults. There is no schema
  migration or recovery UI; v1 key changes need an explicit migration design.

## What survives

| Event | Confirmed survives | Not persisted / reset |
| --- | --- | --- |
| View recreation | Model-owned values normally survive while app scene/model survives | local `@State` can reset if its view is recreated. |
| Navigation across root Map/Chat | catalog/settings and model transcript survive; root/map local presentation state varies | dock focus/collapse/attachment state is local to its mounted view. |
| App background/relaunch | **INFERRED:** UserDefaults values are loaded by new `UniverseViewModel`; intended to survive | map mode, root surface, selection, query, transcript, activity history, language, visualization style. |
| App reinstall | **UNKNOWN:** no code/test proves UserDefaults or Keychain result | do not promise any data retention. |

## Network and external data

- Default assistant behavior is local `UniverseAssistantCore`; it needs no
  network.
- `DeepSeekClient` is a plain `URLSession` OpenAI-compatible request to
  `https://api.deepseek.com/chat/completions`, 30-second timeout. It is
  reachable only in DEBUG when developer mode and a Keychain key are present;
  errors fall back to local assistant text.
- `AssistantBackend.hosted` is declared but unimplemented.
- `RelationAI` can call DeepSeek and `RelationCache` can persist results, but
  neither is wired to the live renderer/product flow.
- Tool detail may open user-initiated Safari/website or DuckDuckGo search URLs.
- There is no API-backed catalog, account/auth, cloud sync, Core Data,
  SwiftData, CloudKit, import/export, or cache beyond the relation utility.

## Assets and localization

- AppIcon, AccentColor, UserAvatar, GitHub PDF logo asset, launch storyboard,
  and seed JSON are bundled under `Sources/MyAIMap/Resources`.
- `ToolLogoView` uses bundled candidates where available and otherwise renders
  local monogram/category fallback. No remote-logo fetcher is implemented.
- No `.strings`, `.xcstrings`, `.lproj`, or localization API usage was found.
  `AppLanguage` is unpersisted and its settings picker is disabled; it is not
  evidence of shipped English/Russian localization.
