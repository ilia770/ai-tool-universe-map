# PRODUCT_SPEC — Current implemented behavior

Status: factual reconstruction of the current working tree, 2026-07-16. This
is not a roadmap. `CONFIRMED` claims cite implementation; `INFERRED` claims
need runtime confirmation; `UNKNOWN` claims are intentionally not filled in.

## Product purpose

**CONFIRMED:** My AI Map lets a founder or operator build a local catalog of
AI tools, view it as category branches, ask a catalog-grounded assistant for
guidance, and open/add/remove tools. The map favors legible category and tool
identity over a generic list view. Core evidence: `UniverseViewModel.swift`,
`UniverseMapView.swift`, `SearchDock.swift`, and `AddToolSheet.swift`.

## Feature specification

| Feature | Current implementation | Entry and supported actions | States / persistence | Acceptance criteria from existing behavior |
| --- | --- | --- | --- | --- |
| First launch and empty universe | **CONFIRMED:** `RootShell` overlays `OnboardingOverlay` until `hasSeenOnboarding` is set. An empty-map card supports Add, Ask AI, and loading sample data. | App launch; scrim/Skip/three onboarding actions; map empty-state actions. | Onboarding completion persists; an empty universe remains empty until a user adds or loads data. | First launch shows one overlay; each exit marks it seen; no silent seed load. |
| Current map | **CONFIRMED in source:** `UniverseMapView` mounts `UniverseConstellationView`, which uses `UniverseConstellationLayout`. | Tap branch, tool, or empty space. | Overview, branch focus, selected tool, detail/chat backdrop via `UniverseMode`; no map selection persistence. | Branch and selected-tool taps mutate the single model-owned mode; empty taps step back. |
| Tool detail | **CONFIRMED:** `RootSheet`/`ToolDetailSection` expose selected tool details, related-tool focus, hide/delete guard, copy and optional in-app browser. | Re-tap selected map tool, tool cards/chips, related tool rows. | Compact width uses a sheet; regular width uses a trailing inspector. Tool hide/restore persists. | Core tools cannot be deleted; dismissal restores a map navigation mode. |
| Ask AI | **CONFIRMED:** local `UniverseAssistantCore` is the normal path; `SearchDock` and `ChatScreen` show messages, matched tools, and missing-tool suggestions. | Root Ask AI route, map composer, starter prompts, Send. | Transcript and activity history are in-memory; local subscription counter persists; normal path is offline. | No query is sent when empty; local replies use visible tools; attachment-only sends state that attachments cannot be read. |
| Add tool / branch | **CONFIRMED:** `AddToolSheet` validates input, optionally creates a custom branch, normalizes HTTPS URLs, deduplicates matching tools, and focuses the result. | Root/map plus button, empty-state call-to-action, assistant suggestion. | Tools, custom categories, and hidden IDs persist via `UniverseStore`. | Name must be non-empty; core is not a selectable target; duplicate add restores a hidden matching tool. |
| Settings / account | **CONFIRMED:** `AccountSettingsSheet` presents settings/history and can reset stored universe data. | Root/map account controls. | Haptics and placeholder subscription persist; API key uses Keychain; language value is memory-only. | Reset asks for confirmation; no implemented billing or consumer API-key flow in release. |

## Feature states and limitations

### Implemented

- Root Map/Ask AI surface switching (`RootShell`).
- Empty state, onboarding completion, bundled sample loading, local tool add,
  custom branch create, hide/restore/reset.
- Deterministic 2D constellation layout in the present source tree.
- Compact detail sheet and regular-width inspector path.
- Local search/ranking, local assistant replies, attachment staging UI, copy
  feedback, haptic and Reduce Motion/Transparency policy.

### Partially implemented or experimental

- **EXPERIMENTAL / visually unmounted:** `UniverseRealityView` and its entity,
  gesture, and relation-rendering path are not mounted by the live map.
  `UniverseMapView` still allocates scene/camera/gesture controllers and calls
  camera-focus hooks, so this legacy boundary remains coupled even though its
  spatial output is dormant.
- **EXPERIMENTAL / unmounted:** edge rail interaction (`RightUniverseRail.swift`)
  and `CategoryRail.swift` exist but are not placed in the current overlay.
- **PARTIAL:** DeepSeek is reachable only when hidden DEBUG developer mode and
  a Keychain key are present. RelationAI and RelationCache have no current
  renderer integration.
