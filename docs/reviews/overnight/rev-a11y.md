# Accessibility Review — AI Tool Universe (playground shell)

Scope: `src/playground/**` — PlaygroundApp, FindBar, ToolDetail, AddToolModal, and the
NeuralUniverse/BrainGraph finalists. Reviewed against WCAG 2.2 AA and iOS/VoiceOver
expectations (44pt targets, focus order, contrast, reduced motion).

Severity key: **P0** ship-blocker · **P1** high · **P2** medium · **P3** polish.

---

## P0 — Modal dialog is not labelled, no global focus styles

### 1. AddToolModal `role="dialog"` has no accessible name
`AddToolModal.tsx:289-293` — the dialog has `role="dialog" aria-modal="true"` but no
`aria-labelledby`/`aria-label`. VoiceOver announces "dialog" with no title. The heading
already exists at line 323.
**Fix:** give the `<h2>` an id and reference it:
```tsx
<h2 id="add-tool-title" className="...">Add a tool to the universe</h2>
// on the dialog div:
role="dialog" aria-modal="true" aria-labelledby="add-tool-title"
```

### 2. No visible focus ring anywhere in the playground
Every interactive control uses `outline-none` (FindBar input `FindBar.tsx:289`,
AddToolModal input `AddToolModal.tsx:341`) or relies only on hover styles
(all nav/chip/category buttons). `playground.css` defines zero `:focus-visible`
styles. Keyboard and switch-control users get no indication of focus — a WCAG 2.4.7
failure across the whole shell.
**Fix:** add a global focus-visible ring in `playground.css`, e.g.
```css
:where(button, a, input, [role="button"], [tabindex]):focus-visible {
  outline: 2px solid rgba(125, 211, 252, 0.9);
  outline-offset: 2px;
  border-radius: 12px;
}
```
The two text inputs that suppress outline (`FindBar`, `AddToolModal`) already add a
`focus:shadow` glow — that glow is decorative and very low contrast; keep a real
`focus-visible` outline too.

---

## P1 — Contrast, missing labels, focus order

### 3. The 3D canvas is invisible to assistive tech
`PlaygroundApp.tsx:79-81` renders `<Active />` (an R3F `<Canvas>`) with no text
alternative, and every graph node is a Three.js mesh (`NeuralUniverse.tsx:670` mesh
`onClick`), not a focusable DOM element. A screen-reader / keyboard user literally
cannot reach any tool node on the map — only the overlay search and category chips.
**Fix:** wrap the canvas container with `role="application"` +
`aria-label="AI tool universe map. Use the search field and category filters to
explore tools."` and ensure the DOM search/detail panels remain the keyboard path to
every tool. (Full keyboard graph traversal is out of scope for the prototype, but the
overlay must be documented as the AT-accessible route, and `aria-hidden` the canvas if
no semantics are exposed.)

### 4. Low-contrast text below WCAG AA (4.5:1) in many spots
On the near-black `#03040a` background:
- `text-white/35` and `text-white/40` labels — "Recently added" `FindBar.tsx:247`,
  Section titles `ToolDetail.tsx:546`, "Already on the map" `AddToolModal.tsx:391`,
  category-legend labels `NeuralUniverse.tsx:1218`, count text `:1257`. White at 35–40%
  alpha over this background is ≈ 2.5–3:1 — fails AA for body text.
- `placeholder-white/35` on both inputs (`FindBar.tsx:289`, `AddToolModal.tsx:341`).
- Hint paragraph `text-white/40` `AddToolModal.tsx:384`.
- Header subtitle `text-white/55` `PlaygroundApp.tsx:101` is borderline (~4.3:1).
**Fix:** raise small/secondary text to at least `white/55` for ≥14px and `white/70`
for the 10–11px uppercase labels and placeholders; bump confidence/count meta to
`white/60`. Verify each against `#03040a` at the actual blurred-glass backdrop (the
glass lightens the bg slightly, but contrast should be measured against the worst case).

