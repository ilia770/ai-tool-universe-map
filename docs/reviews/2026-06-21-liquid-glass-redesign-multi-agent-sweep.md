# Liquid Glass Redesign Multi-Agent Sweep

Date: 2026-06-21
Branch: `feat/redesign-chatgpt-liquid-glass`
HEAD reviewed: `dc500f8`
Mode: read-only audit, no product code edits

## Scope

This sweep reviewed the current iOS app and the new ChatGPT-style chat-first +
Apple Liquid Glass specs before Phase 0 implementation.

Inputs:

- `docs/superpowers/specs/2026-06-21-chatgpt-liquid-glass-design-direction.md`
- `docs/superpowers/plans/2026-06-21-chatgpt-liquid-glass-redesign-plan.md`
- `docs/superpowers/specs/2026-06-21-motion-haptics-microinteraction-spec.md`
- Current iOS source under `ios-app/Sources/MyAIMap`
- Current tests under `ios-app/Tests`
- SwiftUI API check via Context7 official Apple SwiftUI docs and local Xcode 26.5 SDK interface

## Executive Summary

No P0 was found. Phase 0 should not start as a blind wrapper rename, because the
current glass helper and the new specs still contain foundation-level risks:

1. Current `LiquidGlass.swift` violates the new design contract: every native
   glass surface is interactive, native glass gets manual stroke/clip overlays,
   and reduce-transparency is not handled.
2. The plan/spec contain compile-risk API snippets: nonexistent
   `glassEffect(..., isEnabled:)`, shorthand `Animation` and `SensoryFeedback`
   syntax that should not be copied into code.
3. The app still has several stabilization bugs that can confuse the new
   chat-first IA: detail sheet ownership, 2D rendered label overlap, stale 3D
   focus after add, and assistant intent edge cases.
4. The verification gate is weaker than the plan says: `ios:verify` and CI build
   tests but do not execute the claimed 182-test suite.

## Review Method

The sweep used one coordinator plus six read-only explorer agents. Each agent
was asked to return only confirmed findings with file/line evidence, severity,
why it matters, and an exact fix. Refuted and uncertain findings were separated
so they do not inflate the backlog.

Agent lanes:

| Lane | Scope | Result |
|---|---|---|
| State / root / navigation | `UniverseMapView`, `UniverseViewModel`, sheet state, route ownership | 1 confirmed P1, 4 spec gaps, 2 refuted |
| Chat / assistant / composer | `SearchDock`, `UniverseAssistantCore`, bubbles, attachments, intent routing | 1 repeated P1, 3 confirmed P2, 2 spec gaps |
| Visualization | 2D graph, 3D RealityKit, selection/camera sync, render-mode specs | 1 confirmed P1, 3 confirmed P2, 4 spec gaps |
| Sheets / settings | Add Tool, Tool Detail, Account Settings, rail, current design specs | 1 repeated P1, 3 confirmed P2, 3 spec gaps |
| Motion / haptics | `BrandMotion`, `BrandHaptics`, `CoreHapticsEngine`, SwiftUI/iOS 26 API validity | 4 confirmed P1, 4 confirmed P2, 4 spec gaps |
| Tests / build config / data | `package.json`, CI, UI tests, seed drift, asset/project references | 1 confirmed P1, 3 confirmed P2, 4 missing test gates |

Independent API verification:

- Context7 official Apple SwiftUI docs confirmed `glassEffect(_:in:)`,
  `glassEffectID(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)`,
  `.glassProminent`, `navigationTransition(.zoom(sourceID:in:))`,
  `matchedTransitionSource(id:in:)`, `scrollEdgeEffectStyle(_:for:)`,
  `backgroundExtensionEffect(isEnabled:)`, and
  `sensoryFeedback(_:trigger:)`.
- The installed Xcode 26.5 SDK interface was used by the motion/haptics agent to
  validate exact Swift signatures where docs snippets were too high level.

