# Playground Design System

The single source of truth for the liquid-glass "AI tool universe" playground
shell (`src/playground/**`). It resolves the inconsistencies surfaced in
`docs/reviews/overnight/*` into one rule per decision, grounded in the
liquid-glass / ChatGPT / Duolingo / Linear / visionOS references under
`docs/design/references/*`.

Implementers import the tokens from **`src/playground/designSystem.ts`** and
follow the per-component specs below. Never re-hand-code glass, radii, type,
spacing, shadow, or motion in a component — reference the module.

Governing principle (from the references): **a calm, near-empty surface that
reveals capability on demand.** One decisive glass chrome layer over the live
universe; semantic tint on the single primary action only; restraint is the
premium signal. Response is constant (every tap = fast, crisp, no overshoot);
delight is rare (overshoot/celebration reserved for genuine milestones).

---

## 1. Tokens

### 1.1 Color roles

| Role | Value | Use |
| --- | --- | --- |
| Base canvas | `BG_BASE = #03040a` | One value. Variants only layer gradients on top — never a different near-black. |
| **Accent (cyan)** | `ACCENT.ring = rgba(125,211,252,0.9)`, `ACCENT.text = cyan-200` | The ONE product accent. Focus rings, active/selected state, eyebrow emphasis. Never decorative. |
| Text primary | `white/85` | Titles, primary body. |
| Text body | `white/80` | Standard prose. |
| Text secondary | `white/60` | Sublabels, captions. |
| Text meta | `white/55` | Smallest legible step (eyebrows, placeholders). **Floor — never below 55%.** |
| Positive | `emerald-300/85` | Strengths only (semantic). |
| Caution | `amber-300/85` | Watch-outs only (semantic). |
| Danger | `red-200/85` | Error copy only (semantic). |

**Resolved inconsistencies:** the review found accent forked across cyan / amber /
slate / none and body opacity scattered across `/70 /75 /80 /85`. Single rules:
cyan is THE accent (migrate SemanticMap off slate, MetroMap/CityMap/GalaxyMap onto
it); emerald/amber are reserved strictly for positive/caution semantics; body
opacity collapses to the ladder above. All `white/35`–`white/45` body/label text
is raised to `white/55`+ (a11y AA over `#03040a`).

### 1.2 The 8 category colors

Single source: the seed data, re-exported as `CATEGORY_COLORS` / `categoryColor()`
/ `categoryTint()`.

| id | name | hex |
| --- | --- | --- |
| `coding` | Coding & Agentic Dev | `#6ee7ff` |
| `design` | Design & Product UI | `#ff8bd2` |
| `research` | Research & Data Intake | `#7fffd4` |
| `media` | Media & Creative Production | `#ffd166` |
| `distribution` | Distribution & Social Ops | `#9bff8a` |
| `infrastructure` | Infrastructure & Runtime | `#a78bfa` |
| `knowledge` | Knowledge & Skills | `#f0abfc` |
| `core` | AI Operating Core | `#d8faff` |

Use the category color for: the tool's brand plate background, the category
pill (`categoryTint(id, '33')` fill + solid hex text), and node tint in the viz.
A category color is **not** a substitute for the cyan accent — accent stays cyan
even inside a category-colored window.

### 1.3 Type scale (`TYPE`)

5 steps. Forbid arbitrary `text-[Npx]` and the letter-spacing zoo outside this set.

| Token | Class | Role |
| --- | --- | --- |
| `eyebrow` | `text-[10px] font-medium uppercase tracking-[0.2em]` | Section labels, meta. **One** size, **one** tracking (0.2em). |
| `chip` | `text-xs` (12px) | Chips, secondary. |
| `body` | `text-sm` (14px) | Body / answer text (15px acceptable if vertical room allows). |
| `title` | `text-base font-semibold` | Panel + modal + sheet titles (all the same now). |

Converts: every `text-[9px]/[11px]/[12px]/[13px]` → nearest step; every
`tracking-[0.14em…0.34em]` eyebrow → `tracking-[0.2em]`.

### 1.4 Spacing scale (`SPACE`)

8-based rhythm. `panel = p-4` (standard panels), `sheet = p-5` (primary modal/hero
only), `row = px-3 py-2` (inner content rows). Section gaps inside panels: 24px
(`space-y-6`) between logical groups; 12px (`space-y-3`) within a group. Whitespace
over divider lines.

### 1.5 Radii (`RADIUS`)

