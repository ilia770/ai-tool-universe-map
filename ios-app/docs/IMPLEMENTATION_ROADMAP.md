# IMPLEMENTATION_ROADMAP

Consolidated, ordered roadmap for the map-first + Ask AI + Liquid Glass redesign, mapped
to the seven domain specs in `ios-app/docs/`. Each phase lists scope, the specs
it implements, exact files, dependencies/order, a done-definition, and an
**already-done-in-main vs remaining** split so finished work is not redone.

Grounded in `origin/main` plus the active stabilization branch. Main has already merged the
root IA (`RootShell`, `ChatScreen`), the real Liquid Glass foundation,
chat motion/polish (Phase 3-4 commits), Dynamic Type fixes, the DeepSeek backend
seam, and the 2D/3D render-mode switch. Many items the original handoff listed as
"NOT DONE" are now done on main — this roadmap reflects main, not the handoff.

Build/test gate for every phase:
`bash scripts/ios-verify.sh --run-tests` (xcodegen → build → `xcodebuild test`;
confirm xcresult `passedTests` ≥ prior, `failedTests == 0`). New test files
require xcodegen, so always go through the script. See `QA_REGRESSION_CHECKLIST.md`.

Referenced specs: `INPUT_CHAT_SPEC.md`, `CHAT_AI_SPEC.md`, `ADD_TOOL_SPEC.md`,
`UNIVERSE_MAP_SPEC.md`, `RIGHT_RAIL_SPEC.md`, `TOOL_DETAIL_SPEC.md`,
`DETAIL_SCREEN_SPEC.md`, `VISUALIZATION_SPEC.md`, `SETTINGS_PROFILE_SPEC.md`,
`UI_STATE_MACHINE.md`.

---

## Phase order at a glance

1. First-run + navigation (map-first launch, Ask AI route, Map switch)
2. Visual system (Liquid Glass foundation + chrome migration)
3. Chat / input / attachments / copy
4. Add-tool
5. Ask-AI intelligence
6. Settings / profile
7. Map interactions

Phases 1-3 are largely **landed on main / this stabilization branch**; the remaining net-new work is
concentrated in **Phase 6 (settings/profile)** and the **polish tail** of
phases 4, 5, and 7. Dependency spine: 2 (glass tokens) underpins all chrome →
1 (shell) hosts every surface → 3/4/5 are the chat surfaces → 6 is reachable
from the shell → 7 is the secondary mode.

---

## Phase 1 — First-run + navigation

**Scope:** Map-first first run with an obvious Ask AI route. A `RootShell` owns
the Chat <-> Universe surfaces via a morph switch (not TabView), with a Map pill
and a visible Ask AI control. First-run shows the map / map preview plus
onboarding clarity, not a confusing empty question state.

**Specs implemented:** `UI_STATE_MACHINE.md` (single source of truth, global vs
local state), `INPUT_CHAT_SPEC.md` (focus must not blank the screen).

**Files:** `MyAIMapApp.swift` (WindowGroup → `RootShell`), `RootShell.swift`
(`RootSurface` chat/universe, Map pill, `badgeShouldPop`, add-flow ghost flight),
`UI/Search/ChatScreen.swift`, `Universe/UniverseMapView.swift` (secondary mode),
`State/UniverseViewModel.swift` (`isUniverseEmpty`, `assistantMessages`).

**ALREADY DONE in main / this stabilization branch:**
- `RootShell` is the WindowGroup content; cold start lands on the map surface
  and exposes the `RootShell.ShowChat` Ask AI route.
- Chat ⇄ Universe morph switch + dive transition; Map pill with live count badge
  and `badgeShouldPop` (commits `69e444e`, `b433f22`).
- Empty-state / first-run starter messages seeded in `MyAIMapApp.swift`.
- Current first-run contract is map-first: UI smoke waits for
  `RootShell.ShowChat` on launch, then opens Ask AI and returns through
  `RootShell.ShowUniverse`.
- Collapse chat now releases the map from `UniverseMode.chatOpen` while keeping
  the transcript resumable through the small Show Chat pill.
- Low-tool / first-run maps are always reachable. Runtime copy no longer says
  that map access is gated by tool count.

**REMAINING:**
- The old "gate universe until >=3 nodes" product rule has been consciously
  dropped for navigation. Empty/low-tool maps remain reachable and must explain
  themselves through first-run/empty-state copy.
- Confirm input focus never drives global dim/blur (the black-screen bug in
  `INPUT_CHAT_SPEC.md`) — regression-check after any composer change.