No simulator/manual UI run was performed in this sweep. Findings that require
rendered screenshots are marked with explicit QA gates below.

## Severity Definitions

| Severity | Meaning |
|---|---|
| P0 | Blocks launch/build or can corrupt user data. None confirmed. |
| P1 | Blocks Phase 0/Phase 2 foundation, can fail build if implemented as written, or breaks primary selected/navigation/readability contracts. |
| P2 | Important stabilization or design-system correctness issue that should be fixed before TestFlight polish or chat-first launch. |
| P3 | Documentation/checklist drift or lower-risk follow-up. |

## Phase Backlog

| ID | Severity | Phase | Area | Summary | Primary files |
|---|---:|---|---|---|---|
| R1 | P1 | Phase 0 | Glass | Replace old `liquidGlass` contract with real `glassSurface` and reduce-transparency fallback | `LiquidGlass.swift`, `BrandColor.swift` |
| R2 | P1 | Phase 0 | Specs | Fix invalid SwiftUI/motion/haptics snippets before agents implement from docs | redesign plan, motion spec |
| R3 | P1 | Phase 0 | Tests | Add real `ios:test`; current verify/CI compiles tests but does not run assertions | `package.json`, `scripts/ios-verify.sh`, `.github/workflows/ios.yml` |
| R4 | P1 | Phase 0 | Tests | Add missing chrome snapshot/render tests promised in release review | `ios-app/Tests/MyAIMapTests` |
| R5 | P1 | Phase 1/2 | State | Detail sheet can stay presented after model leaves `.detail` | `UniverseMapView.swift`, `ToolDetailSection.swift`, `UniverseViewModel.swift` |
| R6 | P1 | Phase 7 | 2D Graph | Layout tests circle distance, not rendered label/card overlap | `UniverseGraphView.swift`, `UniverseGraphLayoutTests.swift` |
| R7 | P2 | Phase 0 | Glass | Current glass call sites include content surfaces; need allowlist | `SearchDock.swift`, `PlanetInfoCard.swift`, sheets/settings |
| R8 | P2 | Phase 0 | Haptics | New `.sensoryFeedback` calls will not honor in-app Haptics toggle unless wrapped | `BrandHaptics.swift`, settings, future call sites |
| R9 | P2 | Phase 0 | Motion | Direct `withAnimation(BrandMotion.*)` bypasses reduce-motion resolver | `SearchDock.swift`, `UniverseMapView.swift` |
| R10 | P2 | Phase 0 | Haptics | Core Haptics engine does not lazily restart after stop | `CoreHapticsEngine.swift` |
| R11 | P2 | Phase 0 | Haptics | Duplicate press/action haptics already produce two felt meanings per tap | `PressBounce.swift`, `SearchDock.swift`, `PlanetInfoCard.swift` |
| R12 | P2 | Phase 2 | Root IA | Root route owner for chat-first is undefined | `MyAIMapApp.swift`, new `RootShell`, `UniverseMode.swift` |
| R13 | P2 | Phase 2 | Onboarding | First-run chat starter data source is unresolved with empty user map | `UniverseViewModel.swift`, `UniverseStore.swift`, seed data |
| R14 | P2 | Phase 3 | Chat | Domain recommendation phrasing can still fall into missing-service path | `UniverseAssistantCore.swift`, assistant tests |
| R15 | P2 | Phase 3 | Chat | Multi-word unknown product can fall into generic chat instead of add-tool path | `UniverseAssistantCore.swift`, assistant tests |
| R16 | P2 | Phase 3 | Composer | Attachment menu is normal layout, not anchored overlay | `SearchDock.swift` |
| R17 | P2 | Phase 5 | Add Tool | Add Tool form uses a medium detent despite keyboard-heavy form usage | `UniverseMapView.swift`, `AddToolSheet.swift` |
| R18 | P2 | Phase 7 | 3D | Core satellites do not camera-focus when selected | `UniverseMapView.swift`, `UniverseSceneController.swift` |
| R19 | P2 | Phase 7 | 3D | Add-tool selection can race stale cached `planets` projection | `UniverseMapView.swift`, `UniverseViewModel.swift` |
| R20 | P2 | Data | Catalog | iOS seed is 53-tool fork while comments claim canonical web seed | `UniverseSeed.swift`, iOS seed JSON, web seed |
| R21 | P2 | UI | Right rail | Active right rail draws full-screen scrim contrary to spec | `UniverseOverlayView.swift`, `RIGHT_RAIL_SPEC.md` |
| R22 | P2 | A11y | Dynamic Type | Fixed-size typography can contradict accessibility checklist | `BrandTypography.swift`, `ToolDetailSection.swift`, `PlanetInfoCard.swift` |