| Token | Class | Role |
| --- | --- | --- |
| `chip` | `rounded-xl` | chips, small controls, inputs |
| `panel` | `rounded-2xl` | mid panels, cards |
| `sheet` | `rounded-3xl` | primary / modal sheets, FindBar bar |
| `control` | `rounded-2xl` | **all** ~40px icon buttons (FAB, send, close) — one radius |
| `pill` | `rounded-full` | pills / toggles only |

Delete one-offs (`rounded-[1.4rem]`, mixed chip radii). **Concentricity:** inner
radius = outer radius − padding (a chip inside a `p-4` `rounded-2xl` panel reads as
`rounded-xl`). Audit ToolDetail / AddToolModal nesting.

### 1.6 Shadows / elevation (`SHADOW`)

3 tiers, no Tailwind shadow presets:

- `resting` `0_8px_30px_rgba(0,0,0,0.35)` — nav bar.
- `floating` `0_12px_40px_rgba(0,0,0,0.45)` — variant HUD, peek bubble.
- `modal` `0_24px_80px_rgba(0,0,0,0.55)` — ToolDetail, AddToolModal, FindBar.

Every glass surface also carries the inner specular highlight
`inset_0_1px_0_0_rgba(255,255,255,0.14)` (`SHADOW.highlight`).

### 1.7 Glass material levels (`GLASS`)

Every glass = **blur(24px) + saturate(~1.7) + translucent white fill + inner top
highlight + soft outer shadow.** Never plain blur (the muddy look). **The
`bg-black/*` dark-tint glass is banned** — it was the single biggest material
inconsistency. `backdrop-blur-xl`/`blur-md`/`blur` are reserved for the scrim only.

| Token | Recipe | Use |
| --- | --- | --- |
| `panel` | `rounded-3xl` + `bg-white/[0.07]` + `backdrop-blur-2xl backdrop-saturate-[1.7]` + modal shadow + highlight | ToolDetail, AddToolModal, FindBar bar, peek card |
| `floating` | `rounded-2xl` + same fill/blur + floating shadow | variant HUDs, ToolDetail peek bubble |
| `bar` | `rounded-2xl` + same fill/blur + resting shadow | header nav |
| `chip` | `rounded-xl border-white/10 bg-white/[0.06]` | chips, small controls |
| `scrim` | `bg-black/50 backdrop-blur-sm` | dim layer behind a live modal |

**Layering law (no glass-on-glass):** content layer (universe) = no glass; chrome
layer = glass; opening a modal dims the background with `scrim` rather than stacking
a second blurred bar. One glass plane is "live" at a time. **Active/selected** state
= slightly more opaque + cyan tint + raised, not a heavy border.

**Scroll-edge scrim:** keep a persistent soft gradient under the header and over
the FindBar (`transparent → BG_BASE/0.85 at 40% → BG_BASE`) so chrome text stays
≥4.5:1 over the always-busy graph.

### 1.8 Motion tokens (`DURATION`, `STAGGER`, `EASE`)

Two layers: **response** (every tap, fast, crisp, no overshoot) and **celebration**
(rare milestone, overshoot allowed).

| Token | ms | Easing | Use |
| --- | --- | --- | --- |
| `press` | 90 | `response` | button/toggle press-down (`active:scale-[0.96]` or `translateY`) |
| `hover` | 150 | `out` | hover / focus glow |
| `state` | 200 | `out` | state swap, send-icon morph (↑↔■) |
| `enter` | 300 | `out` | standard fade, focus border, empty-state |
| `sheet` | 360 | `sheet` (`0.32,0.72,0,1`) | modal/sheet present |
| `exit` | 260 | `sheet` | sheet dismiss (snappier than enter) |
| `turn` | 460 | `out` | message turn / section enter (translateY 8–12px + fade) |
| `peek` | 400 | `out` | long-press peek present |
| `celebrate` | 600 | `back` (`0.34,1.56,0.64,1`) | milestone burst ONLY |

Stagger: chips `45ms`, sections `42ms`, per-word stream `16ms`; **cap stagger count
at 6**. Easings: `EASE.out` is the default (~80%); `EASE.sheet` for sheet
present/dismiss; `EASE.back` ONLY for the icon settle and celebration; `EASE.response`
for button presses. Ban ad-hoc durations.

**Micro-animation catalogue:**

- **Tactile glass press** — `active:scale-[0.96]` (buttons) or `translateY(2–3px)` +
  brief inner-highlight intensify, ≤90ms `response`. The glass "lip" (Duolingo ledge,
  lightened for glass).
