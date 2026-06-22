# CHAT_AI_SPEC

Owner domain: Ask AI Universe answer behavior, intent routing, and assistant
action chips, plus copy-action feedback.

**Affected files**
- `UI/Search/UniverseAssistantCore.swift` — pure intent routing + reply text.
- `State/UniverseViewModel.swift` — `askAssistant`, DeepSeek fallback,
  `appendLocalReply`/`appendAssistantReply`, catalog grounding.
- `State/UniverseSelection.swift` — `AssistantMessage`, `MissingToolSuggestion`.
- `UI/Search/ChatScreen.swift` — message rendering, copy button, action row.
- `UI/Search/SearchDock.swift` — existing-tool chips + missing-tool chips.
- `Universe/UniverseOverlayView.swift`, `Universe/UniverseMapView.swift` — chip
  callbacks (open tool / open Add Tool with draft).
- `UI/Haptics/BrandHaptics.swift` — haptic feedback primitive.

Do not edit the Universe 3D/2D visualization, right rail, detail visual design,
the Add Tool form layout, or profile/settings here.

## Data Sources (ground every answer in these — never the open web)
- Existing + user-added tools: `UniverseViewModel.visibleAllTools` (seed plus
  locally persisted adds, minus hidden).
- Categories / branch labels: `UniverseSeed.category($0).shortName`
  (Coding, Design, Research, Analytics, Media, Runtime, Social, Skills, Core).
- Per-tool use case, strengths, tradeoffs, typical users, pricing notes:
  `ToolKnowledgeBook.knowledge(for:)`.
- Relations: `Tool.relationIds`, resolved only when the related tool is present
  in the visible universe.
- Recent local history: `UniverseViewModel.activityHistory`.

No live web lookup. **Exact pricing must never be invented.** When a tool has
no verified local pricing, the assistant emits `Pricing unknown, verify website.`
(`UniverseAssistantCore.safePricing`).

## Required behavior (what Ask AI must understand)

The assistant must correctly handle, and never collapse into a single fallback,
each of these intents:

1. **General questions / small talk** — answer normally. "как дела" / "hello" /
   "thanks" must NOT return "I did not find this service."
2. **Tool recommendations (domain)** — "which tool for app design?" → recommend,
   checking the user's universe FIRST, else suggest 2-3 popular addable tools.
3. **App-building workflow** — "I need to build an app, which tools?" → ordered
   stack across design → coding → backend → analytics, with options + caveats.
4. **Design / specific-tool questions** — answer about a named tool directly.
5. **Missing-tool suggestions** — when a branch has no good existing option,
   say so plainly and offer addable suggestions with Add buttons.
6. **Add-tool intent** — a lone unknown product name routes to the
   missing-service / website-request path so the user can add it.

## Current routing (entry point: `UniverseAssistantCore.reply`)

Order is significant; the first matching branch wins. "Fixed" = already landed.

1. **Empty query** → prompt to ask what to build/compare/add. *(fixed)*
2. **Named tool** — every token of a tool's name appears in the query → answer
   about that tool directly (`directMatchReply`), even if a domain word is also
   present (H2). Generic single-token names (`research`, `code`, `design`,
   `runway`, …) in `genericNameTokens` are excluded so "which tool for research"
   stays a domain ask, not the tool literally named *Research*. *(fixed)*
3. **Domain intent** — `domainIntent(for:)` requires a recommendation phrase
   (`which`, `recommend`, `best for`, `i need`, `looking for`, `want`,
   plus RU `какой / нужен / ищу / посоветуй / что для …`) AND a domain keyword.
   → `domainReply`: existing branch tools first, then 2-3 missing suggestions.
   *(fixed — R14 added the "I need / looking for" phrasings)*
4. **Full app workflow** — `isFullAppWorkflow` (recommend-ask + app noun +
   build verb) → `appWorkflowReply` with a preferred multi-branch stack. *(fixed)*
5. **Ranked direct matches** — `SearchCore` + `ToolKnowledge.searchableText`,
   with single/multi-token fallback scoring → `directMatchReply`. *(fixed)*