**Done when:** fresh launch is understandable within 5 seconds; Ask AI opens
chat; Map switch works both ways; collapsing chat returns map interaction;
focusing the composer never blanks the screen; gate runs green.

---

## Phase 2 — Visual system (Liquid Glass)

**Scope:** One coherent iOS 26 Liquid Glass language. Real `glassEffect` APIs
with reduce-transparency and pre-iOS-26 fallbacks; glass only on floating
nav/controls, content stays on solid/material; tightened tokens.

**Specs implemented:** cross-cutting — applies to every chrome surface in the
other specs (composer, toolbars, HUD pill, sheets).

**Files:** `UI/Effects/LiquidGlass.swift` (`glassSurface(in:tint:interactive:)`),
`BrandColor` / `BrandRadius` / `BrandMotion` / `BrandTypography` tokens, and the
glass call sites in `SearchDock.swift`, `ToolDetailSection.swift`,
`RightUniverseRail.swift`, `AddToolSheet.swift`, `AccountSettingsSheet.swift`,
universe HUD (`UniverseOverlayView.swift`).

**ALREADY DONE in main / this stabilization branch:**
- Real `glassEffect` 3-tier `glassSurface` (R1/R2): reduce-transparency → opaque
  `BrandColor.glassSolid`; iOS 26 → native; iOS 18-25 → material + hairline.
- Tokens added: `glassSolid`, `glassControl`/`glassButton` radii, 7 `BrandMotion`
  tokens + `withBrandAnimation`.
- Glass allowlist migration of SearchDock / CategoryRail / AddTool /
  AccountSettings / PlanetInfoCard (R7); chrome snapshot tests (R4).
- Navigation chrome now shares morph identities across RootShell route controls,
  SearchDock collapse/show-chat, Universe top chrome, and modal sheet toolbar
  actions.

**REMAINING:**
- R9: replace any remaining direct `withAnimation(BrandMotion.*)` call sites that
  bypass reduce-motion with `withBrandAnimation` (hot paths: `SearchDock`,
  `UniverseMapView`).
- Confirm no nested/over-glassing regressions (HIG: content surfaces stay solid).

**Done when:** all chrome uses `glassSurface`; reduce-transparency yields fully
opaque legible UI; no content surface is glassed; snapshot tests green.

---

## Phase 3 — Chat / input / attachments / copy

**Scope:** ChatGPT-grade conversation. Full-height transcript, assistant-on-page
+ user-in-bubble, floating glass composer, streaming-style reveal, action chips,
in-conversation tool payloads (matched card / carousel / GAP card), attachment
entry, copy-message. Input focus is local and must not blank the universe.

**Specs implemented:** `INPUT_CHAT_SPEC.md` (composer, focus decoupling),
`CHAT_AI_SPEC.md` (chips, payloads, presentation).

**Files:** `UI/Search/ChatScreen.swift`, `UI/Search/SearchDock.swift`,
`UI/Search/SearchCore.swift`, `State/UniverseViewModel.swift` (`assistantMessages`,
`assistantQuery`, attachment state).

**ALREADY DONE in main / this stabilization branch:**
- `ChatScreen` full transcript + floating glass composer; assistant/user layout.
- Phase 3 motion polish: turn reveal, date separators, jump-to-latest pill
  (commit `2624035`).
- Attachment entry present in `ChatScreen` / `SearchDock`; copy-message present in
  `ChatScreen` (`UIPasteboard`).
- Attachment-only messages answered honestly (`askAssistant` U1 path,
  `UniverseViewModel.swift:256-266`).
- Copy feedback + haptic and the floating Liquid Glass attachment preview are
  on the active PR branch.
- `ComposerLogic.keepsChatActive` lets collapsed chat release map gestures while
  preserving transcript state.
- The collapsed Show Chat pill stays visible as a small resumable affordance,
  without holding the map in `.chatOpen`.

**REMAINING:**
- Attachment menu anchoring and staged attachment preview are covered by
  `UniverseUISmokeTests/testCaptureKeyStates`; real Photos/File picker payload
  preview remains out of scope for this pass.
- Verify tool-payload variants (matched-tool card ≤2 actions, 3-8 carousel, GAP
  card) all render per `CHAT_AI_SPEC.md`.
- R11: enforce a single haptic owner per tap (composer/cards) to kill duplicate
  press+action haptics.

**Done when:** composer floats in glass; focus never blanks the map; copy works;
attachment menu anchored; all payload variants render; one haptic per tap.

---

## Phase 4 — Add-tool

