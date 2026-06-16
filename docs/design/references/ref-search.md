# Reference: Search & Command — Raycast, Linear, Arc, Superhuman

Research for the liquid-glass "AI tool universe" app. Focus: search bars, command palettes, result lists, keyboard + touch, empty/typing/loading states. Mobbin MCP was unavailable (paid plan required), so this combines deep product knowledge of these apps with sourced specifics (Superhuman's own engineering blog, a reverse-engineered Raycast design token doc, and cmdk — the headless library Linear/Raycast/Vercel/Arc all build on).

Sources at bottom. Where a number is sourced it's marked; where it's a well-established convention from the product or cmdk it's marked `[conv]`. Treat unsourced pixel values as starting points to tune in-context, not gospel.

---

## TL;DR — the 10 patterns to adopt

1. **One palette, invoked everywhere by one toggle key.** Same key opens and dismisses (Cmd/Ctrl+K on web; a persistent bottom search affordance on touch). Superhuman's core principle: every action lives in one place, reachable from any screen. For us: the FindBar IS the command palette — don't build two surfaces.
2. **Latency is the product.** Superhuman targets **50–60ms** internally for every action (the public "feels instant" threshold is 100ms; 50ms feels like the UI responds *before* you finish). Render the first results frame on the very next keystroke — never wait on network. Local fuzzy filter first, async enrichment after.
3. **Fuzzy, forgiving, ranked — not literal.** Match against title AND aliases/synonyms, case-insensitive. Superhuman uses the `command-score` algorithm with a **0.0015** acceptance threshold and per-command base scores so rarely-used items are filtered out until typed for. Adopt: every tool gets aliases (e.g. "GPT" → ChatGPT, "img gen" → image tools).
4. **Recency/usage boosts ranking.** Recently-used and frequently-used items float up with a score multiplier; explicit "follow" ordering pins hierarchy. Cold open should show *your* recent tools, not alphabetical.
5. **Always teach the shortcut.** Show the keyboard shortcut inline on the right of each row as a keycap chip (Superhuman's passive-learning loop: user sees the shortcut repeatedly via the palette, muscle memory forms, they graduate off the palette). Even on touch, show the chip as an affordance/identity marker.
6. **Group results with sticky-ish section headers.** cmdk convention: grouped items under quiet headings (e.g. "Recent", "Tools", "Actions", "Search the web"). Headers are muted, small, all-caps-ish; items are full-contrast.
7. **Imply more below the fold.** Superhuman deliberately cuts off the last visible row (shows ~5, clips the 5th) so the list reads as scrollable/infinite rather than complete. Cheap trick, big perceived-depth payoff.
8. **Keyboard is first-class, mouse/touch is parallel.** Arrow up/down to move, Home/End to jump, Enter to activate, Esc to dismiss (cmdk defaults). Hover and keyboard selection share ONE highlight state — moving the mouse and pressing arrows must not fight.
9. **Hide chrome, show content.** No visible filter toggles, no "advanced search," no result counts by default. The input + the list. Power lives in *what you type* (aliases, scopes), not in visible controls.
10. **Distinct, calm states.** Empty (pre-typing) = recents + suggestions, not a blank box. Typing = instant local filter. Loading (async) = keep showing prior results, add a thin top progress shimmer; never blank-flash. Zero-results = one quiet line + a fallback action ("Search the web for '…'", "Add this tool").

---

## Layout & dimensions

### Raycast (reverse-engineered tokens) — dark, dense, keyboard-grade
| Element | Spec |
|---|---|
| Palette container bg | `#0d0d0d` surface, 1px `#242728` hairline border, radius **10–16px** |
| Container padding | 0 — contents fill to the edges |
| Search input | height **36px** (44px for a larger "store" variant), padding **8×12px**, radius 8px, 16px/400 text |
| Input focus | border brightens to `rgba(255,255,255,0.16)` (no glow, just a hairline shift) |
| Result row | padding **6×10px**, radius 6px, row height **~28px**, 16px/400 text |
| Row hover/selected | bg lifts to `#121212` (one step up from container) — **same state for hover and keyboard** |
| Keycap chip | bg `#121212` w/ subtle top→bottom gradient (3D-key feel), text `#cdcdcd`, **13px**, padding **1×6px**, height ~20px, radius 4px |
| Inline gaps | 2 / 4 / 8 / 12px scale |
| Text hierarchy | primary `#ffffff`, body `#cdcdcd`, secondary/caption `#9c9c9d` |

Takeaways for us: rows are **dense (~28–36px)**, not chunky iOS-list tall. Selection is a *subtle one-step background lift*, not a heavy accent fill. Keycaps are small, gradient-filled, low-contrast. On touch we'll go taller (44px min hit target) but keep the visual lightness.

### Superhuman — "visually imposing" centered modal
- Large centered overlay covering a big slice of the screen (commands feel important, focused). Monospaced font in the input to "evoke directing a powerful machine."
- Shows ~5 commands, **clips the 5th** to imply more below.
- Each command: icon (left) · title · (matching alias in parens if matched via alias) · shortcut chip (right).

### Linear / Arc / cmdk — the shared skeleton
- Backdrop blur + dim, a single rounded card, input pinned to top of card, scrollable grouped list below.
- Common chrome: subtle backdrop blur, card with hairline border, grouped headings, keyboard-hint chips, a quiet footer hint row ("↑↓ to navigate · ↵ to select · esc to close").
- Headless cmdk handles filtering/keyboard/a11y; the look is entirely yours — so the *differentiator is material + motion*, which is exactly where our liquid glass should spend its budget.

---

## Motion & micro-interaction timing

These apps are deliberately *restrained* with motion in the palette (speed > flourish). Recommended budget for our liquid-glass version:

| Interaction | Spec | Notes |
|---|---|---|
| Palette open | **150–200ms** ease-out; scale 0.96→1.0 + opacity 0→1, backdrop blur/dim fades in parallel | iOS-native feel: `cubic-bezier(0.32, 0.72, 0, 1)` (the "iOS sheet" easing) |
| Palette dismiss | **120–150ms** ease-in, slightly faster than open | Asymmetry: exits feel snappier |
| Keystroke → results | **0ms perceptual** — re-filter synchronously on input; target <16ms (1 frame). Never animate row reorder during fast typing | Superhuman 50–60ms total-action budget |
| Selection move (arrow/hover) | highlight transition **80–120ms** ease, or instant if typing | Keep crisp; long transitions feel laggy under keyboard nav |
| Row reorder after async enrich | optional FLIP **180–220ms** ease-out, debounced ~150ms so it doesn't churn mid-type | |
| Loading shimmer | thin (2px) top bar or row skeleton, **looping ~1000–1200ms** | Only when async > ~150ms; otherwise don't show it |
| Empty→results first paint | no fade — snap content in; fading the list on every keystroke reads as slow | |

Rule of thumb borrowed from Superhuman: **if a transition delays the user seeing/acting on results, cut it.** Spend motion on open/close and on the glass material, not between keystrokes.

---

## Keyboard + touch

**Keyboard (cmdk conventions):**
- ↑/↓ move selection · Home/End jump to first/last · Enter activate · Esc dismiss · same toggle key (Cmd/Ctrl+K) opens & closes.
- Selection must wrap or clamp predictably; auto-scroll the selected row into view with a small margin.
- On dismiss, **restore focus** to the previously-focused element (Superhuman calls this out explicitly).
- Sub-actions: a secondary key (Raycast uses Cmd+K *inside* the palette) opens a per-item action menu — worth adopting as "long-press" on touch.

**Touch (our iOS target):**
- The bottom FindBar (ChatGPT-style) is the palette. Tapping it expands upward into the result sheet; the input stays pinned above the keyboard.
- Min **44px** hit targets for rows even if the visual row art is lighter/denser inside.
- **Long-press a result** = the keyboard "secondary action" menu (open / add to map / pin / share).
- Swipe-down on the sheet or tap backdrop to dismiss (mirrors iOS sheet); keep the dismiss gesture consistent with ToolDetail's brand window.
- Keep the shortcut keycap visible on touch as an *identity/affordance* cue even though it's not tappable — reinforces "this is a power tool" and aids users who'll later use a hardware keyboard (iPad).

---

## State design — empty / typing / loading / zero-results

| State | Show | Hide |
|---|---|---|
| **Empty (just opened, no query)** | "Recent" group (last-used tools) + a few "Suggested"/popular tools + top actions (Add tool, Browse all). Never a blank field. | Full catalog, alphabetical dumps, result counts |
| **Typing** | Instant local fuzzy filter; grouped (Recent matches → Tools → Actions → "Search the web for '…'"). Highlight the matched substring. If matched by alias, show `Title (alias)`. | Spinners, network waits, debounce-induced blanks |
| **Loading (async enrich)** | Keep prior results on screen; thin top shimmer or trailing row skeletons. Optimistically rank by local data first. | Blank screen / full-list spinner / layout collapse |
| **Zero results** | One quiet centered line ("No tools match '…'") + a primary fallback action: "Search the web for '…'" and "Add '…' as a new tool" (routes to AddToolModal). | Sad illustrations, long help text, dead-ends |

What they **hide vs show** (the meta-lesson): these apps hide *configuration* (no visible filters, scopes, toggles, counts, settings) and show *content + the next action*. Complexity is reachable by typing (aliases, prefixes like `>` for commands vs search), never by visible UI. Adopt a typed-scope convention if useful — e.g. plain text = search tools, `>` = run an action/command, `/` = filter by category — but keep it invisible until discovered.

---

## Direct recommendations for the liquid-glass AI-universe app

1. **Unify FindBar + command palette.** One surface. Bottom-anchored chat input on touch that expands into a grouped result sheet; Cmd/Ctrl+K toggles the same surface on web. Don't ship a separate palette and search.
2. **Glass is the differentiator, motion is restrained.** cmdk/Linear/Arc all look generic by default — our liquid glass on the card + selection-row is the moat. Spend material richness on the panel and the *selected* row (a brighter glass lift, ~one step up, not a saturated accent). Keep inter-keystroke motion at zero.
3. **Selection = subtle one-step background lift** (Raycast model: `#121212` over `#0d0d0d`), shared by hover+keyboard, with an 80–120ms ease. Avoid heavy accent fills — they read cheap and fight the glass.
4. **Dense rows on web (28–36px), 44px touch targets on mobile**, light keycap chips (13px, gradient, low contrast) right-aligned on every row.
5. **Recents-first empty state**, alias-rich fuzzy matching with a low acceptance threshold and usage-based ranking, substring highlight, and the "clip the last row" trick for perceived depth.
6. **Zero-results always offers a route out**: "Search the web for '…'" + "Add as new tool" → AddToolModal. Never a dead end.
7. **Open 150–200ms / dismiss 120–150ms** with iOS sheet easing `cubic-bezier(0.32,0.72,0,1)`, backdrop blur fading in parallel; consistent with ToolDetail's brand-window transitions.

---

## Sources
- Superhuman — [How to build a remarkable command palette](https://blog.superhuman.com/how-to-build-a-remarkable-command-palette/) (fuzzy matching, command-score 0.0015 threshold, ranking, clip-last-row, focus restore, monospaced input)
- [Superhuman: Speed as the Product](https://blakecrosley.com/guides/design/superhuman) (50–60ms internal latency target vs 100ms perceptual threshold; passive shortcut learning)
- [Mobbin glossary — Command Palette best practices](https://mobbin.com/glossary/command-palette) and [Superhuman Web Command Modal](https://mobbin.com/explore/screens/e36ea7b5-114b-43ff-84d2-3b3e344bbc7d)
- Raycast design tokens (reverse-engineered) — [awesome-design-md / raycast / DESIGN.md](https://github.com/VoltAgent/awesome-design-md/blob/main/design-md/raycast/DESIGN.md) (container, row, input, keycap dimensions & colors)
- cmdk (the library behind Linear/Raycast/Vercel/Arc) — [Building Command Menus with cmdk](https://dev.to/blockpathdev/building-command-menus-with-cmdk-in-react-45o3) (keyboard model, grouping, headless styling)
- [Command Palette — UX Patterns (Medium)](https://medium.com/design-bootcamp/command-palette-ux-patterns-1-d6b6e68f30c1)

> Note: Mobbin MCP returned "paid plan required," so screen-level pixel measurements from Mobbin couldn't be pulled directly. Raycast dimensions above are from a reverse-engineered token doc and should be tuned against the live product. Numbers marked as conventions reflect cmdk defaults and consistent behavior across these apps.