- **Send-icon morph** — empty→`mic`/hidden, has-text→filled ↑, streaming→■ stop;
  scale + cross-fade 200ms `out`.
- **Per-word stream fade** — answer words mount opacity 0→1 over 200–300ms, stagger
  16ms/word (simulated stream for the on-device query → premium feel).
- **Thinking 3-dot pulse** — before first answer paint, ~300–500ms, dots scale/opacity
  stagger 0.16s, 1.4s loop.
- **Turn / section enter** — translateY 8–12px + fade, 460ms `out`, staggered.
- **Chip stagger** — translateY 6px + scale 0.94→1, 400ms `out`, 45ms stagger.
- **Sheet present** — translateY 16–24px + scale 0.96→1, 360ms `sheet`.
- **Drag dismiss** — 1:1 finger tracking, rubber-band past axis (`DISMISS.resistance`),
  background universe scales `0.92→1.0` + blur `8→0` as it dismisses.
- **Brand-plate pop** — icon plate scale 0.8→1 on open, `EASE.back`.
- **Add-tool celebration** — anticipation beat → new node blooms into the universe
  (bloom flare + small camera push-in) → success haptic at the visual peak → total
  count-up → forward CTA. The single highest-value delight moment.

### 1.9 Gesture / dismiss contract (`DISMISS`, `LONG_PRESS_MS`)

**One** dismiss rule across all sheets (resolves three competing thresholds): dismiss
if dragged **down past `DISMISS.distancePx` (100px) OR a downward flick velocity >
`DISMISS.velocity` (0.5px/ms)**, else snap back to the nearest detent.
**Down-only on touch** (drop the rightward axis — it fights iOS edge-back-swipe).
Long-press = `LONG_PRESS_MS` (420ms), **cancel on `pointermove` > `LONG_PRESS_SLOP_PX`
(10px)** so a scroll that starts on a chip doesn't fire a peek.

### 1.10 Accessibility tokens (`FOCUS_RING`, `HOVER_LIFT`)

- `FOCUS_RING` — every interactive control gets it (the review found zero
  focus-visible rings). 2px cyan ring + 2px offset over `BG_BASE`.
- `HOVER_LIFT` — gate every hover lift behind `[@media(hover:hover)]` so it doesn't
  stick after a tap on iOS.
- Decorative glyphs inside a labelled button → `aria-hidden` so VoiceOver reads the
  label once. Prefer Lucide `X`/`Plus`/`ArrowUp`/`ArrowUpRight` over literal
  `✕`/`+`/`↑`/`↗` glyphs (consistent stroke weight; consistent baseline).
- Min touch target **44×44px** for primary controls (visual box may stay 40px with a
  padded hit-slop). Text floor 12px (`text-xs`); 10px only for non-essential meta.
- `prefers-reduced-motion` → springs/parallax → simple fades; also skip `vibrate()`.
  `prefers-reduced-transparency` → swap glass for near-opaque frosted fill.
- Live region: wrap the FindBar thread in `aria-live="polite"`.

### 1.11 iOS shell prerequisites (global, in `index.html` / `index.css`)

- `viewport-fit=cover` on the viewport meta (without it `env(safe-area-inset-*)`
  is 0 everywhere). Thread `env(safe-area-inset-*)` into FAB, FindBar, ToolDetail,
  AddToolModal, header.
- `button, a, [role="button"] { -webkit-tap-highlight-color: transparent; }`
- `touch-action: manipulation` on interactive chrome (kills 300ms double-tap delay
  without blocking canvas pinch).
- `html, body { overscroll-behavior: none; }`
- `<meta name="theme-color" content="#03040a">`.

---

## 2. Component specs

Each spec gives: placement/layout, every element + states, micro-animations/gestures,
and explicit hide-vs-show rules.

### 2.1 PlaygroundApp shell (nav / header / FAB / layout)

**Layout.** `h-[100dvh]` root, `BG_BASE`. Bottom→top z-stack: universe canvas
(`inset-0`, no glass) → header (top, glass nav) → FindBar (bottom) / ToolDetail
(right) / FAB (bottom-right) at the chrome layer → AddToolModal / InAppBrowser
(overlay, with scrim). One glass plane live at a time.

**Header (top).** `pointer-events-none` wrapper, `pt-[max(1rem,env(safe-area-inset-top))]`.

- *Title block* — non-interactive. **Ship copy, not engineer codenames.** Replace
  `active.label.split('·')[1]` + blurb with a user-facing one-liner (or hide the
  subtitle in shipping mode). The "A · AI Brain / Cosmograph / Neo4j Bloom" jargon
  is debug UI.