**Scope:** Adding a tool locally — Auto/Manual branch resolution, dirty-state
dismissal guard, and the signature "tool lands in the universe" add-flow morph
from a chat card to the Map pill.

**Specs implemented:** `ADD_TOOL_SPEC.md`.

**Files:** `UI/Settings/AddToolSheet.swift`, `State/UniverseViewModel.swift`
(add/restore tool, custom tools), `RootShell.swift` (ghost-flight to Map pill).

**ALREADY DONE in main:**
- Add-tool sheet with Auto/Manual branch mode (`ADD_TOOL_SPEC.md` behavior).
- Signature add-flow morph: chat card ghost flies to Map pill + badge tick
  (commit `2fe3180`, `RootShell` `AddFlightPayload` / `MapPillFramePreferenceKey`).

**REMAINING:**
- R17: AddTool sheet presentation → `.large` only + dirty-state dismissal guard
  (warn before discarding in-progress input).
- R18/R19 (overlaps Phase 7): after add, rebuild `planets` before camera focus so
  the new node is focusable.

**Done when:** Auto/Manual resolve correctly; sheet is `.large` with a
dirty-state guard; add-flow morph plays; new tool is immediately focusable in the
map; tests green.

---

## Phase 5 — Ask-AI intelligence

**Scope:** Answer quality and intent handling for the local assistant — grounded
in the 53-tool catalog, recommendation phrasing → domain reply, name-like
unknowns → add-tool path, cautious pricing/claims, chip match-IDs. The backend
seam (local default; DeepSeek behind a debug/dev path) is owned by
`SETTINGS_PROFILE_SPEC.md`.

**Specs implemented:** `CHAT_AI_SPEC.md`; backend-seam crossref to
`SETTINGS_PROFILE_SPEC.md`.

**Files:** `UI/Search/UniverseAssistantCore.swift`, `State/UniverseViewModel.swift`
(`askAssistant`, `appendAssistantReply`, `deepSeekSystemPrompt`),
`State/UniverseSelection.swift` (`AssistantMessage`, `AssistantReply`).

**ALREADY DONE in main:**
- R14/R15 intent: recommendation phrasing ("I need / looking for / нужен / ищу")
  → domain reply, not missing-service; name-like short unknowns → add-tool path.
- Local-first reply always computed; DeepSeek used only when configured, with
  local fallback on missing key/any error (`askAssistant` `:268-296`).
- Cautious pricing/claims copy in `UniverseAssistantCore`.

**REMAINING:**
- MUST-VALIDATE: confirm the 53-tool catalog carries JTBD-1 coverage and the
  "no good match → add the tool" path is well-handled (per handoff).
- Re-home the DeepSeek credential behind the backend seam (the *seam* work is
  specified in `SETTINGS_PROFILE_SPEC.md` §1; this phase consumes it).
- Increment the Phase-6 usage counter from `askAssistant` once that exists.

**Done when:** catalog JTBD coverage validated; no-match path adds tools cleanly;
assistant reads its backend from the seam, not "key present?"; tests green.

---

## Phase 6 — Settings / profile  ← largest net-new work

**Scope:** Make Settings honest and consumer-ready: remove the user-facing API
key, add a plan/usage/upgrade placeholder, verify the 2D/3D switch, relabel
language to "Follow device language", confirm haptics actually toggle, and
disable/remove any non-functional control. Full detail in
`SETTINGS_PROFILE_SPEC.md`.

**Specs implemented:** `SETTINGS_PROFILE_SPEC.md` (primary),
`VISUALIZATION_SPEC.md` (render-mode crossref).

**Files:** `UI/Settings/AccountSettingsSheet.swift`,
`State/UniverseViewModel.swift`, `State/UniverseSelection.swift`,
`State/UniverseStore.swift`, `Services/DeepSeekClient.swift`,
`Services/KeychainStore.swift`, `UI/Haptics/BrandHaptics.swift`.

**ALREADY DONE in main:**
- 2D Graph ⇄ 3D Spatial switch wired to `renderMode`, persisted, 3D =
  Experimental.
- Haptics toggle wired end-to-end to `BrandHaptics.isEnabled`, persisted.
- Language picker correctly disabled with "coming soon" copy.
- DeepSeek Keychain plumbing exists and is sound (just over-exposed).

**REMAINING (the bulk of new work):**
- Remove the DeepSeek API-key field from normal Settings; gate behind
  debug/developer mode; route AI via the `AssistantBackend` seam
  (`SETTINGS_PROFILE_SPEC.md` §1).
