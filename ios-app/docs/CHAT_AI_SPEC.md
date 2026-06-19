# CHAT_AI_SPEC

Owner: Claude (logic in `UI/Search/UniverseAssistantCore.swift`, the pure
ranking/recommendation core) → Codex (chip rendering in the chat surface).
Do NOT edit the universe scene, rail, or detail layout here.

## Prime directive
The assistant answers from the user's **own** universe first, is honest about
gaps, and never invents tools. Every tool it names is an actionable chip.

## Data context (the assistant must see all of it)
Source of truth is `UniverseViewModel`. The reply core receives:
- `model.visibleAllTools` — every tool currently in the universe (added + sampled, minus hidden). **Not** `UniverseSeed.tools`.
- per-tool: `category`, `summary`, `stage`, `orbit`, `url`, `logoDomain`, `relationIds`, `classification` (confidence/keywords/reason).
- `ToolKnowledgeBook.knowledge(for:)` → `useCase`, `killerFeatures`, `strengths`, `tradeoffs`, `pricing`, `typicalUsers`.
- category metadata via `UniverseSeed.category(_:)` (name/shortName/description).
- `model.activityHistory` (added/removed/opened/asked) for "what do I already have / recently used".

The core stays pure (no `UniverseViewModel` import): the view passes the
resolved collections in, exactly as `UniverseAssistantCore.reply(query:tools:categoryName:knowledge:)` does today — extend that signature, don't reach into the model from the core.

## Intent handling
Detect intent from the query; support at minimum:
- **Build-a-thing** ("I need to create an app, which tools?") → recommend a tool per workflow stage (research→plan→build→ship→review) using `stage`/category coverage.
- **Best-for-X** ("which tool for app design?") → rank within the matching category.
- **Cheapest** → rank by parsed price tier ascending (see Pricing parsing).
- **Fastest** / **simplest** vs **advanced** → rank by a heuristic from `tradeoffs`/`typicalUsers` keywords.
- **Inventory** ("what tools do I already have?") → list owned tools grouped by category, no recommendations.

## Response structure (markdown, rendered by the chat bubble)
Sections, each omitted when empty:
1. **You already have** — owned tools that fit (chips, `kind: existing`).
2. **Recommended to add** — tools NOT in the universe (chips, `kind: add`). Max 3.
3. **Options** — compact table: tool · paid/free · fast/slow · simple/advanced · one-line tradeoff.
4. **Tradeoffs / Next** — one or two lines guiding the next question or action.

Owned vs missing is decided by id membership in `visibleAllTools`.

## Pricing parsing (for cheapest/options)
`ToolKnowledge.pricing` is free text today. Add a pure helper
`PriceTier.parse(_ pricing: String) -> PriceTier` returning
`.free | .low | .mid | .high | .custom | .unknown` (keyword + `$`-number
heuristics). Used by both this spec and `TOOL_DETAIL_SPEC.md` pricing table —
**single shared parser**, defined once.

## Tool chips / buttons
The reply carries a typed payload, not just markdown text:
```
struct AssistantReply {
    let markdown: String
    let chips: [ToolChip]      // ordered, deduped
}
struct ToolChip { let toolID: String; let name: String; let kind: Kind }  // .existing | .add
```
Rendering (Codex, in the chat bubble per `CHAT_INPUT_SPEC.md`):
- `.existing` chip → tap opens that tool's detail (same path as a map/satellite tap → `model.focusTool(id)` then present detail).
- `.add` chip → tap calls the Add flow pre-filled with the suggested name (see `ADD_TOOL_SPEC.md`); on success the chip flips to `.existing`.
- Chip shows the tool logo/monogram (`ToolLogoView`) + name. Min 44pt hit area.

`matchIDs` already exists on today's `AssistantReply` — evolve it into `chips` with the `kind` tag; don't add a parallel mechanism.

## Failure / unknown states
- Empty/whitespace query → "Ask what you want to find, or paste a service URL." (unchanged).
- **No suitable owned tool** → say so plainly, then suggest 2–3 popular tools to add as `.add` chips (a small curated `popularByCategory` map, NOT invented names). Never imply a tool exists when it doesn't.
- Empty universe (`model.isUniverseEmpty`) → answer with `.add` recommendations only + a nudge to load the sample.
- Price/knowledge unknown → render "Unknown" tier, never a guessed number.

## Acceptance criteria
- A tool added via Add flow is referenced by the assistant in the SAME session (depends on `ADD_TOOL_SPEC.md` C-1 fix).
- "What do I have?" lists exactly `visibleAllTools`, grouped by category.
- Every tool name in a reply is a tappable chip; existing→detail, missing→Add.
- "Cheapest" orders by parsed tier; ties broken deterministically by id.
- No reply ever names a tool absent from both the universe and the curated popular list.
- Core stays unit-testable (pure): add `UniverseAssistantCoreTests` cases for each intent + the no-match popular-suggestion path.

## Manual QA
1. Empty universe → ask "tools to build an app" → only Add chips + sample nudge.
2. Load sample → "what do I have?" → grouped inventory, no Add chips.
3. Add a brand-new tool → ask about its category → it appears under "You already have".
4. Tap existing chip → detail opens. Tap Add chip → Add sheet pre-filled → after add, chip→existing.
5. "cheapest design tool" → cheapest first; a tool with unknown price sorts last, labeled Unknown.
