# Reference — Duolingo & Delightful Apps (playful micro-interactions, haptics, celebration)

Scope: reusable interaction patterns for our liquid-glass "AI tool universe". FOCUS = button press feel, haptics, progress feedback, celebratory moments, gamified delight applied tastefully. Sourced from deep knowledge of Duolingo / Things 3 / Robinhood / Headspace / Apple system UI + web research (Mobbin MCP was unavailable — paid plan).

Stack reality (drives the recommendations below): **no framer-motion / gsap / spring lib** in `package.json`. Animations are CSS transitions / `@keyframes` / Tailwind 4 + R3F. So all timings below are written as plain CSS `transition` / Web Animations API values. Haptics on web = `navigator.vibrate()` (Android/Chrome only; iOS Safari ignores it — treat haptics as progressive enhancement, never load-bearing).

---

## 1. The core principle: delight is RARE, RESPONSE is CONSTANT

The single most-copyable Duolingo lesson: **separate two layers.**

- **Response layer (every interaction):** fast, cheap, near-instant. Press states, hovers, toggles. 80–150ms. Ease-out. NO bounce, NO confetti. This is 95% of touches and must feel _crisp_, not _bouncy_. Overshoot on every tap = UI feels unstable / cheap.
- **Celebration layer (rare milestones):** spring/overshoot, particles, sound, haptic. Reserved for genuine accomplishment moments only (lesson done, streak extended). If everything celebrates, nothing does.

Adopt for us: pressing a node, opening ToolDetail, typing in FindBar = **response layer** (snappy). Adding a tool successfully, "discovering" a new region of the universe, completing onboarding = **celebration layer**.

---

## 2. The 3D / tactile button ("Check" button) — our highest-value steal

Duolingo's button is the most imitated micro-interaction in mobile. Mechanics:

- Button has a **solid colored "base"/rim underneath**, offset vertically (the 3D lip). Classic values: face sits `4px` above a same-hue, darker base. CSS analog: `box-shadow: 0 4px 0 <darker>;` (a hard, 0-blur shadow — it's a _ledge_, not a soft drop shadow).
- **On press-down:** face translates down to meet the base — `transform: translateY(4px)` and the 4px ledge collapses to 0. Reads as physically depressing a key.
- **Timing:** press-down is near-instant (~**60–90ms**, ease-out). Release springs back slightly squishy. Duolingo pairs a `.bouncy` curve on release for the "squish."
- **Haptics:** a firmer tap on press-DOWN, a softer tap on RELEASE (two distinct events, not one).
- **Disabled state:** the ledge is removed and color desaturates — the button literally looks "flat / un-pressable." Affordance via depth.

Adopt for us (liquid-glass twist): our buttons are glass, not opaque. Re-create the ledge as a **bottom inner highlight + bottom drop edge** so glass still has a "lip." Press = `translateY(2–3px)` (subtler than Duo's 4px — glass should feel lighter than plastic) + briefly intensify the inner highlight (light "compressing"). Keep press-down ≤ 90ms.

Concrete CSS skeleton:
```css
.glass-btn {
  transition: transform 80ms ease-out, box-shadow 80ms ease-out, filter 80ms ease-out;
  box-shadow: 0 3px 0 rgba(0,0,0,.18), inset 0 1px 0 rgba(255,255,255,.5);
}
.glass-btn:active {
  transform: translateY(3px);
  box-shadow: 0 0 0 rgba(0,0,0,.18), inset 0 1px 0 rgba(255,255,255,.7);
}
```
Pair with `navigator.vibrate?.(10)` on pointerdown (progressive enhancement only).

---

## 3. Micro-interaction timing cheat-sheet (use these as our tokens)

| Interaction class | Duration | Easing | Notes |
|---|---|---|---|
| Button / toggle press, tap feedback | **80–150ms** | ease-out `cubic-bezier(0.4,0,0.2,1)` | the "response layer." No overshoot. |
| Hover / focus glow on a node | 120–200ms | ease-out | glass: animate the highlight, not position |
| State swap (correct/wrong, selected) | 150–250ms | ease-out | color + scale ≤1.04 |
| Modal / sheet present (ToolDetail, AddTool) | **300–400ms** | ease-out, or gentle spring | larger surface = slower; this is a "hero transition" |
| Celebration (success burst, streak) | 400–700ms total | **spring / overshoot** | the ONLY place overshoot is allowed |
| List item enter (stagger) | 200–300ms each, **40–60ms stagger** | ease-out | staggered reveal reads as "alive" |

Default easing for ~80% of everything = ease-out `cubic-bezier(0.4, 0, 0.2, 1)` (fast start = feels responsive, slow settle = feels natural). Reserve springs for celebration + sheet presents only.

Web Animations API spring substitute (no lib): a 2-keyframe overshoot — `scale: 1 → 1.12 → 1` over 450ms with `cubic-bezier(0.34, 1.56, 0.64, 1)` (the "back-out" curve) reads as a spring without a physics engine.

---

## 4. Haptic taxonomy (the discipline matters more than the API)

Duolingo's restraint: haptics map to _meaning_, not to _every touch_. Map iOS-style semantics → our `navigator.vibrate` enhancement:

| Moment | iOS generator (reference semantics) | Web vibrate fallback |
|---|---|---|
| Button press-down | `impactOccurred(.rigid/.medium)` | `vibrate(10)` |
| Toggle / selection snap into place | `selectionChanged()` | `vibrate(8)` |
| Successful add-tool / save | `notificationOccurred(.success)` (light double-tap) | `vibrate([12,40,12])` |
| Error / invalid (e.g. dup tool) | `notificationOccurred(.error)` (3 escalating taps) | `vibrate([20,60,20,60,30])` |
| Celebration / milestone | medium impact synced to the visual peak | `vibrate([10,30,10,30,40])` |

Rules: (1) haptic fires on the **physical event** (pointerdown), not on async success — except success/error which fire when the result lands. (2) Never haptic on scroll or passive motion. (3) Sync the celebration haptic to the _visual peak_ of the animation, not its start. (4) iOS Safari won't vibrate — so haptics must be additive sugar; the visual + (optional) sound must carry the meaning alone.

---

## 5. Progress feedback — show momentum, not just status

Duolingo never shows a bare "loading" or a static bar. Patterns to steal:

- **Animated fill, not jump.** Progress bars _slide_ to the new value over 300–600ms ease-out. The motion is the reward. After a correct answer the bar visibly _advances_ — the user watches their progress grow.
- **Anticipation overshoot on the bar.** Fill goes slightly past target then settles (back-out curve). Tiny, but reads as "earned."
- **Number count-up.** XP / counts tick up digit-by-digit (~600–800ms) rather than snapping. Use `requestAnimationFrame` ease-out interpolation.
- **Persistent streak / state in the chrome.** A small always-visible counter (streak flame) in the header creates a "don't break it" pull. For us: a subtle "tools mapped: N" or "regions explored" indicator in PlaygroundApp's header chrome — quiet, but it counts up with a little pulse when it changes.
- **Segmented progress for multi-step.** AddToolModal / onboarding: show discrete pips/segments that fill one-by-one, not a continuous bar. Discrete = "I completed a step" feels more rewarding than a sliver of a bar.

---

## 6. Celebratory moments — tasteful gamified delight

The lesson-complete screen is the template. Anatomy:

1. **Beat of anticipation** (~150–300ms hold) before the payoff — silence/stillness makes the burst land harder. Don't fire confetti the instant the tap registers.
2. **Character/mascot reaction** — Duo's owl reacts emotionally. We have no mascot, but the **universe itself is our character**: on a milestone, the graph can pulse/bloom outward, a node can "ignite," camera can do a tiny celebratory push-in (R3F: lerp camera 2–4% closer then back over ~600ms).
3. **Particle burst** — confetti/sparkles, but _brief_ (under ~1s) and physically plausible (gravity, varied velocity). For liquid-glass: prefer **light motes / glints / a bloom flare** over literal paper confetti — fits the aesthetic. Postprocessing bloom pulse on a node = on-brand "spark."
4. **Earned-value reveal** — XP/count-up animates AFTER the burst, not during.
5. **One clear forward CTA** ("Continue") — celebration ends decisively; no clutter.

Restraint rules: celebrate the **end of an effort arc** (added a tool, finished onboarding, first time opening a region), never trivial taps. Make the BIG moment (first success, streak save) bigger than routine ones — escalation keeps delight from going stale. Always provide a settle: the screen must come to rest, calm, ready for the next action.

Apply to AddToolModal success: brief hold → the new tool's node **blooms into the universe** with a bloom-flare + soft camera nudge + success haptic + count-up of total → toast/CTA. That single moment is worth more than ten subtle polish passes.

---

## 7. Empty / loading / error states (Duolingo never wastes a state)

- **Empty states are invitational, not apologetic.** Friendly one-liner + an illustration + a single primary action. For us: an empty/first-run universe should feel like "space waiting to be filled," with a gentle pulsing "add your first tool" affordance — not a sad "no data."
- **Loading = personality.** Skeletons that shimmer, or the mascot doing something. For us: nodes can drift/breathe while data resolves, so "loading" looks like the universe forming rather than a spinner.
- **Errors are gentle + recoverable.** Soft red, encouraging copy ("Not quite — try again"), error haptic, and the input stays so you can fix it. Never a dead-end or a scary modal.

---

## 8. What they HIDE vs SHOW (the taste signal)

**Show:** progress/momentum (bars, streaks, count-ups), immediate per-action feedback (green/red, sound, haptic), one clear next action, earned rewards revealed with a beat.

**Hide:** complexity & settings (buried in menus, never on the main path), failure framed as failure (reframed as "try again"), the machinery (no spinners-as-spinners, no raw error codes), too many choices at once (one primary CTA per screen; secondary actions de-emphasized or hidden behind "..."). Density is deliberately LOW per screen — generous spacing, big tap targets (≥44pt / ~48px), one idea at a time.

Adopt: keep PlaygroundApp's main canvas calm and uncluttered. Push config/secondary actions into the FAB menu / overflow, not onto the canvas. Big touch targets on nodes. One primary action visible at a time (FindBar's send, AddTool's confirm, ToolDetail's primary CTA).

---

## 9. Spacing / layout notes from this app family

- **Big, confident type & targets.** Primary CTAs are full-width-ish, tall (~52–56px), high-contrast, rounded (Duolingo ~`16px` radius; our glass can go softer/rounder). Generous internal padding.
- **Vertical rhythm in chunks of 8** (8/16/24/32). Section gaps 24–32px; intra-group 8–16px.
- **One accent action per view**, everything else recedes. Color is used sparingly to point at the next step (Duolingo green = "go"). For us, reserve our brightest glass/glow accent for the single primary action on each surface.
- **Bottom-anchored primary actions** (thumb reach) — matches our FindBar-at-bottom and argues for AddTool/ToolDetail primary CTAs pinned to the bottom.

---

## 10. Concrete adoption checklist for our app

1. **Tactile glass buttons** (FindBar send, AddTool confirm, ToolDetail CTA, FAB): add a press `translateY(3px)` + ledge-collapse + inner-highlight pulse, ≤90ms ease-out, + `vibrate(10)`. §2
2. **Timing tokens**: codify the §3 table as CSS custom properties (`--t-press: 90ms`, `--t-sheet: 360ms`, `--ease-out`, `--ease-back`). Use everywhere; ban ad-hoc durations.
3. **Sheet presents** (ToolDetail, AddToolModal): 300–400ms ease-out present, with content staggering in (40–60ms). §3
4. **Add-tool success = the celebration moment**: anticipation beat → node blooms into universe (bloom flare + camera nudge) → success haptic → total count-up → CTA. §6
5. **Progress as motion**: animate any bar/fill, count up any number, add a quiet streak/"tools mapped" counter in header chrome that pulses on change. §5
6. **Haptic discipline**: wire the §4 taxonomy as a tiny `haptics.ts` helper (press/select/success/error/celebrate) guarded by `'vibrate' in navigator`. Additive only.
7. **States with personality**: invitational empty universe, breathing-nodes "loading," gentle recoverable errors. §7
8. **Keep canvas calm**: one primary action per surface; secondary actions into FAB/overflow; big tap targets on nodes. §8

---

### Sources
- [Little touches, big impact — Duolingo micro-interactions (Medium)](https://medium.com/@Bundu/little-touches-big-impact-the-micro-interactions-on-duolingo-d8377876f682)
- [Duolingo button tactile interaction (60fps.design)](https://60fps.design/shots/duolingo-button-tactile-interaction)
- [Making a 3D button with haptic effect like Duolingo in SwiftUI (DEV)](https://dev.to/yossabourne/making-3d-button-with-haptic-effect-like-duolingo-in-swiftui-2mj9)
- [Replicating Duolingo's iconic button in pure CSS (Medium)](https://medium.com/@lilskyjuicebytes/clone-the-ui-1-replicating-duolingos-button-in-pure-css-bd37a97edb7e)
- [Duolingo button gist (SwiftUI)](https://gist.github.com/electricsidecar-dev/ec618885c08558948584e9ad35b60eff)
- [Mobile App Animation Guide: Timing, Easing (Appy Pie)](https://www.appypie.com/blog/mobile-app-animation-guide)
- [Designing delightful micro-interactions for mobile apps (Bootcamp/Medium)](https://medium.com/design-bootcamp/designing-delightful-micro-interactions-for-mobile-apps-e37ed8bea7bc)
- [What makes an app delightful — micromoments of joy (Bootcamp/Medium)](https://medium.com/design-bootcamp/what-makes-an-app-delightful-cc972ee381d1)
- [UIImpactFeedbackGenerator.FeedbackStyle (Apple Developer)](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator/feedbackstyle/soft)
- [How to generate haptic feedback with UIFeedbackGenerator (Hacking with Swift)](https://www.hackingwithswift.com/example-code/uikit/how-to-generate-haptic-feedback-with-uifeedbackgenerator)
