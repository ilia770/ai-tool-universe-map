# Reference: Detail Sheets & Cards — App Store, Linear, Arc, Things

Research focus: bottom sheets / side panels, detail layouts, swipe-to-dismiss, grabber handles, section hierarchy, hide/reveal of secondary info. Goal: extract **reusable, adoptable** patterns for our liquid-glass "AI tool universe" app (ToolDetail.tsx brand window, AddToolModal, FindBar bottom chat).

> Note: Mobbin MCP was paywalled at research time, so this is built from deep first-hand knowledge of these apps + Apple HIG (Sheets) and UISheetPresentationController specifics, confirmed via web search. Numbers marked ~ are observed/estimated; HIG-confirmed items are noted.

---

## 0. TL;DR — what to adopt for ToolDetail

1. **Two-detent bottom sheet** (`medium` ≈ 50%, `large` ≈ 92%) with a **grabber** that both drags AND taps-to-cycle. This is the single most reusable pattern. (HIG-confirmed.)
2. **Dismiss = swipe down**, not a close button as primary. Keep a top-left/top-right "Done"/× as secondary for accessibility, but the gesture is the headline interaction.
3. **App Store "above-the-fold" header**: icon + name + one-line subtitle + a single primary action button, all visible before any scroll. Everything else is progressively revealed below.
4. **Section hierarchy by whitespace, not lines**: group with ~24–32px vertical gaps and lightweight section labels; avoid heavy dividers (Things/Linear style).
5. **Hide secondary info behind "more"**: truncate long description to 3 lines with an inline **"more"** affordance (App Store pattern); reveal in place, no navigation.
6. **Rubber-band + velocity-aware dismiss**: drag tracks the finger 1:1, past-end resistance, and a flick past ~25% height OR downward velocity > threshold commits the dismiss.

---

## 1. Apple HIG ground truth (the substrate all four sit on)