## File Ownership Map

Primary implementation files likely touched by follow-up fixes:

- `ios-app/Sources/MyAIMap/UI/Effects/LiquidGlass.swift` - Phase 0 wrapper.
- `ios-app/Sources/MyAIMap/UI/Theme/BrandColor.swift` - `glassSolid`, accent
  ramp, chat ramp.
- `ios-app/Sources/MyAIMap/UI/Theme/BrandMotion.swift` - seven new motion
  tokens and reduce-motion-safe helper for action blocks.
- `ios-app/Sources/MyAIMap/UI/Haptics/BrandHaptics.swift` - app-level haptic
  gate and future sensory-feedback helper.
- `ios-app/Sources/MyAIMap/UI/Haptics/CoreHapticsEngine.swift` - lazy restart,
  `toolLand`, `ticker(count:)`.
- `ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift` - detail ownership,
  Add Tool detent, 3D camera focus, cached `planets` race.
- `ios-app/Sources/MyAIMap/Universe/UniverseGraphView.swift` - rendered-frame
  overlap behavior.
- `ios-app/Sources/MyAIMap/UI/Search/SearchDock.swift` - attachment overlay,
  glass/content split, duplicate haptics, future chat-first extraction.
- `ios-app/Sources/MyAIMap/UI/Search/UniverseAssistantCore.swift` - intent
  routing for recommendation vs lookup vs general chat.
- `ios-app/Sources/MyAIMap/UI/Settings/AddToolSheet.swift` - large-only form,
  dirty-state dismissal protection.
- `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift` - first-run chat data
  source and add-tool focus sequence.
- `ios-app/Tests/MyAIMapTests/*` - new glass, chrome render, assistant intent,
  2D rendered-frame, 3D focus tests.
- `scripts/ios-verify.sh`, `package.json`, `.github/workflows/ios.yml` - test
  execution gate.

## Confirmed Findings

### P1 - Liquid Glass foundation violates the redesign contract

Evidence:

- Current helper is old `.liquidGlass(...)`, not `glassSurface(...)`:
  `ios-app/Sources/MyAIMap/UI/Effects/LiquidGlass.swift:18`
- iOS 26 native path always applies `.interactive()`:
  `LiquidGlass.swift:45`, `LiquidGlass.swift:52`
- Native path adds manual stroke and clips glass:
  `LiquidGlass.swift:46`, `LiquidGlass.swift:49`, `LiquidGlass.swift:53`,
  `LiquidGlass.swift:56`
- No `accessibilityReduceTransparency` branch; fallback still uses material:
  `LiquidGlass.swift:23`, `LiquidGlass.swift:67`
- Content surfaces still use glass, including chat panel and user bubbles:
  `SearchDock.swift:379`, `SearchDock.swift:508`

Why it matters:
Phase 0 is supposed to create the foundation for all later migration. If it
keeps this helper shape, it preserves the exact over-glassing and accessibility
problem the redesign is meant to remove.

