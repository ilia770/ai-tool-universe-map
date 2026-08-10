# INTERACTION_SPEC — Current visible behavior

Status: source-level reconstruction. “Visible” means mounted on the current
root/map/chat composition; retained but unmounted components are called out
explicitly so they are not mistaken for user-facing behavior.

**UI architecture links:** interaction changes must preserve the component and
transition identities defined in `UI_COMPONENT_IDENTITY.md` and
`UI_TRANSITION_CATALOG.md`, follow `UI_APPLE_NATIVE_SPEC.md` and
`UI_COMPONENT_LIFECYCLE.md`, and use the visual/accessibility checks in
`UI_QA_CHECKLIST.md`.

## Root surfaces and onboarding

| Surface/control | Action | Implemented response | State effect / notes |
| --- | --- | --- | --- |
| Root Map / Ask AI switch | tap segment | switches `RootShell.surface` | Map/Chat full-surface transition; root chat return resets map navigation to overview. |
| Onboarding actions | tap Ask AI, Add Tool, Explore Map | marks onboarding seen and routes/presents | persistence happens before or with action; scrim and Skip dismiss to map. |
| Onboarding scrim | tap | dismisses overlay | labelled as a button; no second confirmation. |
| Map empty-state Add | tap | opens map-hosted Add Tool sheet | does not silently add data. |
| Map empty-state Ask AI | tap | requests in-map chat activity | user needs runtime QA for keyboard/panel response. |
| Load sample universe | tap | appends seed tools/unhides seed IDs | persists and rebuilds derived map planet list. |

## Current 2D map interaction

| Element | Gesture | Result | Conflict/cancellation |
| --- | --- | --- | --- |
| Category node | Button tap | select/branch focus; re-tap behavior varies by current mode | 44-point target; no active pan/pinch competing gesture. |
| Tool node | Button tap | focus tool; re-tap opens detail | stable `ConstellationStar.*` ID. |
| Empty constellation space | tap | resign keyboard and step mode back in overview/branch/tool modes | unavailable in detail or in-map chat, whose close/restore path is owned by dock activity/blur/collapse callbacks. |
| Core node | no current direct button in overview | visual central identity | **CONFIRMED:** `ConstellationCoreNode` is non-hit-testable; do not claim core is directly tappable in overview. |
| Map breathing/rings | ambient animation | visual only | suppressed by Reduce Motion/static UI test argument. |

**CONFIRMED:** current source has no mounted 2D pan, pinch, rotation, zoom,
or camera motion. RealityKit tap/drag/magnify gestures remain in
`UniverseRealityView`, which is unmounted.

## Assistant, keyboard, and attachments

| Control/state | Action | Implemented response | Cancellation / constraints |
| --- | --- | --- | --- |
| Composer | tap/type | focuses `SearchDock` text field and writes `assistantQuery` | 1–6 lines, local focus; keyboard state is not persisted. |
| Send | tap/submit | sends text or staged attachment title; invokes local assistant | disabled only when neither text nor attachment exists. |
| Plus when composer is fully idle | tap | opens Add Tool flow | a focused-but-empty composer shows disabled Send instead; one composer-level add affordance. |
| Paperclip | tap | toggles menu; opens photo/file system picker | glyph stays paperclip; menu closes on blur/cancellation. |
| Attachment preview | remove/replace | updates local staged payload | no file/image content is interpreted by assistant. |
| Conversation header | collapse/show | toggles local transcript view and reports chat activity | collapsed transcript remains in memory; local dock state resets if view unmounts. |
| Tool/suggestion chip | tap | focus/open detail or begin Add Tool draft | chips read model data; do not fabricate a missing tool. |
| Root full chat transcript | scroll / jump pill / copy | interactive keyboard dismissal, jump to latest, copy toast | independent scroll state from in-map dock. |

`SearchDock` is an assistant composer, not the visible conventional search UI.
`searchQuery`/`searchResults` exist in the model but no mounted text field
binds to them in current source.

The normal assistant path is local. A hidden DEBUG developer mode with a
Keychain key can use DeepSeek and fall back to the local path; do not document
the assistant as unconditionally offline.

## Detail and settings

- Tool detail controls include relation focus, copy, website/search sheet, and
  a confirmation-gated removal action for non-core tools.
- Compact detail uses system sheet drag/dismiss interaction. **REQUIRES RUNTIME
  VERIFICATION:** timing of the Boolean/mode synchronization when dismissed by
  gesture.
- Account settings exposes haptic behavior, reset confirmation, history, and
  debug-gated DeepSeek key UI. Placeholder upgrade behavior is non-billing.
- Add Tool uses local field focus, text validation, branch-mode choice, and a
  discard confirmation. Its submitted result is model-owned/persisted.

## Haptics, pointer, and accessibility

- Haptic calls are centralized and guarded by `hapticsEnabled`; Apple hardware
  response is **REQUIRES RUNTIME VERIFICATION**.
- No hover/pointer-specific interaction was found.
- Current map nodes and major root/onboarding/chat controls have accessibility
  labels/identifiers. The inactive rail deliberately hides itself from VoiceOver
  because its hold/drag interaction has no active accessible alternative.
- Dynamic Type, VoiceOver order, sheet focus, system picker accessibility, and
  keyboard focus on iPad require runtime testing.

## Present-but-not-current interactions

| Component | Source behavior | Current status |
| --- | --- | --- |
| `UniverseRailView` | long-press then drag category selection, haptics, trailing contrast strip | **UNMOUNTED:** `UniverseOverlayView` does not insert it. |
| `CategoryRail` | category selection UI | **UNMOUNTED:** no production call site. |
| `UniverseRealityView` | spatial entity tap, empty tap, drag orbit, pinch zoom | **LEGACY/EXPERIMENTAL:** no current map call site. |
| Camera neighbor snap / 3D labels | camera-driven affordances | **DORMANT** under 2D map. |

Every future visible control must either be wired to a tested action, have a
disabled-state explanation, or be removed through an explicitly authorized
cleanup task. Do not make current documents imply that unmounted rail or 3D
gestures are interactive.
