# Component Inventory & States Review

Dimension: **component inventory & states**. Scope: shell files under
`src/playground/**` plus the in-app browser overlay. Reviewer pass over every
interactive element (buttons, chips, inputs, panels), the states each one
implements, and the states that are MISSING.

Legend for state coverage: ✅ present · ⚠️ partial / inconsistent · ❌ missing ·
n/a not applicable to this element.

---

## 1. Element-by-element inventory

| # | File | Element | default | hover | press/active | focus-visible | disabled | loading | empty | error | Notes / concrete fix |
|---|------|---------|---------|-------|--------------|---------------|----------|---------|-------|-------|----------------------|
| 1 | `PlaygroundApp.tsx:84` | **Add-tool FAB** (`+`) | ✅ | ✅ `hover:bg-white/[0.14]` | ✅ `active:scale-95` | ❌ no `focus-visible` ring | n/a | n/a | n/a | n/a | Keyboard users get no visible focus. Add `focus-visible:ring-2 focus-visible:ring-white/40 focus-visible:outline-none`. Also no entrance animation — FAB just pops; add a `motion-safe` rise on mount. |
| 2 | `PlaygroundApp.tsx:105` | **Variant nav tabs** (A–O) | ✅ | ✅ `hover:bg-white/10` | ❌ no press feedback | ❌ no `focus-visible` | n/a | n/a | n/a | n/a | Active tab has no press/active micro-effect (selecting feels instant/flat). Add `active:scale-[0.96]`. Selected state relies only on bg color — add `aria-current` / `aria-selected` for a11y. No `focus-visible` ring on the only keyboard nav surface. |
| 3 | `PlaygroundApp.tsx:98` header `<h1>/<p>` | **Header title block** | ✅ static | n/a | n/a | n/a | n/a | n/a | n/a | n/a | Non-interactive; fine. |
| 4 | `FindBar.tsx:281` | **Chat input** | ✅ | n/a | n/a | ✅ `focus:` ring+bg (driven by `focused` state) | ❌ never disabled | ❌ no loading | ✅ empty handled (history/recently-added) | ❌ no error state | Query is synchronous so loading is arguably n/a, but there's no max-length / overflow guard and no inline error if `runQuery` returns empty (the "no match" answer is pushed as a turn, OK). Input is never disabled during/after submit — acceptable. Consider `enterKeyHint="search"` and `inputMode` for iOS keyboard polish. |
| 5 | `FindBar.tsx:295` | **Submit button** (`↑`) | ✅ | ✅ `hover:scale-105` | ✅ `active:scale-[0.88]` | ❌ no `focus-visible` ring | ✅ `disabled:opacity-40` + `disabled:scale-100` | ❌ no loading spinner | n/a | n/a | Good press/disabled coverage. Missing `focus-visible`. No loading is OK (sync) but if query ever becomes async this needs a spinner state. |
| 6 | `FindBar.tsx:211` | **Answer match chips** | ✅ | ✅ `hover:-translate-y-0.5` | ✅ `active:scale-[0.96]` | ❌ no `focus-visible` | n/a | n/a | n/a | n/a | Strong press effect already. Missing keyboard focus ring. Long-press peek is pointer-only — no keyboard equivalent for the secondary action. |
| 7 | `FindBar.tsx:249` | **"Recently added" history chips** | ✅ | ✅ `hover:-translate-y-0.5` | ✅ `active:scale-[0.96]` | ❌ no `focus-visible` | n/a | n/a | ✅ this IS the empty state | n/a | Same as #6: add `focus-visible`. This block renders only when `history.length>0`; when there are turns AND no history the bar shows just the input — acceptable. |
| 8 | `FindBar.tsx:317` | **Peek scrim button** (long-press overlay) | ✅ | n/a | n/a | ❌ | n/a | n/a | n/a | n/a | Whole scrim is a `<button>` wrapping a `<div role="button">` — nested interactive elements (a11y/HTML validity issue). The inner "Open" is a `div role=button` with keyboard handler but the outer is a real button — Tab order is muddy. Fix: make scrim a non-button overlay with `onClick`, and make the Open control a real `<button>`. |
| 9 | `FindBar.tsx:336` | **Peek "Open" action** | ✅ | ✅ `hover:bg-white` | ✅ `active:scale-[0.96]` | ⚠️ `role=button`+keydown but no `focus-visible` ring | n/a | n/a | n/a | n/a | Should be a native `<button>` (see #8). Add visible focus ring. |
| 10 | `FindBar.tsx` thread container | **Conversation thread (swipe-to-dismiss)** | ✅ | n/a | ⚠️ drag transform | n/a | n/a | n/a | ✅ collapses when empty | n/a | Swipe-down clears ALL turns at once with no undo and no confirm — destructive. Consider dismissing only visually / add an undo toast, or a small "clear" affordance instead of full wipe on a 90px drag. Grab handle (`:188`) is decorative only. |
| 11 | `ToolDetail.tsx:286` | **Close button** (`✕`) | ✅ | ✅ `hover:bg-white/10` | ✅ `active:scale-90` | ❌ no `focus-visible` | n/a | n/a | n/a | n/a | Add focus ring. Otherwise complete. |
| 12 | `ToolDetail.tsx:378` | **"Open ⟨tool⟩ ↗" CTA** | ✅ | ✅ `hover:bg-white` + sheen sweep | ✅ `active:scale-[0.98]` | ❌ no `focus-visible` | ❌ no disabled when no URL (it's just hidden) | ❌ no loading while iframe boots | n/a | n/a | Primary action. After click the in-app browser opens an iframe with NO loading indicator (see #19). Add focus ring. Consider a pressed/"opening…" state to bridge the gap before the overlay appears. |
| 13 | `ToolDetail.tsx:445` (`ConnectionChip`) | **Connection chips** | ✅ | ✅ `hover:-translate-y-0.5` | ✅ `active:scale-95` | ❌ no `focus-visible` | n/a | n/a | n/a | n/a | Best-covered chip in the app. Only gap: keyboard focus ring + no keyboard path to long-press peek. |
| 14 | `ToolDetail.tsx:517` (`PeekBubble`) | **Peek bubble** (auto-dismiss) | ✅ | n/a | n/a | ❌ | n/a | n/a | n/a | n/a | Entire bubble is a `<button>` that closes on click; fine, but auto-dismisses in 2.2s with no pause-on-hover/focus — keyboard or slow readers can't act on it. Add hover/focus to cancel the auto-dismiss timer. |
| 15 | `ToolDetail.tsx` panel | **Detail panel (drag-to-dismiss)** | ✅ enter/exit anim | n/a | ⚠️ drag transform | n/a | n/a | n/a | ✅ returns null when no tool | n/a | No `Escape`-to-close handler here (AddToolModal has one; ToolDetail does NOT). Add `Escape` close + focus trap for parity. Drag is touch-only — desktop has only the ✕. |
| 16 | `AddToolModal.tsx:335` | **Text input** | ✅ | n/a | n/a | ✅ `focus:border/bg/shadow` | ❌ never disabled | n/a | ✅ empty → placeholder + helper copy | ❌ no inline validation on the text itself | Solid focus styling. No error state for an unclassifiable / empty paste (submit just no-ops). Consider `enterKeyHint="done"`. |
| 17 | `AddToolModal.tsx:324` | **Modal close** (`✕`) | ✅ | ✅ `hover:bg-white/10` | ✅ `active:scale-[0.9]` | ❌ no `focus-visible` | n/a | n/a | n/a | n/a | Add focus ring. |
| 18 | `AddToolModal.tsx:430` | **"Upload icon" button** | ✅ | ✅ `hover:bg-white/10` | ✅ `active:scale-[0.96]` | ❌ no `focus-visible` | ❌ never disabled | ❌ no loading while FileReader runs | ⚠️ success → "Image set ✓" (no way to clear) | ✅ error via `imageError` block (`:419`) | Has a success label and an error path — good. Missing: a loading/reading state (large image read is async, button stays idle), and no "remove image" affordance once set. Add focus ring. |
| 19 | `AddToolModal.tsx:439` | **"Add to map" submit** | ✅ | ✅ `hover:bg-white` + shadow | ✅ `active:scale-[0.96]` | ❌ no `focus-visible` | ✅ `disabled:opacity-40` + `disabled:scale-100` + `disabled:shadow-none` | ❌ no loading | n/a | n/a | Best-covered button (disabled fully styled). `addTool` is sync so loading is n/a today. Missing focus ring. |
| 20 | `AddToolModal.tsx:393` | **"Already on the map" match chips** | ✅ | ✅ `hover:bg-white/[0.09]` | ✅ `active:scale-[0.96]` | ❌ | n/a (cursor-default, non-nav) | n/a | n/a | n/a | These are `<span>` not `<button>` — they have press visuals + long-press peek but are NOT keyboard-focusable and have no role. Either make them real buttons or drop the interactive affordances. Peek state (`peekId`) styling is good. |
| 21 | `AddToolModal.tsx:312` | **Grab handle** | ✅ | n/a | ✅ `active:cursor-grabbing` + `group-active:bg-white/40` | n/a | n/a | n/a | n/a | n/a | `group-active:` won't fire — the `.group` class is not on the handle's parent (it's a bare `<div>`). The color-change press effect is dead. Add `group` to the handle wrapper or move the active style onto the handle itself. |
| 22 | `AddToolModal.tsx:275` | **Scrim / backdrop** | ✅ click-to-close | n/a | n/a | n/a | n/a | n/a | n/a | n/a | Fine. Opacity tracks drag — nice. |
| 23 | `InAppBrowser.tsx:33` | **In-app browser "Close"** | ✅ | ✅ `hover:bg-white/[0.12]` | ✅ `active:scale-95` | ❌ no `focus-visible` | n/a | n/a | n/a | n/a | Add focus ring. No `Escape` to close the overlay. |
| 24 | `InAppBrowser.tsx:41` | **`<iframe>` content area** | ✅ | n/a | n/a | n/a | n/a | ❌ **no loading state** | n/a | ❌ no error/blocked-by-CSP fallback | Major gap: many sites set `X-Frame-Options`/CSP and will render a blank white iframe with no message. Add a spinner overlay until `onLoad`, and an `onError`/timeout fallback ("Couldn't embed — open in a new tab") with an external-link button. |

---

## 2. Cross-cutting findings (priority order)

### A. Missing `focus-visible` rings — EVERY interactive element (highest impact)
Not a single button/chip in the shell defines a `focus-visible` style. For an
App-Store-grade product this fails basic keyboard accessibility and looks
unfinished on desktop Tab navigation. Add a shared utility, e.g.
`focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/40
focus-visible:ring-offset-1 focus-visible:ring-offset-[#03040a]`, applied to:
FAB, variant tabs, both submit buttons, all chips, all close buttons, the
in-app-browser Close. The chat input and AddToolModal input already style
`focus:` correctly — bring buttons up to the same bar.

### B. Press / micro-animation gaps
- **Variant nav tabs** (`PlaygroundApp.tsx:105`) — no `active:` press effect at
  all; the primary navigation feels flat. Add `active:scale-[0.96]` and a brief
  selected-tab spring.
- **Add-tool FAB** — no entrance animation; pops in. Add a `motion-safe` rise.
- **AddToolModal grab handle** — its `group-active:bg-white/40` press color is
  dead (no `.group` ancestor); the press affordance never shows.

### C. Loading states missing where they matter
- **In-app browser iframe** (`InAppBrowser.tsx:41`) — no loading spinner, no
  CSP/blocked fallback. This is the single most visible "loading" gap: tapping
  "Open" can yield a blank white box.
- **AddToolModal "Upload icon"** — `FileReader` read is async with no progress
  state; large images appear to do nothing for a beat.
- FindBar submit and "Add to map" are synchronous today, so no spinner needed —
  but both are one refactor away from needing it; note for whoever wires a real
  backend.

### D. Non-button interactive elements (a11y + correctness)
- `AddToolModal.tsx:393` match chips are `<span>` with press visuals + long-press
  but no role and not focusable.
- `FindBar.tsx:317` peek scrim is a `<button>` wrapping a `<div role="button">`
  (nested interactives) and `:336` Open is a `div role=button` not a `<button>`.
Fix both: native `<button>` for actionable controls, plain overlay for scrims.

### E. Missing `Escape` / focus-trap parity
`AddToolModal` traps focus and handles `Escape`. **`ToolDetail` does neither** —
opened over the map it can't be dismissed by keyboard and doesn't trap focus.
Add `Escape`-to-close and a focus trap to ToolDetail and to the InAppBrowser
overlay.

### F. Destructive action without confirm/undo
`FindBar` swipe-down clears the entire conversation (`setTurns([])`) on a 90px
drag with no undo. Consider an undo toast or a lighter dismiss.

### G. Error / empty-state coverage
- Good: AddToolModal image error block, FindBar empty (history) state, FindBar
  "no match" answer, ToolDetail null-guards.
- Missing: iframe error/blocked fallback (#24), no inline error when a paste
  can't be classified, no "remove uploaded image" path once set.
