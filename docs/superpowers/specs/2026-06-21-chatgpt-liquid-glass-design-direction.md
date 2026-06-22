# Design Direction — Chat-first + Liquid Glass (synthesized)

Date: 2026-06-21 · Branch: `feat/redesign-chatgpt-liquid-glass` · Target iOS 26
Source: 4 parallel design-agent proposals (product / UI-UX / Liquid Glass HIG /
Mobbin patterns). Supersedes the open questions in
`2026-06-21-chatgpt-liquid-glass-redesign-plan.md`.

## The thesis (all four agents converged)

**Chat is the front door; the universe is the artifact the chat builds.** Not
two peer tabs — one looping product: ask → get a curated tool → "Add to map" →
the universe grows → next answer is more personal. The universe stops being "a
mode you switch to" and becomes the *visible memory of the conversation*. This
single relationship makes demoting the universe safe and makes both surfaces
stronger.

Positioning: *the assistant that turns "what should I use for X?" into a living
map of your stack — not another chatbot, not a dead directory.*

## Resolved decisions (were open in the plan)

| Question | Decision |
|---|---|
| TabView vs morph-switch | **Morph-switch**, NOT TabView. Tabs frame them as peer apps and kill the cause→effect story. Use `glassEffectID`+`@Namespace`. |
| Cold-start screen | **Always Chat** (home base), never last-used. |
| Settings location | **Sheet** (config, not conversation). Promote only "Add tool" out into chat. |
| Default universe render | **2D** as entry (reads/screenshots cleaner); 3D = wow toggle. |
| Universe discoverability | Reachable 3 ways: persistent "Map" pill w/ live tool-count badge · inline "View on map ↗" chip after an add · the add→universe morph. |

## Product (JTBD + IA)

