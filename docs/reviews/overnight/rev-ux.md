# Overnight Review — UX Flows & Information Architecture

Reviewer dimension: UX flows & IA. Scope: `src/playground/**` shell
(`PlaygroundApp.tsx`, `FindBar.tsx`, `ToolDetail.tsx`, `AddToolModal.tsx`,
`store.tsx`, `query.ts`) plus `components/InAppBrowser.tsx`.

Method: walked each flow end-to-end (add-tool, ask-the-map, open brand window,
history, switch variant, open link) and traced what the user sees, where they
get stuck, and what is redundant or mistimed.

---

## Flow 1 — Add a tool (FAB → AddToolModal → detail)

**1a. Dead-end: "Add to map" gives no confirmation that the add landed in the map.**
`AddToolModal.submit()` (`AddToolModal.tsx:214`) calls `addTool`, then
`onAdded?.(tool.id)` opens the brand window (`PlaygroundApp.tsx:92`). The user is
dropped straight into ToolDetail — but the *visualization behind it* never
acknowledges the new node (no pan/flash/highlight to where it landed). The whole
pitch ("the classifier places it") is invisible. After closing the detail panel
the new tool is just one of dozens of identical dots. Fix: after add, briefly
pulse/scale the new node in the active variant, or have ToolDetail show a one-line
"Added to <Category> · <Stage>" banner that ties back to the map position.

**1b. Redundant + confusing: silent dedupe swallows the user's intent.**
`store.addTool` (`store.tsx:62-94`) returns the *existing* tool if the slug/name/
domain already matches, and `AddToolModal` then opens that tool's detail with no
message. Combined with the live "Already on the map" chips (`AddToolModal.tsx:389`),
the user can type "Perplexity", see it listed as already-present, yet still press
"Add to map" and be silently routed to the existing entry. The button should
either disable / relabel to "Open Perplexity" when `matches` contains an exact
identity match, or the modal should toast "Already on the map — opening it."

**1c. "Already on the map" chips are a dead-end — they look tappable but aren't.**
The match chips (`AddToolModal.tsx:394-413`) are `<span>`s with `cursor-default`,
active-scale styling, and a long-press peek that only reveals the text "· already
added". They give hover/active feedback like buttons but do nothing on tap, and
the long-press payload is a tautology. Either make them open the existing tool
(tap → `onAdded(m.id)` + close) or strip the button-like affordances so they read
as static labels.

**1d. Confidence % is shown but never explained or acted on.**
The preview shows "· 73% match" (`AddToolModal.tsx:373-379`) with a bump
animation, but a low confidence has no consequence — the tool is added to the
guessed category regardless, and there is no way to correct the category/stage if
the classifier is wrong. For a "premium" feel either (a) let the user tap the
category pill to override the guess before adding, or (b) drop the number, since a
percentage the user can't influence reads as noise.

**1e. Icon upload affordance is buried and its paste path is undiscoverable.**
Paste-an-image is wired on the whole dialog (`onPaste`, `AddToolModal.tsx:309`),
and the only hint lives in the long helper paragraph (`:384`) that *disappears the
moment the preview renders* — i.e. once you type a name (the common case) the
paste hint is gone. The "Upload icon" button sits bottom-left next to "Add to map"
with equal weight, competing with the primary action. Move icon handling into the
preview row (tap the logo to replace) so it is contextual and the footer holds
only the primary CTA.

---

## Flow 2 — Ask the map (FindBar chat)

