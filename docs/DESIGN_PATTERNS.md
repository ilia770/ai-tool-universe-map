# iPhone overlay patterns — concrete sources

Working notes on what we are deliberately cribbing from premium iOS
apps, screen by screen. Pair this with `DESIGN_TOKENS.md` (the
visual language) and `PHASE_2_PLAN.md` (the build order).

Each section follows the same shape: **What we're stealing →
Source app(s) → How it maps onto My AI Map**. No vague "feels like
ChatGPT"; every reference points at a specific gesture or visual.

## 1. Bottom sheet with three detents

**Steal**: a single sheet that grows in three predictable steps —
peek (one line + drag handle), mid (chips + active filters),
expanded (full tool detail). Detent transitions are physics-based,
not duration-based.

**Sources**:
- **Apple Maps** — peek/mid/expanded; mid stops at ~40 %, expanded
  fills under the status bar.
- **Find My** — same three detents, less ornament. Closer to what
  we want on the iPhone home screen.
- **Things 3** — sheet edges round more aggressively (`24 pt`),
  inner padding stays a constant `16 pt` across detents. We use
  the same.

**On My AI Map**:
- Peek: "Founder OS · 8 categories · 49 tools" + drag handle.
- Mid: category rail + lens controls (clarity, stage filter).
- Expanded: selected tool detail (logo, summary, classifier
  confidence, related tools).

SwiftUI primitive:

```swift
.sheet(isPresented: $sheetVisible) {
    SheetContents()
        .presentationDetents([.height(120), .fraction(0.5), .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)
        .presentationCornerRadius(BrandRadius.card.value)
        .presentationBackground(.thinMaterial)
}
```

## 2. Input bar above the keyboard

**Steal**: the Liquid Glass intake field hovers above the keyboard
on iPhone instead of pushing the universe up. The way ChatGPT,
Claude, and Perplexity do it.

**Sources**:
- **ChatGPT iOS** — leading attachment, trailing send button, the
  whole bar drops with a spring on submit.
- **Perplexity** — same shape but with a `+` model picker on the
  left; we copy the picker idea for category hinting.

**On My AI Map**:
- Anchored to `safeAreaInset(edge: .bottom)`.
- Leading `wand.and.stars` icon shows "rule-based draft → AI later"
  in a tooltip on long-press.
- Submitting fires the `medium` haptic + scrolls the universe to
  the classified tool's pocket.

## 3. Command palette as a search dock

