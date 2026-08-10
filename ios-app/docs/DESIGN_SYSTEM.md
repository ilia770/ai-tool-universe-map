# DESIGN_SYSTEM — Reconstructed current visual language

This describes implemented visual primitives, not a redesign prescription. The
app is dark, native iOS, cosmic, and glass-chrome-led. Source of truth is the
named token/component code below; repeated literals are documented rather than
normalized during this documentation task.

**Architecture links:** `UI_APPLE_NATIVE_SPEC.md` owns permanent implementation
rules. Use `UI_MOTION_TOKENS.md`, `UI_LAYOUT_SYSTEM.md`, `UI_TYPOGRAPHY.md`,
and `UI_ACCESSIBILITY.md` for cross-cutting contracts; this document remains
the current visual-primitives baseline.

## Confirmed reusable tokens

| Concern | Owner | Implemented values / behavior |
| --- | --- | --- |
| Palette | `UI/Theme/BrandColor.swift` | near-black `void`; core cyan; category accents; neutral glass/card/stroke/text colors. |
| Spacing | `BrandSpacing.swift` | 2, 4, 8, 10, 12, 16, 20, 24, 32 point named scale. |
| Radius | `BrandRadius.swift` | pill, node/tight/nested/card, glass-control/button, bubble, prompt/reveal/floating card, graph-label, and sheet values. |
| Type | `BrandTypography.swift` | Dynamic-Type-aware SF default family is predominant for chrome/reading/graph; rounded type also appears in onboarding/empty-state and selected chat/rail labels. |
| Motion | `BrandMotion.swift` | entry/nudge/press/flow/breath/stream/cursor/thinking/reveal/morph/pill-pop/composer-grow; static policy checks Reduce Motion and `-uitestStatic`. |
| Hit areas | `UI/Effects/HitArea.swift` | shared minimum target helper used by selected controls. |
| Haptics | `UI/Haptics/BrandHaptics.swift`, `CoreHapticsEngine.swift` | central named haptic calls, gated by persisted setting with UIKit fallback. |

## Surface hierarchy

1. **Canvas/content:** `BrandColor.void`, current constellation nodes/edges, or
   full chat background. Map nodes are content, not generic glass cards.
2. **Floating navigation/control chrome:** `glassSurface` / Liquid Glass
   controls — root surface switch, composer, toolbar controls, transient pills.
3. **Reading surfaces:** neutral card/material treatments — tool detail,
   transcript/bubbles, sheets. They should not compete with the chrome layer.
4. **Accent:** category/core color for selection, tiny signal dots, selected
   node rings, and primary action emphasis; it is not a universal panel fill.

`UI/Effects/LiquidGlass.swift` implements the actual fallback sequence:

- Reduce Transparency: opaque `BrandColor.glassSolid` with optional tint;
- iOS 26+: native `glassEffect`, optionally interactive;
- iOS 18–25: `.ultraThinMaterial` plus one hairline.

## Component system

| Component / pattern | Current use | Ownership notes |
| --- | --- | --- |
| `GlassMorphCluster` | root Map/Ask AI switch and segmented choices | selected control gets one travelling glass identity; iOS 18–25 uses matched geometry. |
| `LiquidGlassButton/Card/Pill/Input/Sheet/Toast` | common floating controls and wrappers | consume Brand tokens but do not own feature behavior. |
| `PressableButtonStyle`, `GlassControlButtonStyle` | map nodes, controls, shared glass | motion-aware press feedback; avoid stacking a second scale animation. |
| `RootShell` ghost flights | chat-card-to-map/tool visual handoff | decorative, local, and Reduce Motion guarded. |
| `UniverseConstellationView` | 2D branch/tool graph | neutral node fills plus restrained category overlay/rings; stable AX IDs. |
| `ToolDetailSection`, `SearchDock`, `ChatScreen` | content/reading surfaces | each has feature-local layout, local state, and some raw values. |

## Typography, layout, and accessibility

- **CONFIRMED:** shared type tokens use semantic Dynamic Type styles, though
  some feature code still uses fixed system sizes (for example rail items and
  visual icons). The active 2D graph caps node labels at `.xxxLarge`.
- **CONFIRMED:** the app forces a dark color scheme in boot and target config.
- **CONFIRMED:** Liquid Glass respects Reduce Transparency and shared motion
  helpers honor Reduce Motion/static UI tests.
- **REQUIRES RUNTIME VERIFICATION:** Dynamic Type at accessibility sizes,
  VoiceOver navigation of all current live surfaces, high contrast behavior,
  physical-device glass response, and haptic feel.

## Implemented animation and shared identities

| Transition / identity | Evidence | Status |
| --- | --- | --- |
| Root Map ↔ Ask AI | `RootShell.surfaceNamespace`, `diveTransition` | **CONFIRMED** root route transition. |
| Account/Add Tool → sheet | `ChromeMorphID`, `matchedTransitionSource`, `.navigationTransition(.zoom)` | **CONFIRMED** availability-dependent source/destination pairing. |
| Collapse Chat ↔ Show chat | `SearchDock.chatChromeNamespace`, `navigationGlassMorphID` | **CONFIRMED** within dock; transcript remains local-memory only. |
| Selected segment travel | `GlassMorphCluster` | **CONFIRMED** native glass ID on iOS 26, matched geometry fallback. |
| Card-to-map/tool ghost | `RootShell` geometry preferences/ghost state | **CONFIRMED** only when anchors exist and motion is allowed. |
| Map 2D layout changes | `UniverseConstellationView` `BrandMotion.morph` | **CONFIRMED** current source. |
| Camera fly/3D gestures | retained camera/spatial files | **LEGACY/EXPERIMENTAL:** not mounted in current renderer. |

## Repeated values and inconsistencies — document, do not “fix” blindly

- `ChatTheme` has its own raw RGB palette rather than consuming all BrandColor
  surface tokens.
- Several feature views retain inline opacity, shadow, radius, and fixed-font
  values despite token guidance.
- Some imperative animations use `withAnimation(BrandMotion.flow)` directly
  rather than the wrapper that resolves Reduce Motion.
- Content-vs-glass policy has intentional/legacy exceptions in cards and
  sheets. A future cleanup needs a visual regression task, not a refactor
  folded into feature work.

## Directional guardrails

Keep the interface native and premium iOS: default SF typography, system
materials/glass, familiar sheet behavior, restrained chrome, and clear
hierarchy. Do not import Material Design, web-dashboard cards, heavy outlines,
or a locally invented design system into a feature. A visual change must name
its relevant token/component and test on compact and regular layouts.
