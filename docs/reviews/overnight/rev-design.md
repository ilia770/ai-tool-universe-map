# Design Consistency & Visual Hierarchy Review

Reviewer dimension: design consistency & visual hierarchy
Scope: `src/playground/**` (shell surfaces + 15 viz variants)
Date: 2026-06-16

This audit treats the shell (PlaygroundApp, FindBar, ToolDetail, AddToolModal)
as the canonical "premium liquid-glass" language and measures every viz-variant
HUD against it. The biggest issue is that there is **no shared token layer** —
every surface re-hand-codes glass, radii, blur, type, and spacing, so the same
visual element drifts file-to-file. Findings are ordered by severity.

---

## P0 — System-level: no shared design tokens

There is no token source. `playground.css` only holds 5 keyframes; glass,
radius, blur, shadow, and accent values are re-typed as literal Tailwind classes
in ~20 places. Every finding below is a symptom of this.

**Unified rule:** introduce a single token module (CSS custom props in
`playground.css` + a small `tokens.ts` of class strings) and reference it
everywhere. Proposed canonical set:

- Glass surface (panel): `rounded-2xl border border-white/10 bg-white/[0.07] backdrop-blur-2xl shadow-[0_12px_40px_rgba(0,0,0,0.45),inset_0_1px_0_0_rgba(255,255,255,0.14)]`
- Glass surface (chip/control): `rounded-xl border border-white/10 bg-white/[0.06]`
- Accent: pick ONE — cyan (`cyan-300/200`) is used by the 4 finalists, so make cyan the system accent.
- Scrim: `bg-black/50 backdrop-blur-sm`
- Type scale: see P2.
- Radius scale: see P3.

---

## P1 — Glass treatment is inconsistent (opacity, blur, inner highlight)

The "frosted panel" exists in at least four mutually-incompatible recipes:

| File · element | Recipe | Problem |
| --- | --- | --- |
| `ToolDetail.tsx:263` panel | `bg-white/[0.07]` + `backdrop-blur-2xl` + inner top-highlight + `ring-1 ring-inset ring-white/[0.08]` | the "gold standard" — rich layered glass |
| `FindBar.tsx:170-171` bar | `bg-white/[0.07]` + `backdrop-blur-2xl` + inner highlight | matches ToolDetail ✓ |
| `AddToolModal.tsx:294,304` | `bg-white/[0.07]` + `backdrop-blur-2xl` + inner highlight | matches ✓ |
| `PlaygroundApp.tsx:103` nav | `bg-white/[0.06]` | one step lighter than the canon `0.07`; no inner highlight |
| `Force3D.tsx:1103,1113,1190,1201,1266` | `bg-white/[0.06]` + **`backdrop-blur-xl`** + NO inner highlight | weaker blur tier + flat (no top highlight) → reads cheaper than the shell |
| `Firefly.tsx:788,892,936` | `bg-white/[0.06]` + `backdrop-blur-xl` | same weaker tier |
| `CityMap.tsx:567`, `ForceCloud.tsx:628`, `GalaxyMap.tsx:782`, `MetroMap.tsx:475,508`, `SemanticMap.tsx:566` | **`bg-black/40–0.65`** + `backdrop-blur` / `blur-md` | dark-tint glass — a completely different material from the shell's white-tint glass |
| `BrainHub.tsx:683,698` | bare `backdrop-blur` (default 8px), color from `style` prop | thinnest blur in the codebase |

**Unified rule:** all floating panels use the single panel-glass token
(`bg-white/[0.07]`, `backdrop-blur-2xl`, inner `0_1px_0` highlight, soft outer
shadow). Drop the `bg-black/*` dark-tint variant entirely — it is the single
biggest material inconsistency. Reserve `backdrop-blur-xl`/`blur-md`/`blur`
only for the dim scrim, never for content panels.

## P1 — Accent color is forked (cyan vs amber vs slate vs none)

- Finalists `BrainGraph` (`cyan-200/80` :1103), `Force3D` (`cyan-300` :1104, plus cyan focus rings/stage pills throughout), `NeuralUniverse` (`cyan-200/70` :1140) all use **cyan** as the single accent.
- `MetroMap`, `CityMap`, `GalaxyMap` use per-provider line colors and `bg-black` chrome with **no consistent accent**.
- `SemanticMap.tsx:540,566` uses **slate** (`slate-200/80`, `slate-900/85`) as its tint — a different neutral family from the rest (white/black).
- The shell itself is **accent-less**: FindBar/ToolDetail/AddToolModal CTAs are pure `bg-white/90 text-black`, ToolDetail strengths/watch-outs use `emerald-300` / `amber-300` (`ToolDetail.tsx:334,337`).

**Unified rule:** declare cyan the product accent (it already wins 3/4
finalists). Use it for focus rings, active-state highlights, and the "eyebrow"
uppercase labels. Keep `emerald`/`amber` strictly as semantic
positive/caution colors (Strengths/Watch-outs), never as decoration. Migrate
`SemanticMap` off slate onto the white/cyan system.

