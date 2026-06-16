# iOS App-Store Readiness Review — AI Tool Universe Playground

Reviewer dimension: "does this feel like a native iOS app." Scope: `src/playground/**` shell
(PlaygroundApp, FindBar, ToolDetail, AddToolModal) + `src/components/InAppBrowser.tsx`,
`index.html`, `src/index.css`, and a representative finalist variant (Force3D).

Verdict: the shell already does a lot of the hard iOS work well — pointer-driven swipe-to-dismiss
with rubber-band resistance, long-press peek, `navigator.vibrate` haptics, `prefers-reduced-motion`
gating, iOS-correct easing curves, and enter/exit (not pop) transitions. The gaps that keep it from
feeling truly native are concentrated in **safe-area handling (the single biggest miss), touch-target
sizing on the variant nav, and a few gesture/perf rough edges**.

Severity legend: **P0** = stop-ship for App-Store feel · **P1** = clearly noticeable · **P2** = polish.

---

## P0 — Safe-area is structurally broken (env() returns 0 everywhere)

**File:** `index.html` line 5.
```html
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
```
`viewport-fit=cover` is missing. Without it, iOS Safari/WKWebView never exposes non-zero
`env(safe-area-inset-*)`. So the one place that *does* try to respect the home-indicator /
notch — `Organism.tsx:939,1051` `bottom-[max(1.5rem,env(safe-area-inset-bottom))]` — silently
collapses to the `1.5rem` fallback on every device. Every other surface ignores safe areas entirely.

**Fix:** set `content="width=device-width, initial-scale=1.0, viewport-fit=cover"`. This is the
prerequisite for all the safe-area fixes below.

### P0.a — FAB and FindBar collide with the home indicator
- **`PlaygroundApp.tsx:88`** — FAB is `bottom-6 right-6`. On a notched iPhone the home-indicator
  region eats the bottom ~34px, so the FAB sits on/under the indicator and is hard to tap.
  **Fix:** `bottom-[max(1.5rem,calc(env(safe-area-inset-bottom)+0.5rem))] right-[max(1.5rem,env(safe-area-inset-right))]`.
- **`FindBar.tsx:166`** — bottom chat bar uses `pb-5` only. The chat input — the primary action —
  rides into the home-indicator zone. **Fix:** `pb-[max(1.25rem,calc(env(safe-area-inset-bottom)+0.25rem))]`.
- **`ToolDetail.tsx:263`** — panel is `bottom-4`; its in-app "Open" CTA (line 380) can land under the
  indicator. **Fix:** `bottom-[max(1rem,env(safe-area-inset-bottom))]`.
- **`AddToolModal.tsx:276`** — `pt-[12vh]` top offset ignores the notch/Dynamic Island; on landscape
  or small phones the grab handle/title can tuck under it. **Fix:** add
  `pt-[max(12vh,calc(env(safe-area-inset-top)+1rem))]`.

### P0.b — Header / variant nav collides with the status bar / Dynamic Island
**`PlaygroundApp.tsx:98`** header is `top-0 p-4`. On a notched device the `h1` and the horizontal
variant nav (line 103) sit under the status bar / Island. **Fix:** wrap top padding with
`pt-[max(1rem,env(safe-area-inset-top))]`. (Force3D already compensates with `pt-32` at line 1101,
but the shell header itself does not.)

---

## P0 — Page is zoomable / not locked like an app; no tap-highlight reset

**Files:** `index.html:5`, `src/index.css`.

- The viewport allows pinch-zoom and the iOS double-tap-to-zoom delay. A "universe" app that
  itself pinch-zooms the 3D scene will fight the browser's pinch-zoom. Native apps don't double-tap-zoom
  the chrome. **Fix:** the 3D variants own pinch; lock browser zoom on the shell chrome via the same
  viewport change is risky for a11y, so instead set `touch-action: manipulation` on interactive chrome
  (kills the 300ms double-tap delay without blocking pinch on the canvas).
