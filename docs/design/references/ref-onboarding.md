# Reference: Onboarding & Empty States — Notion, Superhuman, Things

Research focus: first-run, empty states, contextual hints, progressive disclosure, what to show vs hide.
Source: deep product knowledge of these three apps + web research (Mobbin MCP gated behind paid plan — not used). Specifics below are calibrated to iOS-native feel; durations/easings are the target values to adopt, not all directly measured.

Goal for our app: a premium liquid-glass "AI tool universe". The universe (graph/bloom/force-field viz) is the hero. Onboarding must teach navigation + the chat/find + add-tool loop WITHOUT covering the universe in chrome. These three apps are the gold standard for "teach by doing, hide everything else."

---

## The three governing principles (steal these)

1. **Notion — Progressive disclosure + seeded content.** Never show the full toolset. Reveal one capability at a time, exactly when it's needed, and never start from a blank page — start from an editable example.
2. **Superhuman — The empty state IS the reward.** The "done" state is the most beautiful screen in the app (Inbox Zero photo + streak). Emptiness is celebrated, not apologized for. Onboarding builds *muscle memory* for a few keystrokes, not feature awareness.
3. **Things — Calm, generous, illustrative emptiness.** Empty views are quiet, centered, hand-drawn, single-sentence. No badges, no nags, no "0 items". Whitespace and one friendly line do the work.

---

## 1. First-run experience

### Notion (adopt: personalization → seeded workspace, not a tour)
- Signup asks 1–2 lightweight questions (use-case: personal / team / school). The answer **pre-selects ~5 templates** instead of dumping the full gallery. *Personalize, then narrow.*
- Lands the user inside a **fully-functional, pre-populated document** (a sample page they can edit/delete) — not an empty canvas. The example teaches structure by being structure.
- A **persistent checklist** ("Getting Started") sits in the sidebar with 3–5 concrete micro-actions, each phrased as the literal gesture: *"Type `/` for commands"*, *"Create a page"*. Checklist is dismissible and shows progress.
- No modal carousel of marketing screens. Teaching is embedded in the workspace.

**For us:** On first launch, ask one question (e.g. "What do you build with AI?" → image / code / writing / agents). Use it to pre-highlight 4–5 relevant tool nodes in the universe and pre-seed a small constellation so the graph is *never empty*. A dismissible "Getting Started" affordance (2–4 steps: *tap a node*, *ask the chat*, *add a tool*) lives in a corner, not a modal.

### Superhuman (adopt: muscle-memory over awareness)
- Onboarding historically = a 1:1 coaching session; the in-app equivalent is a **short, focused command tutorial** that teaches a *handful of keystrokes* (E to archive, etc.) by having you *do them on real data*, not read about them.
- Zero marketing slides. You're in the product on screen one. The tutorial is interactive practice, not narration.

**For us:** Teach the 2 gestures that matter — (1) tap/drag in the universe, (2) open the bottom find/chat bar — via one interactive "do it now" prompt each, on the live universe. Don't explain the 15 viz variants. Don't list features.

### Things (adopt: instant, illustrated, no friction)
- First launch drops you straight into **Today**, already showing a soft hand-drawn illustration + one encouraging line. No account wall, no tour, no permission spam up front. Permissions (notifications, calendar) are requested *contextually*, the first time the feature is touched.

**For us:** Land directly in the universe. Defer any permission/account asks until the moment they're needed (e.g. ask to save only when the user adds their first tool).

---

## 2. Empty states — the highest-leverage screens

> Empty/first-run states are among the **most-viewed** screens in any app. Treat each as a designed moment with: (a) orient, (b) show value, (c) one clear action.

### Pattern anatomy (composite of all three)
```
        ┌─────────────────────────┐
        │   [ illustration/icon ]  │   ← soft, on-brand, ~96–140px, centered
        │                          │
        │      One short line      │   ← title, 17–20pt semibold, calm tone
        │   (optional subline)     │   ← 13–15pt, secondary color, ≤2 lines
        │                          │
        │     [ primary CTA ]      │   ← single button, only when there's an action
        └─────────────────────────┘
              vertically centered
```