## P1 — Header overlaps every variant's own top HUD

`PlaygroundApp.tsx:98` renders a fixed header (`top-0 p-4`, title + variant
nav) at `z-10`. Variants then push their own HUD down by hard-coded ad-hoc
top offsets to dodge it:

- `BrainGraph.tsx:1100` `top-32`, `Force3D.tsx:1101` `pt-32`, `NeuralUniverse.tsx:1138` `pt-32`, `BloomGraph.tsx:1223` `top-32` / `:1339` `top-[8.5rem]`, `Firefly.tsx:788` `top-[72px]` / `:892` `top-[72px]`, `Force3D.tsx:1266` `top-32`, `BloomGraph.tsx:1514` `top-16`.

These magic numbers (`top-16`, `top-[72px]`, `top-32`, `top-[8.5rem]`,
`pt-32`) are all approximations of the same "clear the header" intent and
disagree with each other, so HUD top-alignment is visibly different per
variant.

**Unified rule:** define one CSS var `--hud-top` (height of header + safe
gap, e.g. `8rem`) and have every variant HUD anchor to it
(`top-[var(--hud-top)]`). Better: render the header as a layout sibling and
let variants fill the remaining area, removing the offset guesswork entirely.

---

## P2 — Type scale is unsystematic (10 distinct sizes, arbitrary mixing)

Sizes in active use across surfaces: `text-[9px]`, `text-[10px]`,
`text-[11px]`, `text-[12px]/text-xs`, `text-[13px]`, `text-sm`, `text-base`.
That is ~7 body/label sizes plus per-file one-offs. Concrete drift:

- **Eyebrow/section labels:** `ToolDetail.tsx:546` uses `text-[10px] uppercase tracking-wider`; `BrainGraph.tsx:1103` uses `text-[11px] uppercase tracking-[0.28em]`; `Force3D.tsx:1104` `text-[11px] tracking-[0.34em]`; `NeuralUniverse.tsx:1140` `text-[11px] tracking-[0.32em]`; `AddToolModal.tsx:391` `text-[10px] tracking-wider`. Same role, 2 sizes and 4 different letter-spacings.
- **Letter-spacing zoo:** `tracking-wider`, `tracking-[0.14em]`, `tracking-[0.16em]`, `tracking-[0.18em]`, `tracking-[0.2em]`, `tracking-[0.24em]`, `tracking-[0.28em]`, `tracking-[0.32em]`, `tracking-[0.34em]` all appear for uppercase eyebrows.
- **Chip text:** FindBar chips `text-xs` (`:230`), ToolDetail connection chips `text-xs` (`:464`), Force3D stage chips `text-[10px]` (:1249), BrainGraph relation chips `text-[11px]` (:1264). Same component role, 3 sizes.
- **Panel title:** ToolDetail `text-base font-semibold` (:280), AddToolModal `text-sm font-semibold` (:323), PlaygroundApp `text-sm font-semibold` (:100). The detail title and the modal title are different sizes for the same "panel header" role.

**Unified rule:** lock a 5-step scale and forbid arbitrary `text-[Npx]`:
`text-[10px]` (eyebrow/meta), `text-xs` (chips/secondary), `text-sm` (body),
`text-base` (panel title), with `font-semibold` reserved for titles +
eyebrows. Pick ONE eyebrow tracking (`tracking-[0.2em]`) and one eyebrow size
(`text-[10px]`). Convert all `text-[9px]/[11px]/[12px]/[13px]` to the nearest
step.

## P3 — Radius scale is inconsistent for equivalent roles

- **Chips:** FindBar match chips `rounded-lg` (`FindBar.tsx:229`), ToolDetail connection chips `rounded-xl` (`:464`), AddToolModal match chips `rounded-lg` (`:396`), Force3D filter chips `rounded-full` (`:1249`), BrainGraph relation chips `rounded-full` (`:1264`). Four radii (`lg`/`xl`/`full`) for one "tag chip" role.
- **Close buttons:** ToolDetail `rounded-xl` (:291), AddToolModal `rounded-xl` (:329) — consistent ✓, but the FAB is `rounded-2xl` (`PlaygroundApp.tsx:88`) and the FindBar send button is `rounded-2xl` (`:299`) — a 40px square control rendered with two different radii across the shell.
- **Panels:** shell panels `rounded-3xl` (FindBar/ToolDetail/AddToolModal); variant panels `rounded-2xl` (most) and `rounded-[1.4rem]` (`Force3D.tsx:1298`) and `rounded-xl` (`MetroMap.tsx:475`). The hero detail card in Force3D invents `1.4rem` for no reason.