Exact fix:
Replace the old helper with `glassSurface(in:tint:interactive:)`. Check
`accessibilityReduceTransparency` first and return an opaque `glassSolid`
surface. On iOS 26 call `.glassEffect(glass, in:)` without manual stroke/clip.
Default `interactive` to `false`; opt in only for controls. Keep content cards,
chat bubbles, sheet bodies, and detail panels solid/material.

### P1 - Specs contain compile-risk Swift syntax

Evidence:

- Plan documents `.glassEffect(..., isEnabled:)`, but public SwiftUI exposes
  `glassEffect(_:in:)` only: `docs/superpowers/plans/2026-06-21-chatgpt-liquid-glass-redesign-plan.md:33`
- Motion spec uses shorthand `.easeOut(0.18)`, `.easeInOut(0.62)`,
  `.spring(0.5,0.86)`: `docs/superpowers/specs/2026-06-21-motion-haptics-microinteraction-spec.md:21`
- Haptic examples use shorthand `.impact(.light,)` and `.impact(.soft,)`:
  `motion-haptics-microinteraction-spec.md:45`

Why it matters:
Agents implementing directly from these specs can produce code that fails at the
first build.

Exact fix:
Update docs before coding:

- Use `Animation.easeOut(duration:)`, `Animation.easeInOut(duration:)`, and
  `Animation.spring(response:dampingFraction:)` or the intended newer labeled
  initializer.
- Use `SensoryFeedback.impact(weight:intensity:)` or
  `SensoryFeedback.impact(flexibility:intensity:)`.
- Remove `isEnabled:` from `glassEffect` references and branch outside the call.

### P1 - Detail sheet can outlive `.detail` navigation state

Evidence:

- Compact detail presentation is owned by local `detailPresented`:
  `ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift:12`,
  `UniverseMapView.swift:159`
- `ToolDetailSection` removes a tool by calling `model.deleteTool(...)`:
  `ios-app/Sources/MyAIMap/UI/Sheets/ToolDetailSection.swift:529`
- `deleteTool` exits `.detail` by mutating `universeMode`:
  `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift:306`
- The local sheet boolean is not cleared when the model leaves `.detail`.

Why it matters:
The sheet can stay visible while map mode has already restored gestures/chrome.
That breaks the single-state model and can leak impossible UI states into the
new root shell.

Exact fix:
Derive compact detail presentation from `model.universeMode.isDetailOpen`, or
add a parent-owned dismissal path that clears `detailPresented` whenever
`universeMode` leaves `.detail`.

### P1 - 2D Graph layout tests circles, not rendered labels/cards

Evidence:

- Layout collision uses node centers/radii:
  `ios-app/Sources/MyAIMap/Universe/UniverseGraphView.swift:46`
- Rendered `GraphNodeButton` includes a larger vertical stack with glow circle
  plus two text lines:
  `UniverseGraphView.swift:637`, `UniverseGraphView.swift:668`
- Current test checks only radius separation:
  `ios-app/Tests/MyAIMapTests/UniverseGraphLayoutTests.swift:17`

Why it matters:
2D Graph is now the default readable renderer. The full seed can pass radius
tests while visible labels/cards overlap.

Exact fix:
Make the layout/collision pass operate on rendered rects, including label
width/height and selected scale, or hide/cull non-focused tool labels. Add tests
for rendered frame intersection at SE, regular iPhone, and iPad widths.

### P1 - Verification gate does not execute the claimed test suite

Evidence:

- `package.json` maps `ios:verify` to `scripts/ios-verify.sh`.
- Default script runs build + `build-for-testing`, not `xcodebuild test`:
  `scripts/ios-verify.sh:17`, `scripts/ios-verify.sh:127`
- CI also uses `--test-build-only`: `.github/workflows/ios.yml:52`
- Redesign plan requires "build + 182 tests green":
  `docs/superpowers/plans/2026-06-21-chatgpt-liquid-glass-redesign-plan.md:69`

Why it matters:
Phase 0 can pass the named verification path while executing zero assertions.

