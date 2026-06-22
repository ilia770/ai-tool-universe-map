# Handoff — Chat-first + Liquid Glass redesign (for Codex)

Date: 2026-06-22 · Branch: `feat/redesign-chatgpt-liquid-glass` · Worktree: `/Users/ilia882/Code/render-modes-wt`
HEAD: `389f443` · 37 commits over `origin/main` · **221 tests / 25 suites green** · No PR to main yet.

## TL;DR
The DESIGN + FOUNDATION are done; the actual chat-first UI is NOT. App still launches into the universe, not a ChatGPT-style chat. Phase 0 is complete. **Next big work = Phase 2 (chat-first RootShell/ChatScreen).**

## Build / test gate (use this — it actually runs assertions)
```
bash scripts/ios-verify.sh --run-tests --device-id EAC2C682-5C38-44DB-8FEC-034E296E8EEA
```
Runs xcodegen → build → `xcodebuild test` (xcresult), reports passed count. (`--test-build-only` only compiles; `npm run ios:test` is the same gate.) Sim = iPhone 17 Pro `EAC2C682-5C38-44DB-8FEC-034E296E8EEA`. NOTE: new test files need xcodegen → always go through this script, not bare `xcodebuild`.

## Spec / planning docs (read before implementing)
- `docs/superpowers/specs/2026-06-21-chatgpt-liquid-glass-design-direction.md` — the product+UX direction (chat = front door, universe = artifact it builds; morph-switch NOT TabView; assistant-on-page; HIG glass MAP; tool card/carousel/GAP payloads; 3 signature morph moments).
- `docs/superpowers/specs/2026-06-21-motion-haptics-microinteraction-spec.md` — motion tokens + haptic vocabulary + add-flow sequencing.
- `docs/superpowers/plans/2026-06-21-chatgpt-liquid-glass-redesign-plan.md` — 6-phase plan.
- `docs/reviews/2026-06-21-liquid-glass-redesign-multi-agent-sweep.md` — backlog R1-R22, Phase-0 gates, file ownership, fix tickets, recommended order. THE checklist.

## DONE (Phase 0 + stabilization, all merged on this branch)
- **R1/R2** `glassSurface(in:tint:interactive:)` 3-tier (ReduceTransparency→opaque `BrandColor.glassSolid`; iOS26→native `glassEffect` no manual stroke/clip; iOS18-25→material+hairline); `interactive` default false; `liquidGlass(...)` = non-interactive shim. Tokens: `BrandColor.glassSolid`, `BrandRadius.glassControl/.glassButton`, 7 `BrandMotion` tokens (stream/cursor/thinking/reveal/morph/pillPop/composerGrow) + `withBrandAnimation`. Fixed invalid Swift in specs.
- **R3** real test gate (`--run-tests`) + CI unit job.
- **R4** `ChromeSnapshotTests` (ImageRenderer, normal + `_accessibilityReduceTransparency`).
- **R5** detail sheet dismisses when `universeMode` leaves `.detail`.
- **R6** 2D label-culling: non-focused tool labels hidden → only node circles must be non-overlapping (tests 320/393/744).
- **R7** glass allowlist migration: SearchDock/CategoryRail/AddTool/AccountSettings/PlanetInfoCard — controls→`glassSurface(interactive:true)`/`GlassEffectContainer`, content→solid, nested glass removed.
- **R8+R10** haptics: CH lazy-restart; `brandSensoryFeedback`/`glassPressFeedback` (PressBounce) gated on hapticsEnabled; `CoreHapticsEngine.Pattern.toolLand` + `ticker(count:)`.
- **R14/R15** assistant intent: recommendation phrasing (I need/looking for/нужен/ищу…) → domain reply not missing-service; name-like short unknowns → add-tool path.
- **R20** iOS seed documented as fork (9 cat/53 tools) + `UniverseSeedParityTests`.
- **R21** right-rail scrim constrained to 220pt strip (was full-screen).
- **DeepSeek backend** (user feature): `Services/DeepSeekClient.swift` (OpenAI-compatible, `deepseek-chat`, Bearer) + `Services/KeychainStore.swift`. User enters key in AccountSettings → Settings tab → "AI assistant" SecureField. `UniverseViewModel.askAssistant` uses DeepSeek when key present, **falls back to local `UniverseAssistantCore` on missing key/any error** (local stays default/offline). KEY: Keychain only, never committed/logged.

## NOT DONE — pick up here

### Phase 2 — chat-first IA (the headline; app does not look like ChatGPT yet)
Build per the design direction:
- New `RootShell` replacing `UniverseMapView` as `WindowGroup` content (`MyAIMapApp.swift`).
- `ChatScreen` = primary (promote the `SearchDock` assistant to a full-height transcript + floating glass composer; assistant-on-page, user in bubble; warm reading surface; SF Pro Text; single `core` accent).
- `UniverseScreen` = secondary mode (existing `UniverseMapView`, renderers untouched).
- Morph-switch chat⇄universe (`glassEffectID`+`@Namespace`, `.navigationTransition(.zoom)`), NOT TabView. Cold start = Chat. Map pill w/ live count badge. Bi-directional chat↔universe linking.
- First-run = starter chips firing real recommendations; never show empty universe; gate universe until ≥3 nodes.
- Tool payloads in-conversation: matched-tool card (≤2 actions), carousel (3-8), GAP card.
- MUST-VALIDATE first: the 53-tool catalog must carry JTBD-1; design the "no good match → add the tool" path well.

### Remaining backlog tickets (review report)
- **R9** direct `withAnimation(BrandMotion.*)` bypasses reduce-motion → use `withBrandAnimation` (already added) at call sites (SearchDock/UniverseMapView — hot).
- **R11** duplicate press+action haptics per tap (SearchDock/PlanetInfoCard/UniverseMapView) — enforce one haptic owner.
- **R12** root route owner for chat-first (folds into Phase 2 RootShell).
- **R13** first-run chat starter data source vs empty map.
- **R16** attachment menu → anchored overlay (SearchDock).
- **R17** AddTool sheet → `.large` only + dirty-state dismissal guard.
- **R18/R19** 3D: core-satellite camera focus; rebuild `planets` before focus after add (UniverseMapView/SceneController).
- **R22** Dynamic Type vs fixed typography (BrandTypography/ToolDetailSection/PlanetInfoCard).

## Coordination rules (learned the hard way)
- Two agents (Claude + Codex) on this branch → NEVER both edit the same file on the shared worktree at once; it silently clobbers.
- Working pattern: worktree-isolated subagents on DISJOINT file sets, each builds via the gate FOREGROUND (synchronous — do NOT background the build + "wait"; that hangs), each pushes its own branch; integrator merges (disjoint files = clean merges).
- After any merge, run the gate once and push.

## Loose ends (non-redesign)
- PR for this branch → main: none yet.
- PR #98 (product-v2 2D/3D toggle → main): still open.
- TestFlight build 4: VALID on App Store Connect, not assigned to internal testing yet.