### 5. Category-color chips fail contrast as the only state signal
`NeuralUniverse.tsx:1240-1257` — an "off" filter chip drops to `opacity: 0.45` with
`white/55` text; the on/off state is conveyed by opacity + a glow shadow only. Opacity
0.45 text fails contrast, and opacity is not a state cue VoiceOver exposes (only
`aria-pressed` is — good that it's set at `:1239`). Same pattern for the color dot.
**Fix:** keep `aria-pressed` (already present), but don't rely on opacity for the text —
use a distinct strikethrough/checkmark or a higher base alpha so the off state still
passes 4.5:1.

### 6. Icon-only "↑" / "✕" / "×" / "←" / "↗" buttons rely on glyph + arbitrary label
Good: most have `aria-label` (send `FindBar.tsx:306`, closes, clear-search). But the
inner glyphs are real text nodes, not `aria-hidden`, so VoiceOver may double-read
("up arrow, Ask"). The arrows that ARE decorative are inconsistently marked
(`NeuralUniverse.tsx:1206,1339` use `aria-hidden`, but `FindBar.tsx:309` "↑" and
ToolDetail `✕` `:294` do not).
**Fix:** wrap every decorative glyph inside a labelled button in
`<span aria-hidden>…</span>` so the `aria-label` is the sole announcement.

### 7. FindBar peek/open: focus is lost and order is wrong
`FindBar.tsx:316-362` — the long-press peek opens a full-screen `<button>` overlay
containing a nested `<div role="button" tabIndex={0}>` "Open". A `<button>` cannot
legally contain another button-role; and on open nothing moves focus into the overlay,
so keyboard users stay behind the scrim. On close, focus is not returned to the
triggering chip.
**Fix:** make the overlay a non-interactive scrim `<div>` with an explicit close
`<button aria-label="Close preview">`, move focus to the "Open" control on mount
(`useEffect` + ref `.focus()`), trap Tab within it, and restore focus to the chip on
close. The "Open" affordance should be a real `<button>`, not `div role="button"`.

### 8. ToolDetail panel is not a labelled dialog and has no focus management
`ToolDetail.tsx:252-263` — the brand window is a plain `<div>`. It is not announced as a
dialog, focus is never moved into it when it opens, Escape does not close it (only the
✕ button or swipe), and on close focus is not restored. Keyboard users opening a tool
from FindBar are stranded.
**Fix:** add `role="dialog" aria-modal="true" aria-labelledby={titleId}`, focus the
panel (or its close button) on mount, wire an Escape handler to `requestClose`, and
restore focus to the opener. Mirror the focus-trap already implemented in AddToolModal
(`AddToolModal.tsx:140-188`) — extract it into a shared hook so both panels share it.

### 9. PlaygroundApp header lacks landmarks / current state
`PlaygroundApp.tsx:98-120` — the `<header>` is `pointer-events-none` with islands of
`pointer-events-auto`; fine visually, but the variant `<nav>` buttons signal the active
variant only with a background swap (`activeId === v.id ? 'bg-white/90 text-black'`).
No `aria-current`.
**Fix:** add `aria-current={activeId === v.id ? 'true' : undefined}` to each nav button
so VoiceOver announces the selected visualization.

---

## P2 — Hit areas, text sizing, reduced motion gaps

### 10. Tiny text below the iOS-readable floor
Multiple `text-[10px]` and `text-[11px]` labels: Section titles `ToolDetail.tsx:546`,
"Recently added" `FindBar.tsx:247`, legend labels and counts `NeuralUniverse.tsx`,
"already added" `AddToolModal.tsx:411`. 10px (≈ Dynamic Type XS) is below the iOS HIG
recommendation and does not scale with user font settings (fixed px, not rem).
**Fix:** raise the floor to 12px (`text-xs`) and prefer `rem` units so Dynamic Type /
browser zoom scales them. Reserve 10px only for truly non-essential decoration.

### 11. Hit areas under 44×44 pt
- Variant nav buttons `PlaygroundApp.tsx:110` are `py-1.5 text-xs` → ≈ 28px tall.
- The "+" FAB is 56px (good).
- Category filter chips `NeuralUniverse.tsx:1240` are `min-h-9` (36px) and neighbor
  chips `min-h-9` `:1310` — below the 44pt iOS target.
- Clear-search "×" `NeuralUniverse.tsx:1183` is a small `px-1.5` glyph with no min size.
- ToolDetail/FindBar/AddToolModal chips correctly use `min-h-[40px]` (close, still < 44).
**Fix:** bump interactive targets to `min-h-11 min-w-11` (44px). For the dense variant
nav, keep visual size but extend the tap target with padding or a transparent
`::before` hit-slop. The `×` clear button needs an explicit `min-h-11 min-w-11`.

### 12. Reduced-motion coverage is good in TS but the CSS keyframes have no guard
`playground.css` defines `findbar-*` keyframes with **no**
`@media (prefers-reduced-motion: reduce)` block. The components mostly gate animation in
JS via `usePrefersReducedMotion`/`reduce` (good — FindBar, ToolDetail, AddToolModal all
branch on it), but anything that applies these classes outside that guard, or the
`motion-safe:animate-[findbar-rise]` on the FindBar container `FindBar.tsx:174`, depends
on Tailwind's `motion-safe` variant — which is correct, but the bare `findbar-fade`
animation on the FindBar peek scrim `FindBar.tsx:321` (`motion-safe:animate-…`) and the
AddToolModal `atm-rise`/`atm-bump` keyframes `AddToolModal.tsx:451-461` are gated only in
JS. NeuralUniverse correctly adds the `@media` guard for `.nu-fade` `:1353`.
**Fix:** add a belt-and-suspenders global guard in `playground.css`:
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```
This also covers the R3F ambient motion's overlay chrome. Note the 3D scene itself
(camera drift, node bob) should also honor reduced-motion — confirm the finalists read
`prefersReduced` for `useFrame` animation amplitude (BrainGraph `:975`, NeuralUniverse
`:65` read the query but verify it actually damps the scene, not just the overlay).

### 13. `navigator.vibrate` haptics not gated on reduced-motion
`FindBar.tsx:26`, `ToolDetail.tsx:15`, `AddToolModal.tsx:33` fire `navigator.vibrate`
on every tap/long-press. Vestibular-sensitive users who set reduced motion may also want
reduced haptics. Minor, but cheap to respect.
**Fix:** skip `vibrate()` when `prefers-reduced-motion: reduce` matches.

---

## P3 — Polish

### 14. Decorative images have empty alt (correct) but the monogram fallback has none
`ToolDetail.tsx:277,533`, `AddToolModal.tsx:358`, `BrainGraph.tsx:455` use `alt=""` on
logo `<img>` (correct — the tool name is adjacent text). No change needed; flagged only
to confirm it's intentional. The initials fallback is plain text — fine.

### 15. Drag-to-dismiss is touch-only with no keyboard/AT equivalent — but Escape/✕ exist
FindBar swipe-to-clear-thread (`FindBar.tsx:145-154`) has no non-touch equivalent to
clear the conversation. Low priority (a Reset/Clear button would help), but each panel
must still be dismissible without a swipe (AddToolModal: Esc ✓; ToolDetail: see #8).

### 16. Live-region for query answers
FindBar appends answer turns (`FindBar.tsx:190`) with no `aria-live`. A screen-reader
user submitting a query won't hear the answer.
**Fix:** wrap the thread region (or each new answer) in `aria-live="polite"`.

---

## Quick-win checklist (highest value, lowest effort)
1. Global `:focus-visible` ring in `playground.css` (#2) — fixes 2.4.7 site-wide.
2. `aria-labelledby` on AddToolModal + add the same dialog semantics + Escape to
   ToolDetail (#1, #8).
3. Raise all `white/35`–`white/40` body text to `white/55`+ and placeholders to
   `white/55` (#4).
4. `aria-hidden` on all decorative glyphs inside labelled buttons (#6).
5. Bump interactive targets to `min-h-11` (#11) and the global reduced-motion CSS guard
   (#12).
