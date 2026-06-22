# Redesign Plan — ChatGPT-style chat-first IA + Apple Liquid Glass

Date: 2026-06-21 · Branch base: `feat/cell-universe-spritekit` (PR #98) · Target: iOS 26

## Goal

Two coordinated shifts, approved scope = **both**:
1. **Chat-first IA** — the AI assistant conversation becomes the primary screen
   (ChatGPT model: full-height transcript, history, bottom composer). The
   cosmic universe (2D/3D) becomes a secondary mode the user opens from chat.
2. **Apple Liquid Glass visual system** — one coherent iOS 26 Liquid Glass
   design language across all chrome, replacing the ad-hoc `LiquidGlass.swift`
   approximations with the real `glassEffect` APIs, with a clean ChatGPT-grade
   minimalist layout/typography.

Non-goal: changing the universe *concept* or the tool data model.

## Design principles

- **ChatGPT taste:** content-first, generous whitespace, one accent, restrained
  type scale, conversation is the hero, controls recede until needed.
- **Apple Liquid Glass (HIG):** glass is for the *navigation/control layer that
  floats above content* — NOT for content surfaces or backgrounds. Do not glass
  everything; over-glassing is the #1 HIG violation. Content (chat bubbles,
  cards) stays on solid/material surfaces; glass goes on the floating composer,
  tab bar, toolbars, FABs, and the universe HUD.
- **Depth, not chrome:** rely on Liquid Glass's built-in lensing/refraction +
  `scrollEdgeEffectStyle`; drop manual gradients/strokes where glass replaces
  them.

## Real Liquid Glass API surface (iOS 26, via context7 / SwiftUI)

- `.glassEffect(_ glass: Glass = .regular, in: some Shape = .rect)` (no `isEnabled:` — branch outside the call; review finding R2)
- `Glass.regular` / `.clear` / `.identity`; `.tint(_:)`; `.interactive()`
- `GlassEffectContainer(spacing:)` — groups nearby glass elements so they blend
- `.glassEffectID(_:in:)` + `@Namespace` — morph transitions between glass shapes
- `.buttonStyle(.glass)` (and `.glassProminent`)
- `.scrollEdgeEffectStyle(_:for:)` — scroll-edge glass treatment
- `.backgroundExtensionEffect()` — edge-extending blurred background
- All gated `if #available(iOS 26, *)` with non-glass `.ultraThinMaterial`
  fallback; honor `accessibilityReduceTransparency` (fall back to opaque).

## Architecture changes

### A. New information architecture (chat-first)
- New root `RootShell` replacing `UniverseMapView` as the `WindowGroup` content.
  - **Primary: `ChatScreen`** — full-screen conversation (transcript +
    bottom Liquid Glass composer), ChatGPT layout. Promotes today's `SearchDock`
    assistant from a docked overlay to the main surface.
  - **Secondary: `UniverseScreen`** — the existing `UniverseMapView` (2D/3D
    renderers untouched) presented as a mode the user opens from chat (e.g. a
    "View universe" affordance / segmented switch), not the default screen.
  - Navigation: a single Liquid Glass **bottom bar / segmented control**
    (`GlassEffectContainer`) toggling Chat ⇄ Universe; Settings as a glass
    toolbar button. (Decide TabView vs custom morph switch in Phase 2.)
- Keep `UniverseViewModel` as the single source of truth; chat + universe both
  read it. Assistant messages already live there.

### B. Liquid Glass design system
- Rework `UI/Effects/LiquidGlass.swift` → a thin, real wrapper:
  `glassSurface(in:tint:interactive:)` delegating to `.glassEffect` on iOS 26,
  `.ultraThinMaterial` + stroke fallback otherwise + reduce-transparency path.
  Migrate every `.liquidGlass(...)` call site to it (ToolDetailSection,
  SearchDock, CategoryRail, AddTool, AccountSettings).
- Extend `Brand*` tokens for the ChatGPT aesthetic: a neutral surface ramp,
  one accent, a tightened type scale in `BrandTypography`, glass corner radii
  in `BrandRadius`. Keep `BrandMotion` for `.smooth` glass morphs.

## Phased build (each phase: build + 182 tests green, then a sim screenshot)

**Phase 0 — Design system foundation** (no IA change yet)
- Rewrite `LiquidGlass.swift` to the real `glassEffect` API + fallbacks;
  add `glassSurface` helper. Tune `Brand*` tokens (neutral ramp, type scale).
- verify: build green; screenshot one existing sheet showing real glass.

**Phase 1 — Glass the existing chrome** (still universe-first)
- Migrate composer (`SearchDock`), `ToolDetailSection`, `CategoryRail`,
  `AccountSettingsSheet`, `AddToolSheet`, universe HUD pill to `glassSurface` /
  `.buttonStyle(.glass)`; add `.scrollEdgeEffectStyle` to scroll views.
- verify: screenshots of detail, settings, add-tool, dock in glass.

**Phase 2 — Chat-first IA**
- Build `RootShell` + `ChatScreen` (promote assistant to full screen) +
  glass bottom Chat⇄Universe switch (GlassEffectContainer). Repoint
  `MyAIMapApp` to `RootShell`. Universe becomes secondary mode.
- verify: launch lands on chat; switching to universe works; smoke test green.

**Phase 3 — ChatGPT-grade chat polish**
- Bubble layout, streaming-style reveal, action chips, missing-tool suggestion
  cards, empty-state — all on solid surfaces with the glass composer floating.
- verify: chat screenshots vs ChatGPT reference; reduce-transparency pass.

**Phase 4 — Morph + motion**
- `glassEffectID`/`@Namespace` morphing: composer ↔ expanded, chat ↔ universe
  transition, tool chip → detail. `.smooth` animations.
- verify: visual QA of transitions; perf check (no per-frame glass thrash).

**Phase 5 — A11y + fallback hardening**
- Verify reduce-transparency, reduce-motion, Dynamic Type, VoiceOver across all
  screens; confirm iOS-25 fallback path compiles/renders.
- verify: a11y audit pass; full `ios-verify --full-test`.

## Risks / constraints
- **Don't over-glass** (HIG): content surfaces stay material/solid; glass only
  on floating nav/controls. Bake this into `glassSurface` usage review.
- **iOS 26 availability:** every glass call needs `#available` + fallback; CI
  builds on Xcode 26 (already configured).
- **Perf:** `GlassEffectContainer` groups are cheap, but avoid recomputing glass
  in animation loops; keep the 2D layout perf fix (outstanding) in mind.
- **Universe demotion is a product change** — confirm discoverability of the
  universe from chat before shipping.
- **Reduce-transparency** must yield a fully opaque, legible UI.

## Out of scope
- 2D SpriteKit cell redesign (separate spec `2026-06-21-cell-universe-2d-spritekit-design.md`).
- Outstanding bug-review fixes (#1/#4/#5 etc.) — land independently.
- Web (`src/`) redesign.

## Decisions still open (resolve at Phase 2)
- TabView vs custom morphing Chat⇄Universe switch.
- Does Settings stay a sheet, or become a chat-side panel?
- Default screen on cold start = Chat (assumed) vs last-used mode.