Exact fix:
Add an explicit `ios:test` script that runs `xcodebuild test` with an xcresult
bundle and make Phase 0 require the passed test count. Keep compile-only as
`ios:test-build` if CI needs a fast gate.

### P1 - Chrome snapshot safety net is documented but missing

Evidence:

- `docs/RELEASE_REVIEW.md:108` says `ChromeSnapshotTests.swift` covers
  `SearchDock`, `CategoryRail`, `ToolDetailSection`, etc.
- No `*Snapshot*` or `ChromeSnapshotTests.swift` exists under `ios-app/Tests`.

Why it matters:
Phase 0 rewrites glass and tokens, exactly the kind of change a chrome snapshot
harness should catch.

Exact fix:
Add SwiftUI render tests with `ImageRenderer` for key chrome in normal and
reduce-transparency environments.

### P2 - Chat assistant still has intent edge cases

Evidence:

- Domain routing recognizes a narrow phrase set:
  `ios-app/Sources/MyAIMap/UI/Search/UniverseAssistantCore.swift:570`
- Multi-token matching requires score 2:
  `UniverseAssistantCore.swift:452`
- `tool` is treated as service intent:
  `UniverseAssistantCore.swift:316`
- `isGeneralConversation` returns true for any unmatched query with 2+ tokens:
  `UniverseAssistantCore.swift:345`

Why it matters:
The old `"как дела"` bug is fixed, but chat-first still has two bad paths:

- "I need a design tool" can become a missing-service URL request.
- A two-word unknown product such as "Magic Canvas" can become generic chat
  instead of the add-tool contribution path.

Exact fix:
Broaden domain-intent phrases for "I need", "looking for", "want",
"help me choose", plus Russian equivalents. Make name-like unmatched 1-3 token
queries route to missing-service/add-tool, while small talk remains general.
Add tests for both paths.

### P2 - Attachment menu is in normal layout, not anchored overlay

Evidence:

- Popover is inserted directly in `SearchDock`'s `VStack`:
  `ios-app/Sources/MyAIMap/UI/Search/SearchDock.swift:98`
- Popover is normal layout:
  `SearchDock.swift:221`
- Transcript has fixed `maxHeight: 284`:
  `SearchDock.swift:365`

Why it matters:
With keyboard, existing messages, and the menu open, small devices can still
stack/clip awkwardly.

Exact fix:
Anchor the menu as an overlay above the composer, compute transcript height from
available geometry/keyboard space, or collapse/reduce transcript while the menu
is open.

### P2 - 3D camera does not focus selected core satellites

Evidence:

- Core satellite selection is expected in tests:
  `ios-app/Tests/MyAIMapTests/UniverseModeTests.swift:40`
- Scene renders core satellites except `founder-os`:
  `ios-app/Sources/MyAIMap/Universe/UniverseSceneController.swift:170`
- `focusCamera` returns to overview for `.core` before checking selected tool:
  `ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift:284`

Why it matters:
The selected card/anchor can say a core satellite is selected while the camera
stays in overview.

Exact fix:
Handle `mode.selectedToolID` before the `.core` overview guard. For non-founder
core tools, focus using the same index/count as `UniverseSpatialLayout`; for
`founder-os`, focus the core.

### P2 - Added-tool focus can race stale `planets`

Evidence:

- `addCustomTool` appends the tool and immediately calls `focusTool`:
  `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift:380`
- `universeMode` change focuses camera before cached `planets` rebuild:
  `ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift:143`,
  `UniverseMapView.swift:185`
- `focusCamera` requires selected tool to be present in cached `planets`:
  `UniverseMapView.swift:290`

Why it matters:
In 3D, a new tool can be selected in state while the camera focuses old
category/overview. This directly undermines the planned card-to-orbit morph.

Exact fix:
Make `planets` a computed projection of `model.visibleAllTools`, or rebuild
planets and refocus current mode inside the visible-tools change handler.

