# Reference: AI Chat Apps — ChatGPT, Claude, Perplexity

Design research for our liquid-glass "AI tool universe" chat surface (`FindBar.tsx`).
Focus: chat input bar, message bubbles, streaming/typing, suggested prompts,
result/source cards, send affordance.

> Mobbin MCP was unavailable (paid plan required); this is built from direct
> knowledge of the three apps plus targeted web research. Specifics are
> calibrated to iOS-app conventions and our existing tokens. Sizes/durations
> are "adopt these" targets, not pixel-exact reproductions.

Sources:
- [BGR — ChatGPT app redesign (simplified composer, Aug 2025)](https://www.bgr.com/1933698/chatgpt-app-redesign-ahead-of-gpt-5-release/)
- [OpenAI Apps SDK — UI guidelines](https://developers.openai.com/apps-sdk/concepts/ui-guidelines)
- [Unusual.ai — Perplexity citation-forward design](https://www.unusual.ai/blog/perplexity-platform-guide-design-for-citation-forward-answers)
- [NextLeap — Perplexity UI for citations & follow-ups (case study PDF)](https://assets.nextleap.app/submissions/LIP3PerplexitysUIforcitationsandfollow-ups-Shalini-dab5b065-328a-4c1c-b3e8-5915c832f8bf.pdf)
- [Bestfolios — Designing Better AI Chat (deep dive)](https://medium.com/bestfolios/designing-better-ai-chat-a-deep-dive-part-1-of-2-0c578ebef618)
- [Streamdown — per-word streaming animation docs](https://streamdown.ai/docs/animation)
- [Anthropic — Artifacts GA](https://www.anthropic.com/news/artifacts)

---

## 1. Chat input bar (composer)

### What the three apps converged on (2025)

- **Pill-shaped composer, pinned to bottom**, sitting above the home
  indicator with safe-area padding. Corner radius is large/continuous
  (24–28px, effectively a stadium for single-line state). Our FindBar
  already uses `rounded-3xl` (24px) — keep it.
- **Three-zone layout: [leading icon] [text field] [trailing affordance].**
  ChatGPT's Aug-2025 redesign collapsed all modes into ONE leading `+`
  button (files, images, tools, connectors), with **dictate + voice-mode**
  on the right. The lesson: **hide capability behind a single `+`; show only
  text + send by default.** Don't line up 4–5 visible icons.
- **Single-line by default, grows to multi-line.** Composer starts ~44–52px
  tall (one line + vertical padding ≈ 11–14px top/bottom). It auto-grows up
  to a cap (~5–6 lines / ~40% of viewport), then the inner field scrolls.
  Our input is fixed single-line `py-2.5` — **upgrade to a `textarea` with
  auto-grow + max-height** for parity.
- **Placeholder is quiet** (~white/35–40 opacity), sentence case, action-
  oriented ("Ask anything"). Ours ("Ask the map — e.g. …") is on-brand;
  keep it short on small screens (truncate the example).

### Send affordance — the most copyable detail

- **Send button morphs with state**, it is never just enabled/disabled:
  - **Empty field** → send is hidden or shown as a low-contrast mic/voice
    icon (ChatGPT shows voice; Claude shows a dimmed up-arrow).
  - **Has text** → circular **filled** button appears with an **up-arrow
    (↑)**, high contrast (white-on-dark or accent fill). This is exactly
    our pattern (`bg-white/90 text-black`, ↑). Good.
  - **Streaming/generating** → the SAME button becomes a **stop square (■)**.
    Tapping cancels generation. **We are missing this** — add a stop state.
- **Transition between states**: quick scale+cross-fade, ~150–200ms,
  ease-out. The icon swap should feel like a morph, not a pop. Our
  `findbar-bump` (300ms) + `active:scale-[0.88]` is in the right spirit.
- **Button size**: 36–40px diameter tap target inside the pill; ours is
  `h-10 w-10` (40px) — correct, keep ≥40px for touch.
- **Haptic**: light impact on send (we fire `haptic(10)`), light tick on
  state change. Keep haptics ≤16ms.

### Adopt for FindBar
- Convert input → auto-growing `textarea` (1 line → ~5 line cap).
- Add **stop (■) state** to the send button while `runQuery` "streams".
- Consider a leading `+` slot reserved for future actions (even if it only
  re-focuses today) to match the mental model — but only if it earns its
  place; don't add a dead button.

---

## 2. Message bubbles

### The key asymmetry (all three apps)

- **User messages = bubbles.** Right-aligned, contained, tinted fill,
  rounded with a "tail" corner (one corner less-rounded toward the avatar/
  edge). Max width ~80–85% of column. Our user turn does exactly this:
  `ml-auto max-w-[85%] rounded-2xl rounded-br-md bg-white/[0.12]`. 
- **Assistant messages = NOT bubbles** (this is the pro move). ChatGPT and
  Claude render assistant text as **near-full-width plain text on the page
  background**, no container fill, so long answers + markdown + code read
  like a document. Only short/system replies get a subtle surface.
  - Our assistant turn currently uses a bubble (`bg-white/[0.05]
    rounded-bl-md`). For short answer + chips that's fine and on-brand for
    a glass card. **But if answers grow longer, drop the assistant fill**
    and let text run wider (≈90–95%) for readability.
- **Vertical rhythm**: ~16–24px gap between turn groups; ~6–8px between a
  message and its own attached cards/chips. Ours: `space-y-3` (12px)
  between turns, `space-y-1.5` (6px) within a turn — slightly tight on the
  outer gap; consider 16px between turns.
- **Type**: body ~15–17px, line-height ~1.4–1.5. User bubble text often
  one step smaller than assistant. Ours is `text-sm` (14px) — fine for a
  compact overlay, but bump answer body to 15px if vertical space allows.

### What they hide vs show
- **No timestamps** inline (chat-app convention dropped for AI chat — keeps
  it clean). Don't add them.
- **No avatars per message** in modern ChatGPT/Claude mobile; identity is
  implied by alignment. We already omit avatars — good.
- **Actions (copy, retry, thumbs) are hidden until needed** — revealed on
  long-press / row hover, or shown as a small row beneath the LAST
  assistant message only. Lesson: don't clutter every message with a
  toolbar; surface actions contextually.

---

## 3. Streaming / typing

### Pattern
- **Stream tokens progressively** (don't wait for the full answer). The
  perceived-speed win is large; users read "the system is alive."
- **Reveal style**: two dominant options —
  1. **Per-word fade-in** (Streamdown/modern Claude feel): each word mounts
     with opacity 0→1 over ~**200–400ms**, ease-out, no layout jump. Feels
     premium and smooth.
  2. **Char-by-char typewriter + blinking caret** (classic ChatGPT). Caret
     is a 1–2px block or `▍`, blink ~**1s steps(2)** (0.5s on / 0.5s off).
- **Pre-first-token state**: a **3-dot pulsing "thinking" indicator** (dots
  scale/opacity stagger, ~**1.4s loop**, 0.16s stagger between dots), OR a
  shimmer/breathing block. Shows the moment between send and first token.
- **Auto-scroll**: pin to bottom WHILE streaming, but **release auto-scroll
  the instant the user scrolls up** (don't fight them); show a "jump to
  latest" affordance instead. Our FindBar auto-scrolls on new turn — add
  the "don't yank during user scroll" guard if we stream token-by-token.

### Adopt for FindBar
- Since `runQuery` is on-device/instant, we can **simulate** a short stream
  for premium feel: reveal the answer with a **per-word fade** (200–300ms,
  `cubic-bezier(0.22,1,0.36,1)` — the easing we already use) and stagger
  words ~12–20ms. Cheap, very high polish.
- Add a **brief "thinking" 3-dot pulse** (~300–500ms) before the answer
  paints, so query→answer doesn't feel like a hard cut.
- While "streaming," send button shows **■** (see §1).

---

## 4. Suggested prompts (empty state) & follow-ups

### Empty-state prompt suggestions
- **ChatGPT/Claude empty state** = a few **tappable suggestion cards/chips**
  (3–4 max) that pre-fill the composer. Cards are short, verb-led
  ("Summarize a document", "Help me write…"). On tap they either fill the
  input or submit immediately.
- Layout: either a **2×2 card grid** (ChatGPT) or a **wrapping chip row**
  (lighter). Chips: pill, subtle border, ~13px text, ~32–40px tall.
- Our empty state shows "Recently added" tool chips — same gesture (tap to
  open). Good reuse. Consider also seeding **2–3 example queries** as chips
  that pre-fill the composer ("find a tool to build a database fast"),
  matching the "suggested prompts" mental model and teaching the input.

### Follow-up questions (Perplexity's signature)
- **After an answer completes**, Perplexity shows **auto-suggested follow-up
  questions as a vertical list of pill rows** with a leading `+` and a
  divider above ("Related"). They appear **only after streaming finishes**
  (sequenced, not during).
- Tapping a follow-up runs it as the next turn. This is a strong
  **engagement loop** we can mirror: after a tool answer, offer 2–3
  follow-ups like "Show alternatives", "What connects to this?", "Cheaper
  options" — generated from the matched tools' graph edges.

### Adopt
- Add 2–3 **example-query chips** to the empty state (pre-fill composer).
- After an answer with matches, render **1–3 follow-up pills** ("Show
  alternatives", "What connects to X") under the chips, revealed AFTER the
  answer paints (stagger ~45ms, our `findbar-chip` keyframe already does
  this).

---

## 5. Result / source cards (Perplexity + ChatGPT search)

### Perplexity source cards — the reference standard
- **Inline citations** = small superscript number pills `¹ ²` in the answer
  text, tinted with the accent (Perplexity uses teal sparingly). Tappable;
  scroll/jump to the matching source.
- **Source cards** = **horizontal scrollable strip** (or a "Sources" header
  with a count) ABOVE or beside the answer. Each card shows:
  **favicon + domain + short title/excerpt**, ~rounded-12px, compact
  (~120–160px wide in the strip), subtle border, low-contrast fill.
- **Reading column** is capped (~**680–720px** max-width) for legibility
  even on wide screens — answers never run full-bleed.
- **Sequencing**: source cards **slide/fade in as citations are generated**,
  follow-ups appear last. Motion telegraphs provenance.

### Map to our tool chips
- Our matched-tool chips ARE our "source/result cards." To level them up
  toward Perplexity quality:
  - Add a **favicon/logo** (we have `ToolLogo` / Logo.dev) + name + 1-line
    category, instead of name-only. Turns a chip into a scannable card.
  - For >3 matches, use a **horizontal scroll strip** (snap), not a wrap,
    to echo the source-strip pattern and save vertical space in the 33vh
    thread.
  - Keep the **inline-reference** idea: if the answer text names a tool,
    make that token a tappable accent-tinted pill that opens its window
    (mini "citation").

---

## 6. Motion / micro-interaction timing cheat-sheet

Calibrated to these apps + our existing easing
`cubic-bezier(0.22,1,0.36,1)` (a great iOS-feeling ease-out we already use):

| Interaction | Duration | Easing | Notes |
|---|---|---|---|
| Composer focus (border/glow) | 250–300ms | ease-out | We use 300ms — keep |
| Send icon state morph (↑ ↔ ■) | 150–200ms | ease-out | scale + cross-fade |
| Press feedback (button) | 80–120ms | ease-out | `active:scale ~0.88–0.96` |
| Message/turn enter | 350–460ms | `(0.22,1,0.36,1)` | translateY 8–12px + fade |
| Chip/card stagger | 40–60ms each | same | cap stagger count (~6) |
| Per-word stream fade | 200–300ms | ease-out | stagger 12–20ms/word |
| Thinking 3-dot pulse | 1.2–1.4s loop | ease-in-out | 0.16s dot stagger |
| Caret blink | 1s | `steps(2)` | 0.5s on / 0.5s off |
| Sheet/peek present | 350–420ms | `(0.22,1,0.36,1)` | matches our `findbar-peek` |
| Swipe-dismiss settle | ~420ms | `(0.22,1,0.36,1)` | matches our thread spring |

Our keyframes (`findbar-rise/turn/chip/peek`) are already well-tuned and
on-spec; reuse them rather than inventing new timings.

---

## 7. Gestures & state

- **Swipe-down-to-dismiss** the thread when scrolled to top — we already do
  this (`onThreadPointerDown` guarded by `scrollTop ≤ 2`, dismiss at
  `dragY > 90` with rubber-band opacity). This matches iOS sheet behavior;
  keep it. Add a **visible grabber handle** at the top (we have the
  `h-1 w-9` pill — good).
- **Long-press for quick-peek** — we have it (420ms → peek card). iOS
  convention is ~**500ms** for context menus; 420ms is acceptably snappy.
  Keep the haptic on fire.
- **Stop generation** gesture: tap the ■ send-button (primary) — the
  universal cancel affordance. Don't hide cancel behind a long-press.
- **Keyboard**: Enter submits (mobile keyboards: send key); Shift+Enter or
  the return key inserts newline once we move to `textarea`. Dismiss
  keyboard on scroll/drag of the thread.

---

## 8. "What they hide vs show" — distilled

| Show by default | Hide until needed |
|---|---|
| Text field + send affordance | Tools/attachments (behind one `+`) |
| User bubbles, assistant text | Per-message action toolbars (copy/retry) |
| Streaming progress (tokens/dots) | Timestamps, avatars |
| Source/result cards w/ favicon | Full source list (behind "Sources" count) |
| 3–4 suggested prompts (empty) | Settings, model picker, history |
| Follow-ups AFTER answer | Follow-ups DURING streaming |

The throughline: **a calm, near-empty surface that reveals capability on
demand.** Our glass FindBar is already close — the biggest gaps to close are
(1) send-button **stop state**, (2) **auto-grow textarea**, (3) a simulated
**per-word stream + thinking dots**, and (4) **richer result cards**
(favicon + category, horizontal strip) plus **follow-up pills**.