- **No `-webkit-tap-highlight-color`.** Every `<button>` (FAB, nav chips, send button, close ✕,
  connection chips) flashes the default grey iOS tap rectangle on touch — the #1 "this is a web page"
  tell. `src/index.css` has no reset. **Fix:** add to `index.css`:
  ```css
  button, a, [role="button"] { -webkit-tap-highlight-color: transparent; }
  html { -webkit-text-size-adjust: 100%; }
  ```
- **No overscroll/bounce containment on the root.** `src/index.css` `body` has no
  `overscroll-behavior: none`. The dvh root in `PlaygroundApp.tsx:78` (`h-[100dvh] overflow-hidden`)
  helps, but rubber-band overscroll can still reveal the page background behind the canvas during a
  drag. **Fix:** `html, body { overscroll-behavior: none; }`.

---

## P1 — Touch targets below 44×44pt (Apple HIG minimum)

Apple HIG mandates ≥44×44pt. Several primary controls are under that.

- **`PlaygroundApp.tsx:110`** — variant nav buttons: `px-3 py-1.5 text-xs` → roughly 28–30px tall.
  These are the main navigation and are the worst offenders; on a phone they're a thumb-miss factory.
  **Fix:** `min-h-[44px] px-3.5 py-2` (and let the row scroll — it already does via `overflow-x-auto`).
- **`FindBar.tsx:299` / `ToolDetail.tsx:291` / `AddToolModal.tsx:329`** — send button and the close ✕
  are `h-10 w-10` (40px). Close enough to read but 4px under spec. **Fix:** bump to `h-11 w-11` (44px),
  or keep the 40px visual box and add an invisible padded hit-area.
- **Chips** (`FindBar.tsx:229`, `ToolDetail.tsx:464`, `AddToolModal.tsx:396`) correctly use
  `min-h-[40px]` — close, but 40 < 44. Bump to `min-h-[44px]` for the primary tap chips, or keep 40
  only where they're secondary. Good that `min-h` is already a habit here.

---

## P1 — Gesture / momentum rough edges

- **No momentum/inertia on the FindBar swipe-down dismiss.** `FindBar.tsx:135-154` tracks raw `dragY`
  and only checks a 90px threshold on release — it ignores **velocity**. iOS sheets dismiss on a fast
  flick even if travel is short. A slow 80px drag and a fast 80px flick feel identical here (both keep
  the sheet). **Fix:** record timestamp+Y at pointerdown and compute velocity in `endThreadDrag`; dismiss
  if `dragY > 90 || velocity > ~0.5px/ms`. Same applies to `ToolDetail.tsx:208 endDrag` (pure distance
  thresholds `d.x>120 || d.y>140`) and `AddToolModal.tsx:240 onHandlePointerUp` (`dy > 110`).
- **ToolDetail drag area is the whole panel, including the scroll body conflict.** `ToolDetail.tsx:261`
  sets `touchAction: 'pan-y'` on the panel while the inner scroll region is `data-no-drag`
  (`:297`). Good — but the *header* region (lines 268-295) is draggable and also `touch-action: pan-y`,
  so a horizontal swipe-to-dismiss-right competes with the browser's native back-swipe-from-edge gesture
  on iOS. Right-edge horizontal dismiss (`d.x > 120`) specifically fights the iOS interactive-pop-gesture.
  **Fix:** prefer **down-only** dismiss for the sheet on phones (drop the rightward axis on touch), or
  set `touch-action: none` on the grab header so the browser doesn't claim it.
- **FindBar dismiss destroys the whole thread, no undo.** `FindBar.tsx:152 setTurns([])` on a 90px drag
  wipes the conversation with no confirmation/undo. A mis-swipe = total data loss. Native apps animate
  the sheet away but keep state, or offer undo. **Fix:** dismiss should collapse the thread view, not
  clear `turns`; or add a brief "Cleared · Undo" toast.