### P2 - Haptics ownership and lifecycle need cleanup before feel layer

Evidence:

- New `.sensoryFeedback` haptics would not honor the app-level Haptics toggle
  unless wrapped.
- Duplicate haptics already exist: style press haptic plus action semantic
  haptic, for example `SearchDock.swift:200`, `SearchDock.swift:300`,
  `SearchDock.swift:781`, `PlanetInfoCard.swift:16`,
  `UniverseMapView.swift:314`.
- Direct `withAnimation(BrandMotion.*)` bypasses the reduce-motion resolver:
  `SearchDock.swift:203`, `SearchDock.swift:785`, `UniverseMapView.swift:211`
- `CoreHapticsEngine` nils `engine` on stop but does not recreate it in `play`:
  `ios-app/Sources/MyAIMap/UI/Haptics/CoreHapticsEngine.swift:30`,
  `CoreHapticsEngine.swift:46`

Exact fix:
Add a project-owned sensory feedback wrapper that gates on
`model.hapticsEnabled`; enforce one haptic owner per interaction; add an
environment-aware `withBrandAnimation`; recreate/start Core Haptics lazily in
`play`.

### P2 - Right rail active state covers the map

Evidence:

- `RIGHT_RAIL_SPEC.md:7` says the rail must not cover the map.
- Current overlay draws full-screen material and black opacity when active:
  `ios-app/Sources/MyAIMap/Universe/UniverseOverlayView.swift:54`

Exact fix:
Remove the full-screen scrim or constrain contrast treatment to the trailing
rail/list width.

### P2 - Add Tool form still uses a medium-ish detent

Evidence:

- Form-sheet guidance says Add Tool should be large-only.
- Current presentation allows `.fraction(0.72)` plus `.large`:
  `ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift:173`

Exact fix:
Use `.large` only for `AddToolSheet`; add dirty-state dismissal protection if
the user has typed.

### P2 - Data source is unresolved for chat-first first run

Evidence:

- Store/model intentionally start empty:
  `ios-app/Sources/MyAIMap/State/UniverseStore.swift:5`
- User map tools are only custom tools:
  `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift:92`
- Assistant replies use `visibleAllTools`:
  `UniverseViewModel.swift:268`
- The design expects starter chips to fire real curated recommendations before
  the map is built.

Exact fix:
Decide whether chat searches the seed catalog separately from the user's map,
or whether the catalog is loaded differently for chat-first onboarding.

### P2 - iOS seed has intentionally drifted from documented web seed

Evidence:

- `UniverseSeed.swift` claims exact canonical web seed.
- iOS seed has 9 categories / 53 tools, including `analytics` and `posthog`.
- Web seed has 8 categories / 49 tools and no `analytics` category.

Exact fix:
Promote the 53-tool iOS seed to canonical web seed, or document iOS as a forked
seed. Add a parity/generation test so drift is intentional.

## Refuted Or Already Fixed From Earlier Bug Sweep

- The original black-screen-on-focus path appears fixed in source: chat mode
  keeps map opacity and dim opacity non-black in `UniverseMode.swift`.
- User bubble width is now container-based via `dockWidth`, not `UIScreen`.
- Duplicate in-message Attach/Add Tool buttons are not currently rendered;
  messages show a hint and the composer owns actions.
- Add Tool Auto/Manual logic appears aligned and covered by tests.
- Haptics setting is now persisted in `UniverseStore`.
- Visualization mode is persisted and user-facing state is `UniverseRenderMode`;
  old A/K/N/O presets are not exposed.
- Settings language control is intentionally disabled/explanatory rather than a
  live no-op.

## Spec Gaps To Resolve Before Phase 0

1. Define a glass allowlist by call site before migration:
   `glassSurface(interactive:)`, solid/material, or deleted with old IA.
2. Fix the plan/spec API syntax noted above.
3. Resolve plan contradiction: Phase 1 says migrate sheet bodies to glass,
   while the design direction says sheet bodies are solid/material.