**Unified rule:** radius tokens — chips/small controls `rounded-xl`,
mid panels `rounded-2xl`, primary/modal sheets `rounded-3xl`, pills/toggles
`rounded-full` only when explicitly a pill toggle. All ~40px icon buttons
(FAB, send, close) use the same radius (`rounded-2xl`). Delete the one-off
`rounded-[1.4rem]`.

## P3 — Inconsistent panel padding for equivalent panels

`p-2` (FindBar outer :170), `p-3`/`p-3.5` (BloomGraph :1223), `p-4`
(ToolDetail header/body :268,297, BrainGraph :1211), `p-5`
(AddToolModal :294, Force3D detail :1298, Organism :945, NeuralUniverse :1269).
Primary sheets range `p-4`→`p-5` with no rule; section padding inside panels
also varies (`px-3.5 py-2.5`, `px-4 py-3`, `px-4 py-2.5`).

**Unified rule:** panel padding token = `p-4` for standard panels, `p-5` only
for the primary modal/hero sheet. Inner content rows use `px-3 py-2`.

## P3 — Shadow depth is ad-hoc

Outer shadows in use: `shadow-[0_8px_30px_rgba(0,0,0,0.3)]`,
`...0.35]`, `shadow-[0_10px_40px_...0.45]`, `shadow-[0_12px_40px_...0.45]`,
`shadow-[0_24px_70px_...0.6]`, `shadow-[0_24px_80px_...0.55]`,
plus Tailwind presets `shadow-lg`/`shadow-xl`/`shadow-2xl`
(NeuralUniverse :1159,1216,1269; GalaxyMap :782; SemanticMap :566). Same
elevation tier rendered with 6+ different blur/spread/alpha values, and some
variants mix the custom system with Tailwind presets within one file.

**Unified rule:** 3 elevation tokens — resting panel
`0_8px_30px_rgba(0,0,0,0.35)`, floating panel `0_12px_40px_rgba(0,0,0,0.45)`,
modal/hero `0_24px_80px_rgba(0,0,0,0.55)`. All panels also carry the inner
`inset_0_1px_0_0_rgba(255,255,255,0.14)` top-highlight (currently only the
shell does). No Tailwind shadow presets.

---

## P4 — Smaller alignment / hierarchy nits

- **Grab-handle width drift:** ToolDetail handle `w-9 h-1` (:266), FindBar handle `w-9 h-1` (:188) ✓, but AddToolModal `w-10 h-1.5` (:319) and the handle color is `bg-white/20` vs `bg-white/25`. Pick one handle token (`h-1 w-9 bg-white/20`).
- **Base canvas bg drift:** PlaygroundApp shell `bg-[#03040a]` (:78) but variants set their own near-black bases: `#05080f` (Force3D), `#04060f` (NeuralUniverse/ForceCloud), `#04020f` (GalaxyMap), `#0a0d14` (MetroMap), `#070b16` (CityMap card). During the variant mount/transition the underlying shell black can flash a different hue. Define one `--bg-base` and let variants only add gradient overlays on top.
- **Close-button glyph:** uses the literal `✕` character (ToolDetail :294, AddToolModal :332) and the FAB uses literal `+` (:90) / send uses `↑` (:309). These render in the system font, not a consistent icon set, so weight/baseline differ from Lucide icons used elsewhere in the product. Use Lucide `X`/`Plus`/`ArrowUp` for consistent stroke weight.
- **Eyebrow color drift:** eyebrow labels are `text-white/55` (BrainGraph :855), `text-white/45` (ToolDetail pricing :351), `text-white/35` (ToolDetail Section :546, AddToolModal :391), `text-white/40` (BrainGraph :1253). Same role, 4 opacities. Pick `text-white/40`.
- **Active-tab contrast:** PlaygroundApp nav active state is `bg-white/90 text-black` (:112) — an opaque white pill inside a glass bar, which is heavier than any other active state in the app (variants use `bg-white/[0.12]`). Either tone the tab active state to `bg-white/[0.14]` or make selected viz states match the strong white treatment; right now the nav is the only place a solid-white active chip appears.
- **Body text opacity ladder:** primary body is `text-white/75` (ToolDetail), `text-white/85` (FindBar answer :206), `text-white/80` (AddToolModal preview), `text-white/70` (Force3D :1326). Standardize: primary body `text-white/80`, secondary `text-white/60`, meta `text-white/40`.

---

## Suggested remediation order

1. Add token layer (P0) — CSS vars + class-string constants in `playground.css` / a `tokens.ts`.
2. Migrate the 4 finalists (A/K/N/O) to the panel-glass + cyan-accent + type/radius tokens (P1/P2/P3) so the demoed surfaces are coherent.
3. Kill the `bg-black/*` dark-tint glass in non-finalist variants (P1).
4. Replace per-variant `top-*` header offsets with `--hud-top` (P1 overlap).
5. Sweep eyebrow tracking/size, chip radius, shadow tiers, body-opacity ladder (P2–P4).