**2a. No empty-state guidance the first time; "Recently added" only appears after you add.**
`history` is `tools.filter(t => t.userAdded)` (`FindBar.tsx:72`), so on first run
the area above the input is blank — no example prompts, no starter chips. The only
hint is the input placeholder. A premium "ask anything" surface should seed 2-3
tappable example questions (e.g. "build a database fast", "edit video", "research
tool") that pre-fill or run the query. Right now the marquee feature looks dead
until the user guesses what to type.

**2b. Chat thread has no per-turn dismissal and the only clear is a hidden gesture.**
The thread can only be wiped by swiping it down past 90px (`endThreadDrag`,
`FindBar.tsx:149` → `setTurns([])`) — an all-or-nothing, undiscoverable gesture
(the grab pill at `:188` is the only signal, and on desktop/mouse the drag is
disabled entirely at `:127`, leaving *no* way to clear history with a mouse).
There's no "new chat" / clear button and no way to remove a single bad turn. Add a
visible clear/close control on the thread header, and a desktop affordance.

**2c. Zero-result answer points to the + button, but the + is a bare glyph with no label.**
`runQuery` returns "Try the + button to add one" (`query.ts:73`) — but the FAB
(`PlaygroundApp.tsx:84`) is an unlabeled "+" in the opposite corner (bottom-right)
from where the user is reading (bottom-center input). The text references a control
the user must hunt for. Either make the zero-state answer render an inline "Add it"
button that opens the modal pre-filled with the query, or stop referencing "the +
button" by name.

**2d. Matched-tool chips and the answer text duplicate the same names.**
The answer string already names the top tool and "Also worth a look: X, Y"
(`query.ts:79-83`), and then the same tools repeat as chips below
(`FindBar.tsx:208-239`). The prose names aren't tappable while the chips are, so
the user sees each name twice with different affordances. Drop the names from the
prose tail (keep just the "why") and let the chips be the single tappable surface.

**2e. FindBar fully unmounts when a tool window opens — the conversation is lost on close.**
`{detailId ? null : <FindBar/>}` (`PlaygroundApp.tsx:95`) unmounts FindBar whenever
a detail panel is open, and because `turns` is component-local state it is
**destroyed**. Open a result → read it → close the window → your whole Q&A thread
is gone. This breaks the core "ask, browse results, come back, ask again" loop.
Lift `turns` to PlaygroundApp (or just hide FindBar with CSS instead of
unmounting) so the conversation survives opening a tool.

---

## Flow 3 — Open the brand window (ToolDetail)

**3a. Interim (un-enriched) tools collapse to a near-empty, sad panel.**
For any tool without an `ENRICHED` record — which includes *every user-added tool*
— `k.enriched` is false, so Killer features / Strengths / Watch-outs / Who-uses-it
all render `null` (`ToolDetail.tsx:304-346`). The panel shows only "What it does"
(often just the classifier's one-line `reason`), a "Pricing: unknown / Pricing not
yet researched" card (`:351-352`), and maybe connections. A user who just proudly
added a tool opens a window that looks broken/empty. Either hide the Pricing
section entirely when unknown (don't show an empty stub), or show an explicit
"Not yet researched — here's what we inferred" state so the emptiness is intentional.

**3b. "Open <tool> ↗" is absent for most seed tools, with no explanation.**
The Open CTA only renders when `tool.url` exists (`ToolDetail.tsx:378`). Many seed
tools have no URL, so the panel simply ends after connections with no way to reach
the actual product — the single most likely next action is missing and unexplained.
For seed tools, derive a URL from `logoDomain`/name or show a disabled "Link
coming soon" so the action slot is never silently empty.

**3c. Two different long-press "peek" patterns coexist and conflict in mental model.**
FindBar long-press opens a full-screen modal peek (`FindBar.tsx:316`), AddToolModal
long-press toggles inline chip text (`AddToolModal.tsx:262`), and ToolDetail
long-press shows a 2.2s auto-dismissing bubble pinned to the panel bottom
(`ToolDetail.tsx:471-540`). Three inconsistent results from the same gesture. Worse,
in ToolDetail a *short tap* on a connection chip already navigates to that tool —
so the long-press peek is a redundant slower path to information you get faster by
just tapping. Recommend dropping the ToolDetail peek bubble entirely; tap-to-open
is enough.

**3d. Connections list has no categories/grouping and no count cap.**
`connections` renders every related tool as a flat chip wall
(`ToolDetail.tsx:357-375`). With no grouping by category or "why connected" label,
a tool with 8+ relations becomes an undifferentiated blob. Consider grouping by
category color or annotating the relation type.

---

## Flow 4 — History / recently-added

**4a. "History" is only ever 6 user-added tools and vanishes the moment you ask anything.**
`history` is capped at the last 6 `userAdded` tools (`FindBar.tsx:72`) and is
rendered *only* when `turns.length === 0` (`FindBar.tsx:245`). So: (1) it's not
query history, it's add history — mislabeled mentally; (2) the instant you ask one
question it's replaced by the thread and there's no way back to it; (3) since
`turns` dies when a tool opens (see 2e), after browsing you land back on history
with no trace of what you asked. There is effectively no durable history of either
questions or visited tools. Add a real "recently viewed tools" list (persist
opened ids) and keep it reachable, e.g. as a collapsed row even while a thread is
open.

**4b. No persistence — refresh wipes everything the user built.**
`added` and `icons` live in `useState` (`store.tsx:52-53`); nothing is written to
`localStorage`. Every added tool, icon, and the whole session evaporates on reload.
For an app that invites "build your universe," this is the biggest IA dead-end.
Persist the added-tool list + icon map.

---

## Flow 5 — Switch variant (top nav)

**5a. 15 equally-weighted tabs in a horizontal scroller bury the finalists.**
The nav renders all 15 variants with identical styling in one overflow-x strip
(`PlaygroundApp.tsx:103-119`). The brief calls A/K/N/O the finalists, but nothing
signals that — the user must scroll a long ribbon of cryptic codenames
("J · Cosmograph", "I · WizMap") with no notion of which to try. For an App-Store
product this is a developer debug menu leaking into the UX. Either hide the lab
switcher behind a settings/long-press gesture, or promote the 3-4 finalists and
fold the rest under a "More" disclosure.

**5b. Variant codenames + blurbs are insider jargon shown in the header.**
The header subtitle prints `active.label.split('·')[1]` + blurb
(`PlaygroundApp.tsx:101`), e.g. "Cosmograph — GPU force graph · Obsidian on
steroids". This is engineer-facing copy ("Obsidian on steroids", "Neo4j Bloom")
surfaced as the app's main title area. Replace with a user-facing description of
what the current view *does for them*, or remove the subtitle in shipping mode.

**5c. Switching variant silently keeps an open detail/chat from the previous view's context.**
`select()` (`PlaygroundApp.tsx:61`) only changes `activeId`; it doesn't reset
`detailId` or clear the chat. Switching the entire visualization underneath an open
brand window is jarring and the new variant won't reflect/animate the selection.
Consider closing the detail panel on variant switch, or re-focusing the selected
node in the new variant.

---

## Flow 6 — Open external link (InAppBrowser)

**6a. Many target sites will render a blank frame — a true dead-end with no fallback.**
The in-app browser loads the URL in a sandboxed `<iframe>`
(`InAppBrowser.tsx:41-48`). Most real tool sites (OpenAI, Figma, Notion, Vercel,
etc.) send `X-Frame-Options: DENY` / CSP `frame-ancestors`, so the frame comes up
white and the user is stuck staring at a blank box with only a "Close" button — no
error, no "Open in new tab" escape hatch. Add an "Open in new tab ↗" link in the
header and/or detect load failure and fall back to `window.open`.

**6b. No address bar, back, reload, or progress — it reads as broken mid-load.**
The chrome is title + url + Close (`InAppBrowser.tsx:26-39`). There's no loading
spinner, so on a slow site the white iframe (6a) is indistinguishable from a
failure. At minimum add a loading indicator and an external-open affordance.

**6c. Closing the in-app browser is fine, but opening one over an open ToolDetail stacks two dismiss models.**
The browser is `z-[80]` (`InAppBrowser.tsx:24`) over ToolDetail's `z-20`. Closing
the browser returns to the detail panel, which is correct — but the detail panel's
swipe-to-dismiss and the browser's tap-scrim/Close are different gestures layered
on top of each other. Ensure Escape consistently closes only the topmost layer
(currently AddToolModal handles Escape, but ToolDetail and InAppBrowser do not bind
Escape at all — `ToolDetail.tsx` / `InAppBrowser.tsx` have no key handler).

---

## Cross-cutting IA findings

- **No global Escape contract.** AddToolModal traps + handles Escape
  (`AddToolModal.tsx:140`), but ToolDetail and InAppBrowser have no Escape binding.
  On desktop the only close is the ✕ or a mouse-disabled swipe. Add Escape-to-close
  to every dismissible layer; define a single top-of-stack handler.
- **Two competing dismiss gestures with different thresholds** (ToolDetail right/
  down 120/140px at `ToolDetail.tsx:213`, AddToolModal down 110px at
  `AddToolModal.tsx:19/245`, FindBar thread down 90px at `FindBar.tsx:149`). Three
  numbers for "the same" swipe-away. Unify the threshold and direction.
- **FAB position fights the chat input.** The "+" FAB (bottom-right,
  `PlaygroundApp.tsx:84`) and the FindBar input (bottom-center→right edge of a
  max-w-xl bar) are both anchored bottom; on a phone the FAB can overlap the chat
  bar's send button. Verify on a 390px viewport; consider moving Add into the chat
  bar as a leading "+" affordance so there's one bottom command surface.

---

## Top priorities (if only a few get fixed)

1. **2e + 4b** — chat/history is destroyed on tool-open and on refresh. The core
   loop (ask → open → return → ask) is broken and nothing persists.
2. **6a** — external links open into a blank, escape-less iframe for most real
   sites. The final "go use the tool" step dead-ends.
3. **3a/3b** — brand window for user-added (and url-less seed) tools looks empty,
   showing "Pricing not yet researched" stubs and no Open button.
4. **5a/5b** — the 15-tab lab switcher + engineer codenames are debug UI in the
   shipping shell; demote to the finalists with user-facing copy.
5. **1a/1b** — adding a tool gives no map-side acknowledgement and silently
   dedupes, so the headline "paste it, we place it" payoff is invisible.