4. Update the plan's open decisions; design direction already chose
   morph-switch, chat cold start, and settings sheet.
5. Clarify route ownership for chat-first root:
   new `RootSurface.chat/universe` vs reusing `UniverseMode.chatOpen`.
6. Define first-run chat starter data source and map gating owner.
7. Expand fallback wording to iOS 18-25, not only iOS 25.
8. Gate every iOS 26-only chrome API, not just `glassEffect`: glass button
   styles and `scrollEdgeEffectStyle` also need availability wrappers.

## Required Phase 0 Acceptance Gates

Phase 0 is only done when all of these are true:

1. `LiquidGlass.swift` exposes the new `glassSurface(in:tint:interactive:)`
   helper or an equivalent API with the same semantics.
2. `accessibilityReduceTransparency == true` produces an opaque surface and does
   not use `.ultraThinMaterial` or native glass.
3. iOS 26 path uses native `.glassEffect(_:in:)` without manual stroke/clip
   overlays.
4. iOS 18-25 fallback renders without compile-time references to iOS 26-only API
   outside availability guards.
5. `interactive` defaults to `false`; only actual controls opt into
   `.interactive()`.
6. Existing content surfaces are not blindly migrated to glass. Each old
   `.liquidGlass` call site is classified as glass, solid/material, or removed.
7. Specs no longer contain copy-paste-invalid API snippets.
8. A real `xcodebuild test` path exists and is run locally at least once.
9. A chrome render/snapshot test covers normal and reduce-transparency output.
10. Screenshots are captured for one existing sheet, the composer/dock, and a
    small-device run after the helper lands.

## Required Tests To Add Or Harden

| Area | Test |
|---|---|
| Glass wrapper | Static/compile test that direct `.glassEffect` use is centralized and availability-gated. |
| Reduce transparency | Render `glassSurface` under `accessibilityReduceTransparency` and assert opaque fallback path. |
| Brand tokens | Extend `BrandTokensTests` for `glassSolid`, `accent`, `accentInk`, `accentSubtle`, glass radii, and chat typography. |
| Chrome render | Add `ChromeSnapshotTests.swift` or equivalent `ImageRenderer` tests for `SearchDock`, `CategoryRail`, `ToolDetailSection`, `AddToolSheet`, `AccountSettingsSheet`. |
| Assistant intent | Add tests for `как дела`, `yak дела`, `I need a design tool`, `looking for analytics`, `Magic Canvas`, and single-token unknown service. |
| Detail ownership | Removing selected tool from compact detail dismisses/updates detail sheet state. |
| 2D graph | Rendered node frames do not overlap at SE, regular iPhone, and iPad widths. |
| 3D focus | Selecting `openswarm` in `.core` focuses a satellite instead of overview. |
| Add tool focus | Adding a tool in 3D rebuilds planets before camera focus. |
| UI smoke | Convert current screenshot harness to hard assertions for launch, account/settings, composer, graph node, and Add Tool sheet. |

## Manual QA Matrix

Run after Phase 0 foundation and again after Phase 2 chat-first root:

| Device / mode | Required states |
|---|---|
| iPhone SE-class | Launch, composer, attachment menu, Add Tool keyboard, detail sheet, reduce transparency. |
| Modern iPhone | 2D Graph default, chat open/collapse, tool detail, settings visualization switch, haptics toggle. |
| iPad regular width | Trailing inspector, compact sheet avoidance, right rail, split/Stage Manager width. |
| iOS 18-25 fallback | No iOS 26 API compile/runtime crash, fallback surfaces readable. |
| iOS 26 native | Glass chrome only, no over-glassed content, no manual stroke/clip artifacts. |
| Reduce Motion | Direct `withAnimation` paths resolved or disabled; haptics still follow policy. |
| Reduce Transparency | Opaque fallback, no translucent material in glass wrapper. |
| VoiceOver / Dynamic Type | Selected card/detail text not clipped; Map count has accessibility value. |

