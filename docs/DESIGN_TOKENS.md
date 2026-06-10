# Design tokens — My AI Map iOS

Single source of truth for colours, typography, spacing, motion,
haptics, and elevation across the SwiftUI app. Phase 1 already lands
the rough surfaces; Phase 2 and later pin them to these constants.

The whole point of fixing tokens before more UI lands: a polished iOS
app distinguishes itself from a web port through *consistency*. ChatGPT
on iOS, Apple Maps, Linear, and Things 3 all read as premium because
every gap, corner radius, and animation curve repeats. Match that.

## Brand palette

| Token | Hex | Use |
| --- | --- | --- |
| `BrandCore` | `#9BE8FF` | Core / Founder OS glow, accent on selected node. Also `AccentColor`. |
| `BrandCyan` | `#22D3EE` | Distribution / Social category. |
| `BrandViolet` | `#5D59FF` | Coding category. |
| `BrandPink` | `#EC4899` | Design category. |
| `BrandTeal` | `#14B8A6` | Research category. |
| `BrandOrange` | `#F97316` | Media category. |
| `BrandLime` | `#A3E635` | Infrastructure / Runtime category. |
| `BrandAmber` | `#FACC15` | Knowledge / Skills category. |
| `BrandWhite` | `#FFFFFF` | Core node, primary text on dark. |

Map these to a single Swift enum in
`ios-app/Sources/MyAIMap/UI/Theme/BrandColor.swift`. Use
`Color(uiColor: UIColor(...))` so values survive Dark / Light Mode
overrides cleanly.

## Surface palette (dark only — light mode deferred to Phase 3)

| Token | Hex / RGBA | Use |
| --- | --- | --- |
| `SurfaceVoid` | `#03040A` | Background behind the RealityKit canvas. |
| `SurfaceGlass` | `rgba(5, 8, 20, 0.76)` | Bottom-sheet glass background. |
| `SurfaceCard` | `rgba(255, 255, 255, 0.06)` | Selected-tool card. |
| `SurfaceMuted` | `rgba(255, 255, 255, 0.035)` | Inactive chips. |
| `SurfaceStroke` | `rgba(255, 255, 255, 0.10)` | Default 1 px hairline. |
| `SurfaceStrokeStrong` | `rgba(255, 255, 255, 0.18)` | Sheet edges, focused inputs. |

## Typography

We do **not** ship a custom font in Phase 0–2. Use SF Pro Display and
Dynamic Type so accessibility settings keep working.

| Token | Style |
| --- | --- |
| `display` | `.system(size: 28, weight: .semibold)` — sheet titles. |
| `title` | `.system(.title3, design: .default, weight: .semibold)` — section headers. |
| `body` | `.system(.body, design: .default)` — descriptions. |
| `chip` | `.system(.footnote, design: .default, weight: .semibold)` — category chips. |
| `eyebrow` | `.system(size: 10, weight: .semibold).tracking(0.18 * 10)` — uppercase kicker. |
| `mono` | `.system(.callout, design: .monospaced)` — confidence / counts. |

Always pair `font` with `lineSpacing` so multi-line copy doesn't
collapse. Rule of thumb: `lineSpacing = ceil(font.size * 0.25)`.

## Spacing scale

Multiples of 4. Reject ad-hoc gaps.

| Token | Value | Use |
| --- | --- | --- |
| `xs` | 4 | Inside-chip gap. |
| `s` | 8 | Between chips. |
| `m` | 12 | Card inner padding. |
| `l` | 16 | Sheet inner padding. |
| `xl` | 24 | Sheet detent gap. |
| `xxl` | 32 | Top-level sheet padding. |

## Corner radii

| Token | Value | Use |
| --- | --- | --- |
| `pill` | 999 | Chips, the lens-bar drag handle. |
| `card` | 18 | Tool detail card, top of bottom sheet. |
| `node` | 8 | Inline tool-row buttons inside the lens panel. |

## Elevation

iOS doesn't expose Material You — fake elevation with two shadows
plus an inner stroke:

```swift
.shadow(color: .black.opacity(0.45), radius: 30, x: 0, y: 18)
.shadow(color: .black.opacity(0.30), radius: 8,  x: 0, y: 4)
.overlay(
    RoundedRectangle(cornerRadius: BrandRadius.card.value)
        .stroke(BrandColor.surfaceStrokeStrong, lineWidth: 1)
)
```

Apply this combo only to the bottom sheet + the selected-tool card —
not to every surface. Tone competes for attention.

## Motion

Animation curves, written as Swift `Animation` cases. Match the web
build's intent (the Bezier in `tool-detail-slide` was
`cubic-bezier(0.16, 1, 0.3, 1)` — Swift's `.spring` reads cleaner
once you accept the analog).

| Token | Curve | Use |
| --- | --- | --- |
| `entry` | `.spring(response: 0.42, dampingFraction: 0.85)` | Sheet, modal, tool card. |
| `nudge` | `.spring(response: 0.28, dampingFraction: 0.72)` | Button taps, chip selection. |
| `flow` | `.smooth(duration: 0.36)` | Camera focus moves. |
| `breath` | `.easeInOut(duration: 4.0).repeatForever(autoreverses: true)` | Ambient glow loops. |

Disable transitions when `UIAccessibility.isReduceMotionEnabled` is
true — read it from `@Environment(\.accessibilityReduceMotion)`.

## Haptics

iPhone-only — guard with `#if os(iOS)`.

| Token | Generator | Use |
| --- | --- | --- |
| `light` | `UIImpactFeedbackGenerator(style: .soft).impactOccurred()` | Tool tap, chip select. |
| `medium` | `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` | Pocket open. |
| `success` | `UINotificationFeedbackGenerator().notificationOccurred(.success)` | Successful classify. |
| `warning` | `UINotificationFeedbackGenerator().notificationOccurred(.warning)` | JSON import rejected. |

Pre-warm a generator before the gesture starts (`.prepare()`),
otherwise the first tap arrives ~50 ms late.

## Iconography

Use **SF Symbols 6** exclusively in Phase 0–3. No custom icon
font, no SVG imports. SF Symbols handle Dynamic Type and weight
automatically and feel native by default. Phase 4 considers a
custom brand mark for App Store and the watch face.

| Surface | Symbol |
| --- | --- |
| Search field | `magnifyingglass` |
| Intake CTA | `wand.and.stars` |
| Reset view | `arrow.counterclockwise` |
| Clarity menu | `viewfinder` |
| Founder OS | `circle.hexagonpath.fill` |

## Layout invariants

1. Safe-area aware on every screen. No content under the home
   indicator or notch.
2. iPhone: portrait by default; landscape allowed but the sheet
   collapses to compact.
3. iPad: side rail instead of bottom sheet (see
   `DESIGN_PATTERNS.md` § "Adaptive layout").
4. Status bar is `.lightContent` everywhere — the cosmic
   background is always dark.

## Where this lives in code

Phase 2 lands a single Swift file:

```
ios-app/Sources/MyAIMap/UI/Theme/
  BrandColor.swift
  BrandRadius.swift
  BrandSpacing.swift
  BrandMotion.swift
  BrandHaptics.swift
  BrandTypography.swift
```

Importing one of these is allowed in any view. Defining a new
colour, gap, radius, or animation curve inline is **not allowed**;
add a token first.