Three jobs: (1) "task now → what do I use?" (80% of sessions, the chat thesis),
(2) "make sense of my stack" (the universe's real job, retention), (3) "capture
a tool I just found" (5-sec add, auto-placed).

Screen map:
- **ChatScreen** = home (cold start). Transcript (solid) + floating glass
  composer. Top bar: ☰ history (leading), "Map" pill + count badge (trailing).
- **UniverseScreen** = summoned overlay (existing `UniverseMapView`, renderers
  untouched). Glass HUD; "Ask about this ↓" returns to chat pre-seeded.
- **History** = left edge-swipe drawer (ChatGPT model), search-first, swipe-row
  actions. NOT a tab.
- **ToolDetail** = one sheet from card OR node. **AddTool** = sheet from composer
  "＋". **Settings** = glass toolbar button → sheet.

First-run (never show empty universe): land in chat with one assistant greeting
+ 3 tappable starter chips that fire a REAL recommendation → card with primary
"Add to my map ★" → one-time morph, Map pill ticks 0→1. Gate the universe until
≥3 nodes so the first galaxy feels earned.

## UI/UX (the big opinion)

**Assistant-on-page (no bubble) + user gets a bubble** — assistant turns carry
rich payloads (tool cards) that look toy-like boxed. Plus:
- **Warm-neutral reading surface** for chat (`#FAFAF8`/dark `#0B0D12`), distinct
  from the cosmic `void` (which stays in universe mode only).
- **SF Pro Text (`.default`), body 17pt, lineSpacing 5** — drop `.rounded` for
  chat body (keep `.rounded` only for empty-state display). Biggest "ChatGPT-
  grade" lever.
- **Single accent = `BrandColor.core`** (cyan-white, already AccentColor);
  demote violet/pink/teal to category/data roles only. Add `accentInk` for
  legible accent text on light.
- Transcript: max width ~720pt centered; 32pt between exchanges, 16pt within an
  exchange, 8pt same-author; user msg scrolls to top on send; assistant glyph
  on first line of a turn only.

### Tool-recommendation payloads (the unique value)
- **Inline tool chip** (in flowing text) → tap opens node/detail.
- **Matched-tool card** (raised solid surface, ≤2 actions: "Open in Universe",
  "Connects to →"); max 3 stacked then "Show N more".
- **Carousel** for 3–8 comparable options (image+title+2-line meta, 1 CTA).
- **Missing-tool "GAP IN YOUR STACK" card** (dashed border, accent wash) —
  first-class path, not edge case; primary "Add to my Universe".
- Cards fade+rise in as a group AFTER the text streams (deliberate conclusion).

## Liquid Glass system (HIG-correct)

**Glass = floating navigation/control layer only. Never content.** The current
`LiquidGlass.swift` over-glasses (~16 surfaces, incl. content + a manual stroke
fighting system lensing). Target ~5–6 true glass regions.

Glass MAP — **GLASS**: composer pill, send (`.glassProminent`), attach button,
chat⇄universe mode switch, universe HUD pill, toolbar/settings buttons, selected
category chip, attachment popover. **SOLID/MATERIAL**: chat bubbles, all cards,
sheet bodies (RootSheet already correct), AddTool/Settings panels, avatar ring,
universe canvas/background, attachment-staged pill.

New helper replacing `.liquidGlass(...)`:
```swift
func glassSurface<S: Shape>(in shape: S = .capsule, tint: Color? = nil,
                            interactive: Bool = false) -> some View
```
Three-tier resolution (a11y first): `accessibilityReduceTransparency` →
opaque `glassSolid`; else `#available(iOS 26)` → `.glassEffect(glass, in: shape)`
(NO manual stroke/clip — trust lensing); else `.ultraThinMaterial` + 0.5pt
hairline. Drop the `strokeStrength` param. Group neighbors in
`GlassEffectContainer` (composer, mode switch, rail) — never nest glass.

Token deltas: `BrandColor.glassSolid` (opaque fallback) + chat ramp + `accent`/
`accentInk`/`accentSubtle`; `BrandRadius.glassControl(22)/glassButton(16)`; chat
type scale in `BrandTypography`; `.scrollEdgeEffectStyle(.soft, for: .bottom)` on
the transcript. `BrandMotion.flow` (.smooth 0.36) is the morph curve — never
animate glass on repeating curves (per-frame thrash).

## Signature moments (the screenshots)
1. **Tool lands in your universe** — card morphs (`glassEffectID`) and flies to
   its orbital position when added. The product story made visible.
2. **"Ask about this" from any node** — node → glass affordance → chat pre-seeded.
   Closes the loop universe→chat; every node is a conversation starter.
3. **Live "Map" count badge** — ticks + pulses on each add. Ambient proof your
   stack lives here and nowhere else.

## Top patterns to adopt (Mobbin/best-in-class)
Inline card ≤2 actions (ChatGPT Apps SDK) · carousel 3–8 (ChatGPT/Perplexity) ·
**bi-directional chat⇄universe linking** (Tangent/MyMap — decisive anti-confusion
move) · promotable canvas + single nav toggle (ChatGPT Canvas/Claude Artifacts) ·
glass on composer+nav only (Apple iOS 26 showcase) · starter-prompt chips firing
real results (Arc) · context-morphing capsule + hold-to-talk voice (ChatGPT/
Raycast) · left edge-swipe history drawer (ChatGPT/Things).

## Revised build sequencing
Keep the plan's Phase 0–1 (design-system + glass the chrome) and 3–5, but **pull
a minimal card→universe morph into Phase 2** so the chat-first launch ships with
its core story (the morph is what justifies the IA), not a demoted universe with
no narrative glue.

## Must-validate before Phase 2 (flagged by product agent)
The 53-tool catalog must be good enough that JTBD-1 answers feel curated. The
**"no good match" state** is the highest-leverage screen: a miss must route to
"add the tool you mean" (JTBD-3), turning a miss into a contribution. Audit
catalog coverage before committing to chat-first.

## Cut list
TabView · last-used-on-cold-start · universe chrome (clarity/rail/lens) anywhere
near chat · a standalone "browse all tools" directory (that's the model we
differentiate against) · multi-screen onboarding tour · accounts/sync/auth (local
`UniverseViewModel` is enough).