## Fix Ticket Drafts

These are ready to convert into issues/PRs:

### Ticket 1 - Phase 0 glass foundation

Files:

- `UI/Effects/LiquidGlass.swift`
- `UI/Theme/BrandColor.swift`
- `UI/Theme/BrandRadius.swift`

Tasks:

- Add `glassSurface(in:tint:interactive:)`.
- Add opaque `glassSolid`.
- Remove native manual stroke/clip from glass path.
- Add reduce-transparency branch.
- Keep old `.liquidGlass` temporarily as a deprecated wrapper only if it helps
  mechanical migration.

Exit:

- Build green.
- New glass contract tests pass.
- Manual screenshot of one sheet and composer.

### Ticket 2 - Verification gate

Files:

- `package.json`
- `scripts/ios-verify.sh`
- `.github/workflows/ios.yml`
- `ios-app/Tests/MyAIMapTests`

Tasks:

- Add `ios:test` that runs `xcodebuild test`.
- Preserve compile-only as explicit `ios:test-build`.
- Add chrome render tests.
- Make UI smoke hard-fail on missing critical states.

Exit:

- `ios:test` produces an xcresult and reports passed test count.

### Ticket 3 - State ownership cleanup

Files:

- `UniverseMapView.swift`
- `ToolDetailSection.swift`
- `UniverseViewModel.swift`
- `UI_STATE_MACHINE.md`

Tasks:

- Derive compact detail sheet from `.detail`, or centrally clear
  `detailPresented` when mode leaves `.detail`.
- Document sheet ownership before `RootShell`.

Exit:

- Delete selected tool from detail cannot leave stale sheet.

### Ticket 4 - Chat intent cleanup

Files:

- `UniverseAssistantCore.swift`
- `UniverseAssistantCoreTests.swift`

Tasks:

- Expand recommendation phrase detection.
- Split general chat from name-like missing-service lookup.
- Add regression tests for RU/EN small talk, recommendations, unknown single
  and multi-word tools.

Exit:

- General chat does not ask for website.
- Recommendation asks return tool/category recommendations.
- Unknown product names route to add-tool URL request.

### Ticket 5 - 2D/3D visualization stabilization

Files:

- `UniverseGraphView.swift`
- `UniverseGraphLayoutTests.swift`
- `UniverseMapView.swift`
- `UniverseViewModel.swift`

Tasks:

- Add rendered-frame overlap model or cull non-focused labels.
- Handle core satellite selected camera focus.
- Rebuild `planets` before focus after add.

Exit:

- 2D default is readable on SE/modern/iPad widths.
- 3D selected card/camera/node stay in sync after core select and Add Tool.

## Recommended Order

1. Patch docs/specs so implementation agents do not copy invalid API syntax.
2. Add test gates: real `ios:test`, smoke hard assertions, chrome render tests.
3. Implement `glassSurface` foundation with reduce-transparency and iOS 18-25
   fallback.
4. Inventory and migrate glass call sites by allowlist, not blanket replace.
5. Fix detail sheet ownership and Add Tool detent before chat-first root work.
6. Fix 2D rendered-frame overlap before defaulting screenshots around graph.
7. Fix assistant intent edge cases before full ChatScreen launch.
8. Fix 3D core/add focus before signature card-to-orbit morph.

## Commands And Tools Used

- `git worktree list --porcelain`
- `git status --short`
- `git show --stat --oneline --decorate HEAD`
- `rg --files ...`
- `sed -n ...` and `nl -ba ...` for source/doc review
- Context7 official Apple SwiftUI docs lookup for current SwiftUI API surface
- Six read-only parallel explorer agents covering state, chat, visualization,
  sheets/settings, motion/haptics, and tests/build config

Builds/tests were not run during this sweep. No source code was changed by the
agents.