### Things — calm empty
- Centered illustration + a single warm sentence (e.g. an empty list shows a light line drawing, no "0 tasks", no error tone).
- **Never** shows raw "No items" / counts of zero. Silence + whitespace over labels.
- Completing all of Today's tasks triggers a **brief celebratory illustration** ("All done") — a small reward beat, then calm.

### Superhuman — empty as reward (the big idea)
- Reaching Inbox Zero shows a **full-bleed curated landscape/architecture/wildlife photo**, a **streak counter**, and a daily-changing image so emptiness is something you *chase*.
- Photo selection is deliberate: wide shots with depth / a vanishing point, rotated daily for surprise. Emotion is intentionally encoded into the "done" state to build habit.

### Notion — productive empty
- Empty page isn't blank: shows ghosted **"Type `/` for commands"** placeholder + template suggestions inline. The empty state itself teaches the primary input gesture.

**For us — three empty states to design:**
- **Empty universe (pre-seed instead):** never truly empty. If a user clears everything, show a faint constellation outline + one line: *"Your universe is quiet. Add a tool to light it up."* + single FAB pulse.
- **Empty search/chat result:** Notion-style — instead of "No results", offer the gesture: *"Nothing yet — try asking what a tool does, or `+` to add one."*
- **"Clean" / accomplishment state (Superhuman-style):** when the user finishes a flow (e.g. organized their stack, completed onboarding), reward with a brief liquid-glass shimmer + one celebratory line. Make the *successful* state the most beautiful frame in the app.

---

## 3. Contextual hints (show the gesture, at the moment)

- **Notion:** hints are literal gesture instructions embedded where the gesture happens (the `/` placeholder lives in the editor). Hint = the next action, phrased as the keystroke/tap.
- **Superhuman:** hints surface the *shortcut* inline next to the action. Teaches the fast path while you use the slow path.
- **Things:** almost no hints — relies on a discoverable, obvious model. The one teaching device is the seeded illustration.

**Rules to adopt:**
- One hint at a time. Never stack tooltips.
- Anchor the hint to the element it describes (coachmark on the node / FAB / chat bar), not a center-screen modal.
- Phrase as the action: *"Drag to orbit"*, *"Tap to open"*, *"Ask the universe…"* — verb first.
- Each hint is **dismiss-on-action** (doing the thing dismisses it) and **dismiss-on-tap-away**. Show a given hint at most once.
- Surface contextually (first time the user hovers near the find bar), not all on launch.

---

## 4. Progressive disclosure — what to show vs hide

| Show immediately | Reveal on first relevant moment | Hide until power-user / never on first run |
|---|---|---|
| The universe (hero) | Find/chat bar capability (after first node interaction) | The 15 viz variants / variant switcher |
| 1 tap + 1 drag gesture | "+ Add tool" (after exploring a few nodes) | Advanced filters, settings depth |
| One seeded constellation | Tool detail / brand window (on first node tap) | Account/permissions (until first save) |
| Dismissible 2–4 step checklist | Streak/reward state (on first completion) | Bulk/edit/management chrome |

- Default to the **simplest viz on first run**; the variant switcher is a power feature, not a first-run choice. (Notion never asks "which database view?" up front.)
- The header/FAB/nav should be **minimal on first launch** and can gain affordances as the user demonstrates competence (earned complexity).

---

## 5. Motion, timing & micro-interactions (target values)

Tuned for iOS-native + liquid-glass premium feel. Use these as defaults; verify on device.

- **Empty-state entrance:** illustration + text fade/translate-up. Duration **300–400ms**, ease-out (`cubic-bezier(0.16, 1, 0.3, 1)` — "iOS soft" / easeOutExpo-ish). Stagger title→subline→CTA by **~40–60ms**.
- **Coachmark/hint appear:** scale **0.96→1** + fade, **200–250ms**, ease-out. Dismiss: fade **150ms**.
- **Reward / accomplishment beat (Superhuman-style):** the celebratory image/shimmer should feel earned but not block — **400–600ms** reveal, then settle. Background photo cross-fade on daily change **~500ms**.
- **Action feedback must feel instant:** like Superhuman, the *state change* (node lights up, tool added) happens with **zero delay (0ms)** — the animation is *closure/polish layered on top*, never a blocking gate. Decouple "it happened" from "the pretty animation."
- **Checklist item complete:** checkmark draw-on **~250ms** + subtle haptic (`UIImpactFeedbackGenerator .light`).
- **Standard iOS easing reference:** ease-out for entrances, ease-in for exits, spring (response ~0.4s, damping ~0.8) for anything that should feel physical/liquid (node settle, FAB press).
- **Haptics:** light impact on hint-triggering taps and add-tool; success notification haptic on the accomplishment/reward state. Sparingly.