6. **No match** → `noMatchReply`:
   - `isGeneralConversation` true → `generalReply` (normal answer). Small talk,
     greetings, RU + transliterated RU are whitelisted; an explicit service word
     (`add / tool / website / url / добав / сервис / сайт …`) forces NOT-general.
     *(fixed — small talk no longer hits the missing-service copy)*
   - 1-3 token name-like query → `missingReply` (treated as add intent, R15).
   - Broad platform (`google`, `instagram`, `meta`, whole-token match) →
     "need a specific product" copy. *(fixed — token match, not substring, so
     `metabase` / `apple notes` don't false-trip)*
   - Otherwise → "I did not find this service" + ask for website URL.

### DeepSeek layer (`UniverseViewModel.askAssistant`)
The local rule-based reply is **always computed first** (it supplies chip
match-IDs + missing suggestions). If a DeepSeek key is in the Keychain, its
catalog-grounded text replaces the prose, but `matchIDs` and
`missingToolSuggestions` still come from the local reply. Any error / empty
text / missing key falls back to the local reply text. The system prompt
(`deepSeekSystemPrompt`) forbids inventing tools/pricing and instructs it to ask
for a website URL when a tool is not in the catalog.

## Known gaps (to close)
- `generalReply` returns a fixed "I am here." card; it does not actually answer
  arbitrary general questions offline (only DeepSeek does). Acceptance only
  requires that general questions are NOT mislabeled "service not found".
- Recommendation detection is keyword-gated: a bare domain noun with no
  recommendation phrase ("design tool") may fall through to ranked/missing
  paths rather than `domainReply`. Acceptable for now; revisit if QA flags it.

## Presentation (Apple-like markdown, rendered by ChatScreen)
- Structure from `structuredText`: **Summary** (one short paragraph) →
  **Recommended tools** (bullets) → **Options** (Fastest / Cheapest-free /
  Easiest / Advanced-pro) → **Caveats / tradeoffs** → **Action chips** line.
- Title + short answer + bullets + grouped sections + subtle dividers. No walls
  of text, no colored callout blocks.
- Existing tool names render as tappable **chips/buttons** (SearchDock
  `actionStrip`, from `message.matchIDs` → `visibleAllTools`). Tapping opens the
  tool detail sheet.
- Missing suggestions render as **Add** chips ("Add Framer"), carrying name +
  category + reason + `Pricing unknown, verify website.`; tapping opens Add Tool
  pre-filled (Manual mode, suggested branch).
- Each recommended line uses use-case first sentence, branch label, pricing (or
  the unknown note), and up to 3 related tool names.

## Copy-action feedback (required)
- Copy controls: assistant message copy (`ChatScreen.assistantActionRow`,
  `UIPasteboard.general.string = message.text`) and tool-info copy in detail.
- On copy: write to pasteboard, fire a **haptic** (`BrandHaptics.fire(.success)`),
  and show a **native-style toast / snackbar**: `Answer copied` for a chat reply,
  `Tool info copied` for a tool. The toast is a brief auto-dismissing overlay
  banner (≈1.5s, top or above the input), not a colored block; subtle material
  surface consistent with the chat theme.
- Toast must be VoiceOver-announced and must not steal focus.
- *(Gap: today the copy button writes the pasteboard with only a press haptic
  via `PressableButtonStyle(haptic: .light)`; no toast and no "copied"
  announcement exist yet. This is the work to add.)*

## User-added tools
Added tools become visible to future answers because the assistant reads
`visibleAllTools`. After a successful add there must be no "tool does not exist"
answer for that tool. Added tools use cautious language until website-verified.

## Acceptance (QA)
- "как дела" / "hello" / "thanks" → normal reply, NOT "service not found".
- "Which tool should I use for app design?" → recommends existing Design-branch
  tools first; if none, says so and offers 2-3 addable suggestions with Add.
- "I need to build an app, which tools?" → ordered multi-branch stack + options.
- A bare known tool name (e.g. "Supabase") → direct answer about that tool.
- A bare unknown product name → asks for website URL (add path), not general chat.
- "google" → "need a specific product", not a hallucinated single tool.
- Existing tool mentions are tappable chips that open detail; missing
  suggestions are Add chips that open Add Tool pre-filled.
- No exact pricing is fabricated; unknown pricing shows the verify-website note.
- Copying an answer → pasteboard set + haptic + "Answer copied" toast.
- Copying tool info → pasteboard set + haptic + "Tool info copied" toast.

## History (prior landed work)
Agent 6 added intent routing, structured replies, missing-tool suggestions,
relation mentions, cautious pricing, history caveats. Codex follow-ups added
missing-chip prefill into Add Tool and the no-match general-vs-lookup split
(small talk, RU + transliterated RU, single unknown token still asks for a
website). Tests: `Tests/MyAIMapTests/UniverseAssistantCoreTests.swift`.