- *Variant nav* — `GLASS.bar`. **Demote the 15-tab lab switcher**: promote the
  finalists (A/K/N/O) and fold the rest behind a "More" disclosure, or hide the whole
  switcher behind a long-press/settings gesture in shipping mode. Tabs:
  `min-h-[44px] px-3.5 py-2` (was ~28px — sub-spec), `TYPE.body` weight-medium.
  States: default `TEXT.secondary`; hover `[@media(hover:hover)]` bg-white/10;
  **press `active:scale-[0.96]`** (was flat); active = cyan-tinted glass
  (`bg-white/[0.14]` + `ACCENT.text`, NOT the heavy opaque `bg-white/90` pill);
  `FOCUS_RING`; `aria-current` on active. Switching a variant **closes any open
  detail + clears nothing else** (re-focus the selected node in the new viz if one
  was selected).
- **`--hud-top`** — define one CSS var (header height + gap, e.g. `8rem`) and have
  every variant HUD anchor `top-[var(--hud-top)]`. Kills the `top-16/-[72px]/-32/pt-32`
  magic-number drift.

**FAB (bottom-right).** `h-14 w-14` (56px ✓ ≥44), `GLASS.floating` + `RADIUS.control`,
Lucide `Plus`. `bottom-[max(1.5rem,calc(env(safe-area-inset-bottom)+0.5rem))]
right-[max(1.5rem,env(safe-area-inset-right))]`. States: default; hover bg-white/[0.14];
`active:scale-95`; `FOCUS_RING` (was missing). **Entrance:** `motion-safe` rise on
mount (don't pop). **Pulse gently only in the empty-universe state** to draw the first
add. Verify it doesn't overlap the FindBar send button on a 390px viewport.

**Hide vs show.** Show: universe, header title, finalist tabs, FAB, FindBar.
Hide/defer: full 15-variant list (behind More), variant codenames/blurbs, settings,
filters — earned complexity, not first-run.

### 2.2 FindBar (bottom chat / command palette)

The FindBar **is** the command palette (one surface, ChatGPT-style, bottom-anchored,
thumb reach). `GLASS.panel`, `max-w-xl`, centered,
`pb-[max(1.25rem,calc(env(safe-area-inset-bottom)+0.25rem))]`.

**Critical fix (review 2e/4b):** lift `turns` state to PlaygroundApp (or hide FindBar
with CSS, don't unmount) so opening a tool window doesn't destroy the conversation.
Persist added tools + icons to `localStorage`.

**Composer (always visible).** Three zones `[leading +] [field] [trailing send]`:

- *Leading `+`* — reserved slot that re-focuses / opens add (matches the ChatGPT
  mental model: capability behind one `+`). Only include if it earns its place.
- *Field* — upgrade the single-line input to an **auto-grow `textarea`** (1 line →
  ~5-line cap, then inner scroll). `GLASS.chip` fill, `TYPE.body`,
  `placeholder-white/40`, quiet placeholder ("Ask the map…", truncate the example on
  small screens). States: default; focus = border-white/25 + cyan focus glow + bar
  lifts (`shadow` step up) over 300ms; `FOCUS_RING` (the glow is decorative — keep a
  real ring too). `enterKeyHint="search"`, `inputMode="search"`.
- *Send (`h-11 w-11`, 44px, `RADIUS.control`)* — **morphs with state, never just
  enabled/disabled**: empty → low-contrast mic/hidden; has-text → filled ↑
  (`bg-white/90 text-black` + `shadow`); streaming → ■ stop (tap cancels). Scale +
  cross-fade 200ms. Press `active:scale-[0.88]`; disabled `opacity-40 scale-100`;
  `FOCUS_RING`. Light haptic on send; tick on state change.

**Empty state (no turns).** **Seed 2–3 tappable example-query chips** ("build a
database fast", "edit video", "research tool") that pre-fill the composer (currently
the area is blank until you add a tool). "Recently added" history chips below if any.
Chips: `GLASS.chip`, `min-h-[44px]`, `HOVER_LIFT`, `active:scale-[0.96]`, `FOCUS_RING`,
staggered `findbar-chip` 45ms.

**Thread (turns > 0).** `max-h-[33vh]`, `aria-live="polite"`, scroll.

- *User turn* = bubble: `ml-auto max-w-[85%] rounded-2xl rounded-br-md bg-white/[0.12]`,
  `TYPE.body`.
- *Assistant turn* = NOT a heavy bubble for long answers — let it run wider (~90–95%)
  on the surface; keep a subtle fill only for short replies. **Per-word fade stream**
  + a brief 3-dot thinking pulse before first paint.
- *Result chips* = the "source/result cards." Upgrade name-only → **favicon/logo +
  name + 1-line category** (scannable). For >3 matches use a horizontal snap strip,
  not a wrap. Tap opens the brand window. **Drop the duplicated tool names from the
  prose tail** (keep just the "why"); the chips are the single tappable surface.
- *Follow-up pills* — after an answer with matches, render 1–3 follow-ups ("Show
  alternatives", "What connects to X", "Cheaper options"), revealed AFTER the answer
  paints (stagger). Tapping runs it as the next turn.
- *Grabber* — `h-1 w-9 bg-white/20` top-center (one handle token across app).

**Gestures.** Swipe-down-to-dismiss only when scrolled to top (`scrollTop ≤ 2`);
**non-destructive** — collapse the thread view, don't `setTurns([])`; if a clear is
intended, add a visible "New chat" control + an "Cleared · Undo" toast (no silent wipe).
Use the unified `DISMISS` contract (distance OR velocity). Long-press chip → peek
(420ms, cancel on 10px move). Enter submits; Shift+Enter newline.

**Zero-result.** Quiet line + an inline **"Add it"** button that opens AddToolModal
pre-filled (don't reference "the + button" the user must hunt for).

**Hide vs show.** Show: field + send, user bubbles, assistant text, streaming, result
cards, 2–3 suggested prompts (empty), follow-ups after answer. Hide: tools/attachments
(behind `+`), per-message toolbars (copy/retry on demand), timestamps, avatars,
follow-ups during streaming.

### 2.3 ToolDetail (brand window)

A **floating glass bottom-sheet** (phones) / right column (desktop). `GLASS.panel`,
`bottom-[max(1rem,env(safe-area-inset-bottom))]`, `will-change:transform`,
`select-none [-webkit-touch-callout:none]` on draggable surfaces. On phones: two
detents — `medium ≈ 52vh` (hero above fold) + `large ≈ 92vh`.

**Add (review/a11y #8):** `role="dialog" aria-modal="true" aria-labelledby`,
focus the panel/close on mount, **Escape-to-close**, restore focus to opener
(extract AddToolModal's focus-trap into a shared hook). `overscroll-contain` on the
scroll body.

**Hero (above fold).** Brand plate (`h-12 w-12 rounded-2xl`, category-color bg,
multi-layer feel: logo on a slightly-parallaxed layer + soft chromatic shadow keyed to
the category color, bold mark) + name (`TYPE.title`) + category pill
(`categoryTint(id,'33')` fill, solid hex text) + `· stage` + single primary CTA. Plate
**pops** scale 0.8→1 `EASE.back` on open.

**Body sections** (whitespace, no dividers, 24px gaps, eyebrow labels):
What it does · Killer features · Strengths(`positive`)/Watch-outs(`caution`) ·
Who uses it · Pricing · Connected-to. Each staggers in (`stagger` 42ms).

- *Un-enriched / user-added tools (review 3a):* don't show an empty "Pricing not yet
  researched" stub — **hide the Pricing section when unknown**, or show an explicit
  "Inferred — not yet researched" state so the emptiness is intentional. Description →
  3-line clamp + inline "more" (animate height, no nav).
- *Connection chips* — `GLASS.chip` `RADIUS.chip` `min-h-[44px]`, favicon + name,
  `HOVER_LIFT`, `active:scale-95`, `FOCUS_RING`. Group/annotate by category when 8+.
  Tap opens. **Drop the redundant long-press peek bubble here** — a short tap already
  navigates faster than the peek reveals (review 3c).
- *Primary CTA ("Open ⟨tool⟩")* — `bg-white/90 text-black` `RADIUS.control`,
  bottom-pinned, sheen sweep on hover, `active:scale-[0.98]`, `FOCUS_RING`. For
  url-less seed tools: derive a URL from `logoDomain`/name or show a disabled "Link
  coming soon" — never a silently empty action slot.

**Gestures.** Down-only swipe-dismiss (`DISMISS` contract); couple drag progress to
background universe scale `0.92→1.0` + blur. Grabber `h-1 w-9 bg-white/20`. Close ✕ →
Lucide `X`, `h-11 w-11`, `FOCUS_RING`.

**Add-side acknowledgement (review 1a).** When opened right after an add, show a
one-line "Added to ⟨Category⟩ · ⟨Stage⟩" banner tying back to the node, and pulse the
new node in the active variant.

**Hide vs show.** Above fold: plate, name, category pill, single CTA, grabber. Reveal:
full description (clamp+more), detailed specs (scroll to large), secondary actions
(share/report — toolbar only when expanded), related rail.

### 2.4 AddToolModal (+ add tool)

**Large-only** centered sheet (HIG: no medium detent when content needs height).
`GLASS.panel` `SPACE.sheet` (`p-5`), `scrim` behind it,
`pt-[max(12vh,calc(env(safe-area-inset-top)+1rem))]`. Already has Escape + focus-trap;
**add `aria-labelledby`** referencing the `<h2 id>`.

**Header.** Title (`TYPE.title` — same as ToolDetail now) + close ✕ (Lucide `X`,
`h-11 w-11`, `FOCUS_RING`). Grab handle `h-1 w-9 bg-white/20` (unify with the app
handle token; fix the dead `group-active` — put `group` on the handle wrapper or move
the active style onto the handle).

**Input.** `GLASS.chip` fill, `TYPE.body`, `placeholder-white/40`, focus cyan glow +
`FOCUS_RING`. `enterKeyHint="done"`. Enter submits.

**Preview row** (when text present, `atm-rise` 360ms). Plate (category-color) + name +
category pill + `· stage` + confidence. **Resolve the confidence ambiguity:** either
let the user **tap the category pill to override** the guess before adding (then the %
is actionable), or drop the % (a number the user can't influence is noise). Move icon
handling **into this row** (tap the logo to replace) — contextual, frees the footer.

**"Already on the map" matches.** Make them **real `<button>`s** (currently `<span>`
with fake button affordances) that open the existing tool on tap (`onAdded(id)` +
close) — or strip the interactive styling. `min-h-[44px]`, `FOCUS_RING`. **Dedupe
intent:** if an exact identity match exists, relabel the primary CTA to "Open ⟨tool⟩"
or toast "Already on the map — opening it" rather than silently routing.

**Footer.** Single primary CTA "Add to map" — `bg-white/90 text-black`
`RADIUS.control`, `min-h-[44px]`, `disabled:opacity-40`, `FOCUS_RING`. Icon upload
moved out of the footer (into the preview row) so the footer holds only the primary
action. Upload button needs a **reading/loading state** (FileReader is async) + a
"remove image" path once set.

**Success = the celebration moment.** anticipation beat → new node blooms into the
universe (bloom flare + small camera push-in) → success haptic at the visual peak →
"tools mapped: N" count-up → open the brand window with the "Added to …" banner.

**Gestures.** Down swipe-dismiss (`DISMISS`); **unsaved-changes guard** — if the input
has text, intercept dismiss with a confirm. Scrim click closes.

**Hide vs show.** Show: input, live preview, matches, single CTA. Hide: paste hint
folds into the preview-row affordance (don't lose it the moment a preview renders);
advanced category/stage editing behind the tappable pill.

---

## 3. Cross-component contracts (one rule each)

- **Glass:** only `GLASS.*`; no `bg-black/*` glass; no glass-on-glass; scrim dims the
  background for any modal.
- **Accent:** cyan only, for focus + active + emphasis. emerald/amber = semantics only.
- **Type:** the 5 `TYPE` steps; eyebrow is always `text-[10px] tracking-[0.2em]`.
- **Radius:** the `RADIUS` map; all ~40px icon buttons = `RADIUS.control`.
- **Shadow:** the 3 `SHADOW` tiers + the inner highlight; no Tailwind presets.
- **Motion:** the `DURATION`/`EASE` tokens; `EASE.back` only for icon settle +
  celebration; cap stagger at 6.
- **Dismiss:** one `DISMISS` contract (down past 100px OR flick > 0.5px/ms), down-only
  on touch, non-destructive.
- **Focus:** `FOCUS_RING` on every interactive control; `aria-current`/`aria-pressed`
  for selected state; decorative glyphs `aria-hidden`.
- **Hover:** every lift gated behind `HOVER_LIFT`.
- **Handle:** one grabber token `h-1 w-9 bg-white/20`.
- **Icons:** Lucide `X`/`Plus`/`ArrowUp`/`ArrowUpRight`, not literal glyphs.
- **State persistence:** `turns` lifted out of FindBar; added tools + icons in
  `localStorage`.
- **Safe-area:** `viewport-fit=cover` + `env(safe-area-inset-*)` on every
  bottom/top-anchored surface.