Source: [Apple HIG — Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), [UISheetPresentationController](https://www.avanderlee.com/swift/presenting-sheets-uikit-uisheetpresentationcontroller/), [NN/g Bottom Sheets](https://www.nngroup.com/articles/bottom-sheet/).

- **Detents** are heights where a sheet "naturally rests." System defines `medium` (~half height) and `large` (fully expanded). Custom detents allowed (iOS 16+ fractional/absolute).
- **Grabber**: a small grey rounded capsule at the top center. Shows resizability, **tap cycles through detents**, and is VoiceOver-operable. Include it whenever the sheet is resizable.
- **Swipe-to-dismiss is expected**: users swipe vertically down to dismiss rather than hunting a button. If there are **unsaved changes**, intercept and show a confirm action sheet instead of silently discarding.
- **Don't offer medium detent when content needs full height** (e.g. Messages/Mail compose are large-only). Implication for us: AddToolModal (a form) should be **large-only**; ToolDetail (browse) benefits from medium+large.
- The sheet animates between detents with a **spring** (UIKit `animateChanges`); without it the sheet jumps. Default system feel is a gentle spring, not a linear tween.

### Grabber spec (reusable values)
- Capsule: **36×5pt**, ~`rgba(0,0,0,0.18)` light / `rgba(255,255,255,0.3)` dark, fully rounded (`border-radius: 2.5px`).
- Sits ~**6–8px** from the sheet's top edge, horizontally centered.
- Hit target is larger than the visual (full sheet-width top strip, ~44px tall) so the drag is forgiving.

---

## 2. App Store — the product detail page (closest analog to ToolDetail)

The App Store product page is our **primary reference** because each app card → detail is structurally identical to tool card → ToolDetail.

### Layout (top → bottom)
1. **Hero header (above fold, no scroll)**: large rounded app icon (~`118pt`, `~22% corner radius`), app **name** (bold, ~28pt), **subtitle/tagline** (one line, secondary color), then a row of: **price/GET button** (pill, filled accent) + **share** icon. Below that a thin row of utility actions.
2. **Stats strip**: horizontally-scrolling row of metric cells separated by hairline vertical dividers — Rating (★ + count), Age, Chart Rank, Category, Developer, Language, Size. Each cell = small label (top, uppercase, ~11pt, tertiary) + bold value (~17pt). **This is a great pattern for tool metadata** (model size, modality, pricing tier, popularity).
3. **Screenshots carousel**: edge-to-edge horizontal paging, rounded corners, peeks the next item ~16px to signal scrollability.
4. **Description**: clamped to **3 lines** with an inline **"more"** link (accent color, right-aligned at end of clamp). Tapping expands **in place** — no push navigation.
5. **Ratings & Reviews**, **What's New** (with version + date), **Information** table (key/value rows), **Related** rails.

### Reusable takeaways
- **Single primary CTA** in the hero. We have one too ("Open" / "Add to my universe" / website). Don't compete it with multiple equal-weight buttons.
- **Metadata as a scrollable stat strip** beats a dense table for glanceability.
- **"more" inline expansion** is the canonical hide/reveal for long prose — adopt for tool descriptions.
- **Peeking carousel** (next item visible by ~16px) is the cheapest "there's more →" affordance.
- **Sticky condensed header on scroll**: as you scroll, App Store collapses the big icon+name into a compact title bar with the GET button migrating up into the nav bar. Adopt: ToolDetail's grabber-area can morph into a compact sticky title + primary action once the user scrolls past the hero.

---

## 3. Things 3 — task detail "card" (the gold standard for calm hierarchy)

Things' task detail is famous for **opening in place**: tapping a row makes the row **expand into an editable card** with a smooth height animation, pushing siblings down — it does NOT navigate to a new screen.

### Motion / interaction
- **Magic open**: row expands ~**0.30–0.35s**, ease-out-ish spring, siblings slide down in the same gesture. The card feels like it "grew" from the row, preserving spatial context. This is the *Things "Magic Plus"/expand* signature.
- Tapping outside or pulling down collapses it back into the row with the inverse animation.
- **No grabber, no chrome**: the card is borderless; separation is pure whitespace + a faint background tint shift.

### Section hierarchy (what to copy)
- **Title** (large, bold) → **Notes** (multiline, placeholder "Notes") → **metadata chips** (When / Deadline / Tags / Checklist), each a tappable lightweight pill, NOT a labeled form field.
- Secondary actions (deadline, repeat, move) are **hidden behind small icon affordances** in a bottom toolbar that only appears when the card is open. **Hide vs show**: only Title+Notes are always visible; scheduling/tagging is revealed on demand via the toolbar.
- Generous line-height, ~**16–20px** between logical groups, **zero divider lines**.

### Reusable takeaways
- **Expand-in-place over navigate** for our cards where context matters (e.g. a tool node expanding within the universe view rather than a hard modal) — strongly reinforces the "spatial" universe metaphor.
- **Chips instead of form rows** for editable metadata.
- **Reveal the action toolbar only in the open state.**

---

## 4. Linear (mobile) — issue detail (structured metadata done right)

Linear's mobile issue view is a full-screen detail (push), but its **properties panel** and **section model** are highly reusable for ToolDetail's structured data.

### Layout
- **Title** at top (large, editable inline).
- **Properties row(s)**: compact pill chips for Status, Priority, Assignee, Labels, Project — each with a tiny glyph + text, horizontally wrapping. Tapping a chip opens a **focused bottom sheet picker** (medium detent) for just that property. **This is the "drill into one field via a small sheet" pattern** — much lighter than a full settings screen.
- **Description** (markdown), then **Activity/Comments** stream at the bottom.
- **Sub-sheets stack**: picking a property slides up a secondary sheet over the detail; dismiss returns you exactly where you were.

### Motion
- Property-picker sheets animate up ~**0.25–0.3s** with a spring; selecting a value auto-dismisses the sheet (no explicit confirm) — fast, low-friction.
- Status/priority changes animate the chip's color/glyph with a quick **~150ms** cross-fade for satisfying feedback.

### Reusable takeaways
- **Property chips → tap → focused medium-detent picker sheet → auto-dismiss on select.** Perfect for AddToolModal field editing (category, modality, pricing).
- **Stacking sheets** (detail sheet → property sub-sheet) keeps context; budget z-index/scrim for it.
- **Instant optimistic feedback** on the chip (color/icon) the moment a value is chosen.

---

## 5. Arc Search / Arc (mobile) — playful, gesture-first sheets

Arc leans into **bottom sheets and swipe gestures** as the primary navigation, with heavy use of **liquid/blurred backgrounds** — directly aligned with our liquid-glass aesthetic.

### Patterns worth stealing
- **Blurred, translucent sheet material**: sheet background is a heavy backdrop-blur of the content behind it, with a subtle inner top highlight (1px white @ ~8% opacity) to catch the "glass" edge. This is exactly the surface treatment for our ToolDetail window.
- **Swipe-up to reveal more / swipe-down to dismiss** as a fluid continuum — the same gesture that dismisses also resizes; there's no hard mode switch.
- **Pull-to-dismiss with content scaling**: as you drag the sheet down, the underlying page **scales back up** (the "card came from behind" depth cue), and the sheet's corner radius can grow slightly while dragging. Adopt: on drag-down, scale the background universe from `0.92 → 1.0` to reinforce that the detail "lifted out" of the graph.
- **Rounded, floating sheet** (not edge-anchored): inset from screen edges by ~**8–12px** with a large corner radius (~`38px` on modern iOS "floating" sheets), so it reads as an object hovering over the universe, not a drawer welded to the bottom.

### Reusable takeaways
- **Glass material recipe**: backdrop-blur ~`30–40px` + `~70–80%` translucent fill in our accent-tinted dark + 1px top inner highlight + soft drop shadow (large blur, low opacity).
- **Background depth coupling**: tie sheet drag progress to background scale/blur for a premium "lifted out of the graph" feel — very on-brand for an AI *universe*.
- **Floating inset sheet** with big radius beats bottom-welded for a jewel-like object.

---

## 6. Cross-app synthesis — concrete spec for OUR ToolDetail / sheets

### Detents
- **ToolDetail (browse)**: two detents — `medium` ≈ `52vh`, `large` ≈ `92vh`. Open at `medium`; the hero (icon, name, tagline, primary CTA) fits in `medium` above the fold; scrolling or dragging to `large` reveals description, capabilities, related tools.
- **AddToolModal (form)**: **large-only** (HIG: don't offer medium when content needs height). Optionally `large` + a small `~30%` "minimized" peek if we want a save-draft affordance.
- **FindBar**: stays a docked input; if it expands into a result sheet, use `medium` detent rising over the universe.

### Grabber
- `36×5px` capsule, top-center, ~`8px` inset. Light: `rgba(255,255,255,0.35)` over our dark glass. Tap cycles detents; large drag hit area (~44px strip).

### Motion & timing (adopt these defaults)
- **Present (open)**: spring, ~**0.35s** perceived. R3F/Framer: `type:"spring", stiffness: 380, damping: 36` (a snappy-but-soft iOS feel) OR cubic-bezier `(0.32, 0.72, 0, 1)` over `~0.4s` (this curve is the de-facto "iOS sheet" easing used by Vaul/iOS-style libs).
- **Dismiss**: same curve, slightly faster ~**0.25–0.3s**.
- **Detent change (medium↔large)**: spring ~**0.3s**, `stiffness: 300, damping: 30`.
- **Drag tracking**: 1:1 with finger; **rubber-band** past the top (resistance ~0.55 of overdrag).
- **Commit-to-dismiss thresholds**: dismiss if dragged past **~25%** of sheet height OR release velocity **> ~500 px/s** downward. Otherwise snap back to nearest detent.
- **Inline "more" expand**: height auto-animate ~**0.25s** ease-out; never navigate.
- **Property chip pickers (à la Linear)**: sub-sheet up ~**0.28s** spring, **auto-dismiss on select**, chip cross-fades value ~**150ms**.
- **Background depth coupling (Arc)**: map drag-down progress `0→1` to universe `scale 0.92→1.0` and `blur 8px→0`.

### Layout & spacing
- **Floating inset sheet**: ~`10px` side insets, corner radius ~`32–38px`, glass material (§5).
- **Hero block (above fold)**: tool icon ~`72–96px` rounded ~22%, name (~24–28px bold), one-line tagline (secondary), single primary CTA pill. Share/secondary actions smaller, to the side.
- **Stat strip** (App Store style): horizontal scroll of metric cells — modality, pricing tier, model family, popularity — uppercase ~11px label over ~17px bold value, hairline dividers between.
- **Section rhythm**: ~`24–32px` vertical gap between groups, lightweight uppercase section labels, **whitespace over divider lines** (Things/Linear). Use a divider only between truly distinct zones.
- **Metadata as chips** (Things/Linear), not labeled form rows.

### Hide vs show (the editorial decision)
| Always visible (above fold) | Revealed on demand |
|---|---|
| Icon, name, one-line tagline | Full description (clamp to 3 lines + "more") |
| Single primary CTA | Capabilities / detailed specs (scroll to `large`) |
| Top 3–5 metadata chips in stat strip | Secondary actions (share/report/edit) in a toolbar shown only when expanded |
| Grabber (resize affordance) | Related tools rail (lower in scroll) |
| | Property editors (open focused sub-sheet per field) |

### Accessibility / robustness
- Keep a visible secondary dismiss (× or "Done") alongside the swipe gesture (HIG: grabber + gesture are primary, but provide explicit control).
- **Unsaved-changes guard** on AddToolModal: intercept swipe-down dismiss → confirm action sheet (HIG-confirmed pattern).
- Respect `prefers-reduced-motion`: drop springs to short fades, kill background scale coupling.

---

## 7. Quick adoption checklist for the codebase

- [ ] ToolDetail.tsx → convert to a **floating glass bottom sheet** with `medium`+`large` detents + grabber (tap-cycles).
- [ ] Hero block: icon + name + tagline + single CTA, fits in `medium` above fold.
- [ ] Description → 3-line clamp + inline "more" (animate height, no nav).
- [ ] Tool metadata → horizontal **stat strip** of chips.
- [ ] Drag: 1:1 tracking, rubber-band, dismiss at 25%/500px·s⁻¹, snap-to-detent spring `(380/36)` or bezier `(0.32,0.72,0,1)`.
- [ ] Couple drag progress to background universe scale `0.92→1.0` + blur.
- [ ] AddToolModal → **large-only**, unsaved-changes confirm on swipe-dismiss.
- [ ] Field editing (category/modality/pricing) → Linear-style **property chips → focused medium sub-sheet → auto-dismiss on select**.
- [ ] Glass material: backdrop-blur ~`30–40px`, ~`75%` tinted dark fill, 1px top inner highlight, soft large-blur shadow.

---

### Sources
- [Apple HIG — Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
- [Presenting sheets with UISheetPresentationController — Antoine van der Lee](https://www.avanderlee.com/swift/presenting-sheets-uikit-uisheetpresentationcontroller/)
- [Bottom Sheets: Definition and UX Guidelines — NN/g](https://www.nngroup.com/articles/bottom-sheet/)
- First-hand analysis of App Store, Things 3, Linear (mobile), Arc Search detail/sheet UIs (Mobbin MCP unavailable — paywalled).
