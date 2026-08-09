# iOS Design-System Rubric

Extracted 2026-07-06 by the design-audit workflow from Brand* tokens + LIQUID_GLASS_VISUAL_SPEC. The canonical checklist for UI reviews.

iOS DESIGN-SYSTEM AUDIT RUBRIC — My AI Map (source: BrandSpacing/Radius/Typography/Color/Motion.swift, LIQUID_GLASS_VISUAL_SPEC.md, Components/Glass/*). Numbers are exact; cite deviations against these.

(1) SPACING — BrandSpacing (4pt base grid; `sm=10` is the single named compact-control exception; token=value → intended use). Un-tokenized off-grid padding is a violation.
hair=2 dense-row hairline · xs=4 chip inner gap · s=8 chip↔chip / icon↔label · sm=10 compact control vertical rhythm (composer/card/notice insets) · m=12 card inner padding · l=16 sheet inner padding / default safe-area gap · xl=20 between detent stops · xxl=24 top-level sheet padding · section=32 between major sheet sections.

(2) RADIUS — BrandRadius (token=value → use). Inline radii are a violation.
pill=999 chips/drag-handle · tight=6 segmented chips/picker dots · node=8 inline tool-row buttons · graphLabel=9 2D node label pill · nested=12 nested glass surfaces · promptCard=14 chat starter card · glassButton=16 glass icon-button · card=18 tool-detail card / sheet top · bubble=20 chat bubbles + floating notices/popovers · glassControl=22 composer pill · revealCard=26 3D tool-summary card · floatingCard=28 empty-state/onboarding card · sheetPresentation=42 system sheet corner.

(3) TYPE — BrandTypography (SF system `.default` unless noted; Dynamic Type, no fixed `.system(size:)`).
displayLarge=largeTitle/semibold · display=title/semibold · emptyStateDisplay=title/semibold/**rounded** (friendly onboarding/empty state only) · title=title3/semibold · body=body · bodySecondary=callout · controlLabel=subheadline/semibold (buttons/pills/tabs) · chip=footnote/semibold · graphLabel=caption/medium · graphLabelFocused=footnote/semibold · graphToolLabel=caption2/medium · graphMetadata=caption2/regular · graphCoreLabel=subheadline/semibold · eyebrow=caption2/semibold → must use `.brandEyebrow()` (adds kerning 1.8 + uppercase) · mono=callout/monospaced (%/counters).

(4) GLASS — single entry `glassSurface(in:tint:interactive:)`; NEVER call `.glassEffect` directly, NEVER nest glassSurface (no double-lensing). Blur = system glass / `.ultraThinMaterial` (no numeric radius). iOS26: native glass owns its edge → NO manual stroke/clip on top. iOS18-25 fallback: `.ultraThinMaterial` + 0.5pt `BrandColor.stroke`. ReduceTransparency: opaque `glassSolid` (+tint 0.22 if tinted). Tint optional, ≤0.12 alpha, never a saturated fill. Strokes: stroke=white 0.10 (only hairline), strokeStrong=white 0.18 (primary-button overlay only). Neutral fills: card=white 0.06, muted=white 0.035; chip idle white 0.05–0.08, chip active white 0.12 or ≤0.12 accent whisper. Shadows (one per layer): card/panel = black 0.30–0.34 / r16 / y8; input = black 0.26 / r14 / y8.
SANCTIONED primitive per role (flag bespoke re-implementations):
- Card / reading surface → `LiquidGlassCard` (default r=floatingCard 28; tool-detail r=card 18)
- Labeled floating CTA → `LiquidGlassButton` (Capsule, native-interactive glass, `GlassControlButtonStyle`; 0.97 fallback on iOS 18–25; ≥44pt hit target)
- Pill / HUD / mode switch → `LiquidGlassPill` (Capsule, interactive)
- Composer/input → `.liquidGlassInput()` (Capsule + shadow 0.26/14/8, NO tint, NO backing plate)
- Full sheet → `.liquidGlassSheet()` (`.large` detent + drag indicator + 42pt corner)
- Toast → `LiquidGlassToast` (Capsule, tint core 0.10)
- Inline action chip → `.actionChipBackground()` (`BrandColor.card` + `BrandColor.stroke` hairline, pad 12/8, ≥44pt hit target)
- Tool/source chip → `ToolChip` (shared action-chip chrome; accent only on logo, ≥44pt hit target)
- Primary action (Send/Add) → filled `Circle` in accent, black glyph, white 0.18 overlay, accent shadow; disabled = white 0.08 fill + white 0.34 glyph (no color).

(5) HARD RULES (cite violations)
- No inline `.padding(<number>)` off the 4pt base grid → use BrandSpacing. The named `sm=10` token is the only compact-control exception; raw `11/7/6/+1/+2` adjustments are violations.
- No inline corner radii → add/use a BrandRadius token.
- No inline hex/`Color(...)`/opacity-fill → go through BrandColor.
- Min 44pt touch target on every tappable control.
- Gaps between peer controls use ONE spacing token consistently (no mixing s/sm/m in one row).
- Accent is active-state / tiny-highlight ONLY (send active, focused caret tint, selected-chip label/icon, status dot). No brand/category color >~0.12 alpha as a `.background` fill; no accent-tinted content surface; no accent capsule fill (the old `accent.opacity(0.24–0.50)` pattern).
- No bespoke glass: hand-rolled `.glassEffect`, raw `.ultraThinMaterial`, manual stroke-on-glass, or a second border/black backing plate = violation; use the role primitive.
- Motion via `BrandMotion.*` only (entry/nudge/press/flow/breath/stream/cursor/thinking/reveal/morph/pillPop/composerGrow). Direct press feedback uses high-damped `press`; native interactive glass owns its own scale and must not be stacked with a custom `.scaleEffect`. Repeating curves (breath/cursor/thinking) MUST be gated behind Reduce Motion via `BrandMotion.resolved` / `withBrandAnimation` / `.brandAnimation`; bare `withAnimation(BrandMotion.*)` bypasses the resolver = violation. `-uitestStatic` follows the same motion-disabled path, including native interactive glass.

Source paths: /Users/ilia882/Code/ai-tool-universe-map/ios-app/Sources/MyAIMap/UI/Theme/Brand*.swift · /ios-app/Sources/MyAIMap/UI/Effects/LiquidGlass.swift · /ios-app/Sources/MyAIMap/UI/Components/Glass/LiquidGlass*.swift + ActionChip.swift/ToolChip.swift · /ios-app/docs/LIQUID_GLASS_VISUAL_SPEC.md