- Add placeholder `SubscriptionState` + usage counters + Upgrade CTA
  (`SETTINGS_PROFILE_SPEC.md` §2); persist via `UniverseStore`.
- Relabel `AppLanguage.system.title` → "Follow device language"
  (`SETTINGS_PROFILE_SPEC.md` §4).
- Quarantine `VisualizationStyle` as internal-only; ensure no enabled preset
  control (`SETTINGS_PROFILE_SPEC.md` §3).
- Fix the mismatched Haptics footnote copy (`SETTINGS_PROFILE_SPEC.md` §5).

**Dependencies/order:** depends on Phase 1 (shell presents Settings) and the
Phase 5 assistant seam consumer. Do the API-key removal and the
backend-seam refactor together so the assistant never loses its routing.

**Done when:** all acceptance items in `SETTINGS_PROFILE_SPEC.md` §7 pass.

---

## Phase 7 — Map interactions

**Scope:** The secondary universe mode — readable 2D/3D renderer, camera focus,
right-edge category rail, and rebuilding nodes before focusing a freshly added
tool. Readability > 3D wow.

**Specs implemented:** `UNIVERSE_MAP_SPEC.md`, `VISUALIZATION_SPEC.md`,
`RIGHT_RAIL_SPEC.md`, `DETAIL_SCREEN_SPEC.md` / `TOOL_DETAIL_SPEC.md` (tool card
opened from the map).

**Files:** `Universe/UniverseMapView.swift`, `Universe/UniverseGraphView.swift`,
`Universe/UniverseRealityView.swift`, `Universe/UniverseSceneController.swift`,
`Universe/CameraRigController.swift`, `Universe/RightUniverseRail.swift`,
`Universe/UniverseOverlayView.swift`, `Universe/PlanetInfoCard.swift`,
`UI/Sheets/ToolDetailSection.swift`.

**ALREADY DONE in main:**
- 2D/3D renderers behind `renderMode`; render-mode chip in the HUD opens Settings.
- R6 label-culling (non-focused labels hidden, only node circles must not
  overlap); R21 rail scrim constrained to a 220pt strip.
- R22 Dynamic Type in `ToolDetailSection` / `PlanetInfoCard`.
- Detail sheet dismisses when `universeMode` leaves the detail state (R5).

**REMAINING:**
- R18: core-satellite camera focus framing in 3D.
- R19: rebuild `planets` before focus after a tool is added (so the new node is
  targetable) — pairs with Phase 4.
- Edge-only rail discipline per `RIGHT_RAIL_SPEC.md` (must not become a panel).

**Done when:** both renderers readable; camera focuses core-satellite cleanly;
newly added tool is focusable; rail stays edge-only; detail card opens/dismisses
per spec; tests green.

---

## Already-done vs remaining — summary

| Phase | Already done in main | Remaining |
| --- | --- | --- |
| 1 First-run + nav | Map-first `RootShell`, Ask AI route, Map return, first-run overlay/empty-state, collapse releases map gestures | Reconfirm focus-doesn't-blank on every composer change |
| 2 Visual system | Real `glassEffect` `glassSurface` 3-tier + fallbacks, tokens, chrome migration, snapshot tests, navigation morph IDs | R9 reduce-motion call sites; over-glass audit |
| 3 Chat/input/attach/copy | `ChatScreen` transcript + glass composer, turn reveal/date sep/jump pill, attachments, copy feedback, floating attachment preview, attachment-only honesty | Payload-variant verify; R11 single haptic owner; real file/photo payload preview out of scope |
| 4 Add-tool | Auto/Manual branch, signature add-flow morph to Map pill | R17 `.large` + dirty-state guard; rebuild nodes before focus |
| 5 Ask-AI intelligence | R14/R15 intent, local-first + DeepSeek fallback seam, cautious claims | JTBD-1 catalog validation; consume backend seam; usage increment |
| 6 Settings/profile | 2D/3D switch, haptics toggle, disabled language picker, Keychain plumbing | Remove user API key (debug-gate); plan/usage/upgrade placeholder; "Follow device language"; quarantine `VisualizationStyle`; haptics footnote fix |
| 7 Map interactions | 2D/3D renderers, label-culling, rail scrim, Dynamic Type, detail dismissal | R18 camera focus; R19 rebuild-before-focus; edge-only rail discipline |

Net: the IA, glass foundation, chat surface, and most polish are **done on
main**. The genuinely remaining work is **Phase 6 settings/profile** (mostly
net-new) plus the polish tails of phases 4, 5, and 7.