- **PARTIAL:** attachment selection reads local photo size or file metadata for
  a staged preview, but does not transmit attachment bytes to the assistant;
  the assistant explicitly cannot inspect attachment content.

### Planned, implied, or unknown — not implemented requirements

- **UNKNOWN:** cloud sync, account/authentication, server-side catalog,
  purchasing, a production hosted assistant, and entitlement enforcement.
- **UNKNOWN:** end-user-visible language localization; `appLanguage` is a
  setting value but source strings are not localized.
- **UNKNOWN:** persistence/restoration of current root surface, map selection,
  transcript, or camera state after relaunch.

## Product constraints

- The app starts with a user-owned empty catalog, not a hidden sample catalog.
- Tool claims should remain conservative unless represented in bundled
  `ToolKnowledgeBook` or the user supplied a source URL.
- The current code treats the `core` category/Founder OS as special: it is a
  central layout identity and cannot be hidden through `deleteTool`.
- UI descriptions in historical documents are not acceptance criteria unless
  current code or tests support them.

## Product acceptance boundary for future work

A feature change should state: its entry point; every visible state (empty,
loading, error, cancellation and success); persistence impact; canonical state
owner; expected outcome after relaunch; relevant test; and the manual map/chat
path that demonstrates it. Do not promote a TODO, a historical spec, or a
dead renderer to an approved requirement.

### UI architecture acceptance boundary

This specification owns the product outcome, while
[UI_APPLE_NATIVE_SPEC.md](UI_APPLE_NATIVE_SPEC.md) owns the permanent UI
implementation contract. Any UI change must use the component identity and
transition catalogs before it changes a component tree, presentation, or
interaction. Start from [SPEC_INDEX.md](SPEC_INDEX.md), record conflicts in
[SPEC_CONFLICTS.md](SPEC_CONFLICTS.md), and use
[UI_QA_CHECKLIST.md](UI_QA_CHECKLIST.md) for visual acceptance.

The complete linked architecture set is
[UI_COMPONENT_IDENTITY.md](UI_COMPONENT_IDENTITY.md),
[UI_COMPONENT_LIFECYCLE.md](UI_COMPONENT_LIFECYCLE.md),
[UI_TRANSITION_CATALOG.md](UI_TRANSITION_CATALOG.md),
[UI_MOTION_TOKENS.md](UI_MOTION_TOKENS.md),
[UI_LAYOUT_SYSTEM.md](UI_LAYOUT_SYSTEM.md),
[UI_TYPOGRAPHY.md](UI_TYPOGRAPHY.md),
[UI_ACCESSIBILITY.md](UI_ACCESSIBILITY.md),
[UI_APPLE_NATIVE_AUDIT.md](UI_APPLE_NATIVE_AUDIT.md), and
[UI_IMPLEMENTATION_REPORT.md](UI_IMPLEMENTATION_REPORT.md). These documents
govern implementation quality; this product specification governs behavior.

## Current state coverage by feature

| Feature | Empty | Loading | Error / cancellation | Success | Known limitation |
| --- | --- | --- | --- | --- | --- |
| Onboarding/catalog | Empty catalog receives overlay and map card | No asynchronous loading UI | Skip/scrim safely dismiss; seed resource decode failure is fatal | tool added or sample loaded | no recovery UI for missing/corrupt bundled seed. |
| 2D map | no planets when visible catalog is empty | no explicit loading state | invalid node IDs are ignored by model guards | branch/tool mode updates visible graph | renderer is current-worktree/uncommitted; no active camera gestures. |
| Tool detail | unavailable when no selected/visible tool | no explicit loading state | dismiss returns/re-derives map mode; delete guarded | sheet/inspector shows selected tool | interactive dismiss timing needs runtime check. |
| Assistant | starter/empty transcript prompt | debug network branch has no user-facing loading model established | missing key/network errors fall back to local reply; picker cancellation retains focus | local reply/chips and activity update | attachment contents cannot be read; transcript is volatile. |
| Add tool | blank form / validation state | no remote enrichment load | invalid input stays local; discard requires confirmation | persist, focus, map rebuild | custom branch management is create-only. |
| Settings | persisted catalog may be empty | no service load | Reset has cancel path | haptic/reset/history settings update | no billing, localization, or user sync. |