- **Long-press timing is 420ms across the board** (`FindBar.tsx:110`, `ToolDetail.tsx:430`,
  `AddToolModal.tsx:266`). iOS system long-press is ~500ms; 420ms is acceptable but on the twitchy side —
  combined with no movement-cancel on `FindBar`/`AddToolModal` chips (only `ToolDetail` cancels on
  `pointerleave`), a scroll that starts on a chip can fire an unwanted peek. **Fix:** cancel the
  long-press timer on `pointermove` beyond ~10px, matching the `ToolDetail` movedRef pattern.
- **Hover-only affordances leak to touch.** Every chip/button uses `hover:-translate-y-0.5` /
  `hover:bg-white/15`. On iOS, tap leaves the `:hover` state "stuck" until the next tap elsewhere, so a
  tapped chip stays lifted/brightened — an un-iOS sticky-hover artifact. **Fix:** gate hover lifts behind
  `@media (hover: hover)` (Tailwind `hover-hover:` via a small plugin, or move the lift into
  `[@media(hover:hover)]:hover:` arbitrary variants).

---

## P1 — Haptics are coarse and unsupported on iOS Safari

**Files:** `FindBar.tsx:26`, `ToolDetail.tsx:15`, `AddToolModal.tsx:33`.

`navigator.vibrate()` is the only haptic path, and **iOS Safari does not implement the Vibration API at
all** — so on the actual target platform there is currently *zero* haptic feedback. The calls are
harmless no-ops on iOS but mean the carefully-chosen 8/10/12/16ms values do nothing on iPhone.

**Fixes (in priority order):**
1. If this ships as a real iOS app (Capacitor/WKWebView wrapper), route haptics through the native
   bridge (`@capacitor/haptics` `impact({style})`) and keep `vibrate` as the Android/web fallback.
2. For pure Safari, the only web haptic is the `switch`/`<label>`-driven trick or the experimental
   `hapticFeedback` — not reliable; document that iOS haptics require the native wrapper.
3. Either way, centralize the three duplicated `haptic()`/`tap()` helpers into one
   `playground/haptics.ts` with semantic levels (`selection` / `impactLight` / `impactMedium` /
   `success`) so the call sites stay meaningful when the native bridge lands. Right now the magic
   millisecond numbers are scattered and platform-dead.

---

## P1 — Perf / 60fps risk on the chrome (not just the 3D)

- **Layered `backdrop-blur-2xl` stacking.** FindBar (`:170`), ToolDetail (`:263`), AddToolModal
  (`:294`) and the long-press scrims each apply `backdrop-blur-2xl` (24px) over a live, animating
  WebGL canvas. iOS GPU-composites blur per frame; a blurred sheet *animating its transform* over an
  always-rendering R3F canvas is the classic iOS jank source. The FindBar peek (`:321`) even stacks a
  second `backdrop-blur-sm` scrim on top. **Fix:** during the active drag/enter transition, drop to a
  cheaper blur (or a flat translucent fill) and only restore `blur-2xl` once settled; add
  `will-change: transform` (ToolDetail has it at `:263`, FindBar/AddToolModal partially — make it
  consistent) and ensure blurred layers aren't re-rasterized every frame.
