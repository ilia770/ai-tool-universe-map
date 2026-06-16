# Reference: Liquid Glass / visionOS / iOS 18–26

Design research for the liquid-glass "AI tool universe" app. Goal: glass that feels **premium and crisp**, not muddy/glassmorphism-soup. Web prototype is React 19 + R3F + Tailwind 4, so all Apple APIs below are translated into **web-adoptable** terms (CSS `backdrop-filter`, gradients, springs).

> Mobbin MCP was paywalled at research time. Sources are Apple's iOS 26 Liquid Glass system (HIG/WWDC25 "Get to know the new design system"), the conor.fyi Liquid Glass reference, and corroborating dev writeups. Links at bottom.

---

## 1. The core mental model: lensing, not blur

The single most important premium signal. Old glassmorphism = **scatter** (a soft, diffuse, frosted smear — what cheap "glass" looks like). Apple Liquid Glass = **lensing**: it *bends and concentrates* background light the way curved physical glass does, then adds a thin bright **specular rim** that reacts to motion/tilt.

Adopt for web:
- Don't ship plain `backdrop-filter: blur(20px)` alone — that's the muddy look. Layer **three things** on every glass surface:
  1. **Refraction/blur**: `backdrop-filter: blur(16–24px) saturate(160–180%)`. The `saturate` boost is what makes pulled-through color feel *lit* rather than grey. This is non-negotiable for "premium not muddy."
  2. **Specular edge**: a 1px inner highlight on the top/left rim. `box-shadow: inset 0 1px 0 rgba(255,255,255,.35)` + a faint inset bottom shadow `inset 0 -1px 0 rgba(0,0,0,.12)`. Optionally a `border` of `1px solid rgba(255,255,255,.18)`.
  3. **Tint/fill**: a translucent fill *on top of* the blur, not instead of it. Regular glass ≈ **40–60% effective opacity**; clear glass ≈ **10–20% fill** (very transparent).
- For our 3D universe (R3F), the canvas behind the glass IS the busy media — so glass over the graph should lean toward **clear + dimming layer** (see §4), while glass over flat UI (lists, detail body) uses **regular**.

## 2. Two variants — pick deliberately, never mix randomly

| Variant | Effective opacity | Use when | In our app |
|---|---|---|---|
| **Regular** | ~40–60% (adaptive) | The default. Toolbars, nav/header, FAB, tab/find bars, standard controls, anything over arbitrary/unknown content. Auto-adapts light/dark. | PlaygroundApp header, FAB, FindBar chrome, AddToolModal, ToolDetail body |
| **Clear** | ~80–90% transparent | ONLY over media-rich / bold backgrounds, and **always with a dimming layer beneath**. Illegible otherwise — Apple themselves walked it back and added a "Tinted" fallback. | Glass panels floating directly over the live R3F graph |

Rule: **clear glass over busy content requires a scrim.** Add a gradient dim layer between the media and the glass (see §4). Without it, clear glass is the #1 cause of the "muddy/illegible" failure.

## 3. Layering & hierarchy — the rules that prevent soup

**Never stack glass on glass.** Glass-on-glass destroys hierarchy and looks like a smear. The system stack, bottom→top:

1. **Content layer — NO glass.** Primary, immersive (our R3F universe, list bodies, media). Glass is *never* applied to content itself.
2. **Navigation/chrome layer — glass.** Secondary, *lighter*, floats above content (header, FAB, FindBar, tab bar). This is the only layer that gets the glass material.
3. **Overlay vibrancy/fills — tertiary.** Labels/symbols inside glass use vibrancy (content tinted by what's behind), not solid colors.

Practical consequences for our shell:
- Header, FAB, FindBar, modals = glass. The universe canvas and any inner card lists = NOT glass (use solid/elevated surfaces, or flat translucent fills with no blur).
- If a glass modal (AddToolModal/ToolDetail) opens, **dim the background**, don't put it on top of another blurred bar. Decide one glass plane wins.
- Glass naturally creates hierarchy on its own — let the material raise attention to the chrome rather than piling on more shadows/stacks.

## 4. Scroll edge effect — the trick that keeps floating bars legible

This is what makes Apple's floating bars never look muddy over scrolling content, and we should replicate it.

- As content scrolls under a floating bar, the bar's background **fades the content out** right at its edge so text on the bar stays readable. Over light content it fades toward white; over dark content toward black. Two flavors: **soft** (subtle blur gradient — default) and **hard** (a crisp boundary, for high-legibility zones like headers/sort rows).
- The bar's own label/icon color **dynamically flips** to maintain contrast against whatever's behind.

Web recipe (use under header AND above FindBar):
- Add a `mask`/gradient fade strip ~24–40px tall at the bar edge: content fades from opaque → transparent toward the bar, so nothing collides with bar text.
- Or place a gradient scrim behind the bar: `linear-gradient` from `transparent` (0%) → `var(--bg)/0.85` (40%) → `var(--bg)` (100%). The **40% blend point, 0.85 opacity** is the cited sweet spot to kill muddiness over busy content.
- For our graph (always "busy"), keep a persistent soft scrim under the header and over the FindBar. This is cheaper and more reliable than per-frame adaptation.

## 5. Tint discipline — semantic only

- Tint glass **only for meaning** (primary action, active/selected state), **never decoratively**, and **one tint per surface**.
- E.g. the primary CTA in AddToolModal or the active viz-variant chip may carry a tint; ambient chrome stays neutral. Resist tinting the whole header "to look cool."
- Apply tint as a translucent fill *over* the blur: `background: color-mix(in srgb, <brand> 60%, transparent)` on top of the backdrop-filter.

## 6. Shape, corner radius, concentricity

- **Capsule** is the default for buttons/pills (FAB, FindBar input, chips). **Circle** for icon-only buttons (target **44–60pt** / ~44–60px hit area — also the min touch target).
- Panels: rounded rect, continuous ("squircle") corners — in CSS approximate with generous `border-radius` (16px standard panel) and avoid sharp browser corners; consider an SVG/`paint()` squircle if budget allows.
- **Concentricity**: nested rounded shapes must share a center — inner radius = outer radius − padding. A pill inside a 16px-radius card with 8px padding → inner radius 8px. Mismatched radii (pinched/flared corners) is a top "feels off / cheap" tell. Audit ToolDetail and AddToolModal inner elements for this.

## 7. Motion & micro-interaction language (timings + easings)

Premium = restrained, springy, *fast settle*. Concrete numbers:

- **Glass morph / expand-collapse** (e.g. FAB → expanded menu, search bar grow): spring, **response ≈ 0.3–0.5s**. Apple's `.bouncy(duration: 0.4)` ≈ a spring with mild overshoot. Web: Framer Motion `type:"spring", stiffness ~300, damping ~30` (≈ response 0.35, slight bounce), or a CSS `cubic-bezier(0.34, 1.56, 0.64, 1)` for a gentle overshoot.
- **Drag-release / snap-back**: `spring(response: 0.3, dampingFraction: 0.6)` — snappy, ~300ms, slight overshoot. Use for closing sheets, returning dragged glass to rest.
- **Press feedback on interactive glass**: scale to **~1.1× on active drag** (or ~0.96 on tap-down for buttons), plus a touch-point glow that radiates from the cursor/finger. Web: `transform: scale()` on `:active`/pointer + a radial highlight following pointer position.
- **Standard UI transitions** (fades, modal in/out, color/contrast flips): **~0.3s ease-in-out** is the workhorse. Keep most non-spring transitions in the **200–350ms** band; anything >400ms for a simple fade reads sluggish.
- **Scroll-driven chrome**: bars **minimize on scroll-down, expand on scroll-up** (`tabBarMinimizeBehavior(.onScrollDown)`). Adopt for header/FindBar to maximize the universe view, expand when the user reaches for navigation.
- **Specular/tilt**: highlights shift with device motion. On web, drive the rim highlight position from pointer move (and `deviceorientation` on mobile if available) for the "alive glass" feel — subtle, a few px of highlight travel, not a disco.

## 8. Gestures & state

- **Sheets/detents**: present panels as draggable sheets with snap waypoints (e.g. a half/large detent) and a top **grabber** affordance. ToolDetail and AddToolModal are good candidates for a bottom-sheet treatment with detents rather than a hard full-screen modal.
- **Haptics** (native only, but mirror the intent in motion): system controls fire light haptics on selection/toggle/detent-snap. On web we can't haptic, so compensate with a crisp micro-bounce + subtle highlight pulse at the same moments (selection committed, snap reached, toggle flipped).
- **State via material, not just color**: selected/active = slightly *more opaque + tinted + raised* glass; idle = lighter/clearer. This is how Apple shows state without heavy borders.

## 9. App-icon / brand-window depth (for ToolDetail "brand window" + AddToolModal)

Liquid Glass icons are **multi-layer**: foreground (logo/mark) + mid + background, with soft depth, translucency, specular highlights, and a neutral/chromatic drop shadow. Silhouette stays identical across Light/Dark/Clear/Tinted modes — recognition never drops. Bold, clear shapes are mandatory; busy artwork "merges" under the glass effect and goes flat.

Adopt in the ToolDetail brand window:
- Render each tool's brand mark on a **separate, slightly parallaxed layer** above its tinted-glass plate; add a soft chromatic shadow keyed to the brand color.
- Keep marks **bold/high-contrast**; don't let the glass eat fine detail. A subtle pointer-driven parallax (foreground moves a few px more than background) sells depth cheaply.

## 10. Accessibility — must honor (also improves the muddy-default problem)

- **Reduced Transparency** → swap glass for a near-opaque frosted/solid surface (Apple's `.identity` = effect off). Gate `backdrop-filter` behind `@media (prefers-reduced-transparency: reduce)`.
- **Reduced Motion** → drop springs/morphs to simple fades; kill tilt/parallax. `@media (prefers-reduced-motion: reduce)`.
- **Contrast**: maintain **≥ 4.5:1** between glass text and its backdrop. The scroll-edge scrim (§4) is what buys this over busy content.
- A "Tinted" high-opacity fallback exists precisely because Clear glass was often illegible — give users (or auto-detect) a more-opaque mode.

## 11. What premium apps HIDE vs SHOW

- **Show**: one decisive glass chrome layer; the live content/universe; semantic tint on the single primary action; the specular rim; the scroll-edge fade.
- **Hide / suppress**: stacked glass, hard borders, drop-shadow pileups, decorative tints, multiple competing blurs, anything that fights the content for attention. Glass chrome should feel *lighter* than content, never heavier.
- **Restraint is the premium signal.** Fewer surfaces, crisper edges, faster springs. When in doubt, remove a layer rather than add one.

---

## Adoption checklist for our shell (concrete)

- [ ] Every glass surface = blur(16–24px) **+ saturate(160–180%)** + inset specular rim + translucent fill (never blur alone).
- [ ] Decide per-surface: regular (chrome over flat UI) vs clear+scrim (panels over the R3F graph). Default to regular.
- [ ] Persistent soft **scroll-edge scrim** under header and over FindBar (gradient: transparent→bg/0.85 at 40%).
- [ ] **No glass-on-glass.** Opening a modal dims the background; only one glass plane is "live."
- [ ] Springs: morph/expand `response 0.35–0.4` w/ slight overshoot; snap-back `response 0.3 / damping 0.6`; generic transitions `~0.3s ease-in-out`, cap 350ms.
- [ ] Press: scale ~0.96 (buttons) / ~1.1 (dragged glass) + pointer-following highlight.
- [ ] Header/FindBar minimize on scroll-down, expand on scroll-up.
- [ ] Tint = semantic only, one per surface, over the blur.
- [ ] Concentric radii audit (inner = outer − padding) on ToolDetail / AddToolModal.
- [ ] ToolDetail brand window: layered + parallax + chromatic shadow, bold mark.
- [ ] Gate `backdrop-filter` and springs behind `prefers-reduced-transparency` / `prefers-reduced-motion`; ensure ≥4.5:1 text contrast.

---

## Sources

- [Apple Newsroom — new software design (Liquid Glass)](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
- [WWDC25 — Get to know the new design system](https://developer.apple.com/videos/play/wwdc2025/356/)
- [conor.fyi — iOS 26 Liquid Glass reference](https://www.conor.fyi/writing/liquid-glass-reference) ([GitHub mirror](https://github.com/conorluddy/LiquidGlassReference))
- [createwithswift — scroll edge effect style](https://www.createwithswift.com/define-the-scroll-edge-effect-style-of-a-scroll-view-for-liquid-glass/)
- [createwithswift — Liquid Glass visual language](https://www.createwithswift.com/exploring-a-new-visual-language-liquid-glass/)
- [anotherapple — Dark Mode with Liquid Glass (Clear vs Tinted)](https://www.anotherapple.com/2026/04/the-correct-way-to-use-dark-mode-with-liquid-glass/)
- [LogRocket — Adopting Liquid Glass: best practices](https://blog.logrocket.com/ux-design/adopting-liquid-glass-examples-best-practices/)
- [createwithswift — Liquid Glass app icons in Icon Composer](https://www.createwithswift.com/crafting-liquid-glass-app-icons-with-icon-composer/)
- [Apple HIG — Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)
- [designedforhumans — Liquid Glass & accessibility](https://designedforhumans.tech/blog/liquid-glass-smart-or-bad-for-accessibility)