**Steal**: tap the search field, the sheet collapses to peek and a
results dock appears, like Linear's iPhone command bar. Selecting
a result moves the camera; pressing Return focuses the first
match (mirrors the web app's Enter shortcut).

**Sources**:
- **Linear iOS** — the dimmer behind the dock keeps the universe
  faintly visible; results are pills with subtle bg, never opaque
  rows.
- **Raycast on Mac** — same pattern, different platform; the
  result-row hover state is what we want for the focused item.

**On My AI Map**:
- Drop the search dock at `safeAreaInset(edge: .top)`, with the
  bottom sheet collapsing to peek automatically.
- Each row shows the tool logo (SF Symbol fallback), category
  chip, stage tag.

## 4. Quiet keyboard shortcuts on iPad

**Steal**: the small semi-transparent overlay that appears when
you hold the Command key (Things 3 / Mail).

**Sources**:
- **Things 3 iPad** — every shortcut listed, no animation jank.
- **Mail iPad** — uses `UIKeyCommand`, we'll use SwiftUI
  `.keyboardShortcut(...)` and let the system render the cheat
  sheet.

**On My AI Map (iPad only)**:
- `⌘F` → focus map, `⌘C` → context, `⌘A` → atlas (mirrors the
  F/C/A keys on the web build).
- `⌘K` → command palette (search dock).
- `⌘W` → close the dialog (parity with Esc).

## 5. Pocket-world reveal animation

**Steal**: the way Maps zooms into a transit stop — the rest of
the world fades a little, the focused area scales up, never a
straight cut.

**Sources**:
- **Apple Maps (transit pin tap)** — exactly what we want for a
  category-ring tap.
- **Photos slideshow Ken-Burns** — for the slow camera drift while
  a pocket is open.

**On My AI Map**:
- Tap a category chip or scroll-zoom past the threshold (same
  `enterDistance = 11` as the web build).
- RealityKit `CameraComponent` lerps over `BrandMotion.flow`
  (0.36 s smooth) to the pocket's `categoryPosition`.
- Sister entities dim via `CustomMaterial` opacity tween to
  `0.18` so they read as "behind glass".

## 6. Floating tool inspector on hover (iPad / Vision Pro)

**Steal**: the way visionOS hover effects communicate
interactivity — a 6 % brightness lift + 1 px outer stroke.

**Sources**:
- **visionOS native apps** — `.hoverEffect(.lift)` is the system
  primitive; works on iPad with a pointer too.

**On My AI Map**:
- ToolNode entities expose a `HoverEffectComponent` (RealityKit)
  so the simulator + iPad pointer + visionOS path all use the
  same code.

## 7. Adaptive layout — iPad split view

**Steal**: NavigationSplitView with a sidebar that hides itself in
compact width; what Mail and Notes do.

**Sources**:
- **Apple Notes iPad** — sidebar collapses below `694 pt` width;
  the universe panel takes the centre, the detail panel becomes
  a sheet.
- **Things 3 iPad** — keeps the sidebar visible longer but
  exposes a single hamburger button to dismiss it.

**On My AI Map (iPad)**:
- Sidebar: categories + intake + search.
- Centre: universe canvas.
- Detail: selected tool, slides in from the right; collapses to a
  sheet under `694 pt`.

## 8. Empty states that teach the gesture

**Steal**: the cue chips that appear under the universe before the
user tries anything. Same approach as Apple Maps' "Try '...'"
suggestions.

**Sources**:
- **Apple Maps search empty state** — three rounded chips
  ("Coffee", "Gas", "Hotels") with subtle SF Symbol icons.
- **Things 3 empty Inbox** — the "Add task" hint sits above the
  bottom bar with low contrast text.

**On My AI Map**:
- Below the peek sheet on first launch: three chips —
  "Zoom into Coding", "Try classifying youtube.com", "Press ⌘F
  for focus" (iPad).
- Dismiss permanently after first successful interaction; persist
  the flag in `UserDefaults`.

## 9. Haptic + sound pairings

**Steal**: the tiny `tick.up.fill` sound on AirPods Pro paired
with a soft impact haptic for "selected".

**Sources**:
- **Camera shutter** — heavy haptic + capture sound; we mirror
  this for a confirmed classify.
- **Settings toggles** — light haptic + tiny click; we mirror this
  for chip selection.

**On My AI Map**:
- Sound effects are off by default. Provide a Settings toggle
  that flips on a small library of `SystemSoundID` cues; the
  haptic pairings always fire.

## 10. Onboarding — three swipes max

**Steal**: every premium iOS app respects "no more than three
screens before you're in the product". Linear, Things 3,
Streaks all keep onboarding to a single screen with a swipeable
explainer.

**Sources**:
- **Linear iOS onboarding** — single screen, three feature
  highlights with hairline dividers, "Get started" CTA pinned
  bottom.
- **Things 3 first launch** — a single screen + one toast hint;
  no other interruption.

**On My AI Map**:
- Phase 4 only — three swipeable cards:
  1. "Zoom into a category to reveal its pocket world."
  2. "Paste a URL → instant rule-based classification."
  3. "Custom tools live on this device (iCloud-synced in a future
     release)."
- Pinned "Get started" CTA jumps straight into the universe.

## Sources to actually study on Mobbin

When Mobbin access is available, capture screen flows from these
apps as PNGs into `docs/design-refs/`:

| App | Mobbin path | Why |
| --- | --- | --- |
| Apple Maps | Maps → Search | Sheet detents, transit zoom. |
| ChatGPT | Onboarding + Chat | Input bar above keyboard. |
| Linear | Inbox → Triage | Command palette dock. |
| Things 3 | Today screen | iPad sidebar, keyboard cheat sheet. |
| Find My | Devices map | Three-detent sheet at minimum ornament. |
| Notes | Sidebar split view | NavigationSplitView responsive behavior. |

Each capture should land alongside a one-line note explaining what
the gesture is doing — not just the still frame.

## Anti-patterns

Things we explicitly will **not** copy:

- Cramming controls into a hamburger menu. Use the bottom sheet
  detents or a tab bar.
- iOS dock-style icon trays (sidebar bottoms on iPad). They look
  decorative and are hard to thumb-reach.
- Auto-scrolling onboarding videos. They block the gesture.
- "Tap anywhere to dismiss" overlays without a visible affordance.
  Always show the dismiss arrow / Done button.