- **`frameloop="always"` + `dpr={[1,2]}`** in `Force3D.tsx:1051-1052` (and per project invariant #5,
  all variants). On a 3× Retina iPhone the canvas renders at up to 2× DPR continuously even when idle.
  Combined with the always-on blur sheets this is a battery/thermal and sustained-fps concern.
  **Fix (within invariant #5 constraints):** cap `dpr` to `[1, 1.5]` on touch/`pointer:coarse` devices;
  consider dropping to `frameloop="demand"` *with manual invalidation* when a modal/sheet is open and
  the camera is idle (the scene is occluded behind a blurred sheet anyway).
- **No GPU-tier / low-power fallback.** There's no detection for older iPhones; antialias is forced on
  (`gl={{ antialias: true }}`, `Force3D.tsx:1059`). On an iPhone SE-class device this 4000-far,
  fogged, multi-light scene at 2× DPR will not hold 60fps. **Fix:** gate antialias and DPR ceiling on
  a quick perf probe or `navigator.hardwareConcurrency`/`deviceMemory`.

---

## P2 — Native-feel polish

- **Scroll bounce / `-webkit-overflow-scrolling`.** Inner scroll regions (ToolDetail body `:297`,
  Force3D panels `:1159,:1298`) use `overflow-y-auto`. Add `overscroll-contain` consistently (ToolDetail
  body lacks it) so a scroll-to-end doesn't bubble into a sheet-dismiss or page bounce. Force3D panels
  already use `overscroll-contain` — good; bring it to ToolDetail.
- **Text selection / callout on press-and-hold.** Chips set `select-none` (good), but the draggable
  panels/headers don't set `-webkit-user-select: none` / `-webkit-touch-callout: none`, so a slow
  press on the ToolDetail header can trigger the iOS text-selection magnifier mid-drag. **Fix:** add
  `select-none [-webkit-touch-callout:none]` to draggable surfaces (ToolDetail `:263`, AddToolModal
  handle `:312` already has `touch-none`).
- **Status-bar style / theme-color.** `index.html` has no `<meta name="theme-color">` and no
  `apple-mobile-web-app-status-bar-style`. For an installed/standalone app the status bar won't match
  the `#03040a` dark shell. **Fix:** add `<meta name="theme-color" content="#03040a">` and, if PWA,
  `<meta name="apple-mobile-web-app-capable" content="yes">` +
  `<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">`.
- **InAppBrowser sheet** (`src/components/InAppBrowser.tsx:23-49`) is a good `h-[88dvh]` bottom sheet but
  has **no swipe-to-dismiss** (only a "Close" button) — inconsistent with every other surface in the app,
  which all swipe-dismiss. And its content area (`p-3`) ignores `env(safe-area-inset-bottom)`. **Fix:**
  add the same pointer drag-to-dismiss + safe-area bottom padding for consistency.
- **Focus ring is desktop-styled.** `src/index.css:40` applies a 2px cyan `outline` on `:focus-visible`.
  Correct to keep for keyboard, but verify it never shows on touch tap (it shouldn't with
  `:focus-visible`, but the variant search inputs use `:focus` shadows that will). Low priority.
- **Reduced-motion is well-handled** across FindBar/ToolDetail/AddToolModal (consistent `reduce` gating)
  — call this out as a strength; just ensure the new velocity-dismiss path also respects it.

---

## Summary scorecard

| Area | State |
| --- | --- |
| Safe-area handling | **Broken** — missing `viewport-fit=cover`; chrome collides with notch/home-indicator |
| Touch targets | **Mixed** — chips use `min-h-[40px]` (close), but variant nav ~28px is sub-spec |
| Haptics | **Dead on iOS** — `navigator.vibrate` unsupported in Safari; needs native bridge |
| Gestures (swipe/long-press) | **Good bones**, but distance-only (no velocity), sticky-hover, destructive FindBar dismiss |
| 60fps / perf | **At risk** — always-on canvas at 2× DPR under stacked animated backdrop-blur sheets |
| Easing / transitions | **Strong** — iOS-correct cubic-beziers, enter/exit not pop, reduced-motion respected |
| Tap-highlight / zoom locks | **Missing** — default grey tap flash, double-tap-zoom delay, no overscroll lock |

### Top 5 fixes, in order
1. Add `viewport-fit=cover` (`index.html`) and thread `env(safe-area-inset-*)` into FAB, FindBar,
   ToolDetail, AddToolModal, and the shell header.
2. Add `-webkit-tap-highlight-color: transparent`, `touch-action: manipulation`, and
   `overscroll-behavior: none` globally (`src/index.css`).
3. Raise variant nav buttons (`PlaygroundApp.tsx:110`) and the 40px close/send buttons to ≥44px.
4. Add velocity-based flick dismissal and gate `hover:` lifts behind `@media (hover: hover)` across all
   three sheets; make FindBar swipe non-destructive.
5. Cap `dpr`/antialias on coarse-pointer devices and downgrade backdrop-blur during sheet transitions;
   centralize haptics behind a native bridge for real iOS feedback.