---

## 6. Gesture & layout specifics

- **Bottom-anchored primary input** (Superhuman/ChatGPT pattern): the find/chat bar lives at the bottom within thumb reach. Keep it as the persistent, always-available "talk to the universe" affordance.
- **Tap-away dismisses** any transient teaching layer (coachmark, checklist popover, tool detail) — never trap the user in onboarding.
- **Single FAB** for the one creative action (+ add tool), bottom-right, ~56–64px. Pulse it gently *only* in the empty-universe state to draw the first action.
- **Centered, vertically-balanced empty layouts** (Things): content sits at roughly optical center, generous top/bottom whitespace; illustration ~96–140px, ~16–24px gap to title, ~8px title-to-subline, ~24–32px to CTA.
- **Safe-area aware:** keep teaching chrome clear of notch/home-indicator; coachmarks respect safe-area insets.

---

## 7. What they deliberately HIDE (anti-patterns they avoid)

- No multi-slide marketing carousel before the product (all three skip it).
- No "0 items" / raw empty counts / error-toned blank screens (Things).
- No full feature tour or feature list on launch (Superhuman teaches ~a handful of keystrokes only).
- No full template gallery / settings dump up front (Notion narrows to ~5).
- No upfront permission/account walls (deferred to point-of-need).
- No simultaneous stacked tooltips.

---

## Adoption checklist for our app

- [ ] First launch lands directly in a **pre-seeded** universe (never empty), simplest viz variant.
- [ ] One lightweight personalization question → highlights 4–5 relevant nodes.
- [ ] Dismissible 2–4 step "Getting Started" checklist in a corner, verb-phrased, dismiss-on-action.
- [ ] Contextual coachmarks (one at a time, anchored, ≤once each) for: orbit-drag, tap-to-open, ask-the-bar, add-tool.
- [ ] Three designed empty states: quiet universe, productive empty-search (offer the gesture), **celebratory accomplishment** state.
- [ ] Make the *success/done* state the most beautiful frame (Superhuman-style reward beat + optional daily-changing liquid-glass backdrop + streak).
- [ ] Instant state change (0ms) + decoupled polish animation; entrances 300–400ms easeOut, hints 200–250ms, light haptics.
- [ ] Defer permissions/account to point-of-need.
- [ ] Hide: viz variant switcher, advanced filters, settings depth on first run.

---

### Sources
- [How Superhuman chooses Inbox Zero images](https://blog.superhuman.com/how-superhuman-chooses-inbox-zero-images/)
- [Superhuman: Speed as the Product](https://blakecrosley.com/guides/design/superhuman)
- [Superhuman Onboarding: Reach Inbox Zero Fast](https://blog.superhuman.com/the-fastest-way-to-inbox-zero-a-single-coaching-session/)
- [How Notion Crafts a Personalized Onboarding Experience (Candu)](https://www.candu.ai/blog/how-notion-crafts-a-personalized-onboarding-experience-6-lessons-to-guide-new-users)
- [Notion's lightweight onboarding (Appcues GoodUX)](https://goodux.appcues.com/blog/notions-lightweight-onboarding)
- [Empty State UI Design best practices (Mobbin glossary)](https://mobbin.com/glossary/empty-state)
- [Empty state UX examples and rules (Eleken)](https://www.eleken.co/blog-posts/empty-state-ux)
- [The UX of Empty States (Tim Graf)](https://timgraf.com/ui/the-ux-of-empty-states-designing-moments-of-nothing-into-something-exceptional/)
- Note: Mobbin MCP screen/flow search was attempted first but requires a paid plan; findings rely on product knowledge + the web sources above.
