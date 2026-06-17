# Chat Create
**Phase:** I · **Lens:** intelligence

## Goal (1-2 lines)
`chatCreate(prompt, map)` → a conversational "I want to build X" assistant that suggests a stack/tools and can add them to the map. This is the discoverable in-app assistant — the Claude-backed upgrade of `QueryEngine`, wired through the existing `ChatThreadStore` / `ChatTurn` thread.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Intelligence/ChatCreate.swift` — request builder, schema, payload → answer + suggestions.
- modify `Sources/MyAIMap/Intelligence/IntelligenceService.swift` — add `chatCreate(...)`.
- reuse (no edit) `State/ChatThreadStore.swift`, `State/ChatTurn.swift` (persisted thread), `UI/Search/QueryEngine.swift` (offline fallback).

## Approach (bullet steps)
- System tail: "The user wants to build something. Recommend a concrete, minimal stack from REAL, known tools. Prefer tools already in the provided map; suggest new ones only when needed. For each suggestion give a one-line reason. Never invent a tool — if you don't know one for a need, say so. Each suggested tool is either an existing map id or a candidate to be identified before it is added."
- User content: the prompt + a compact JSON of the current map (`id`, `name`, `category`) + the recent thread turns (`ChatThreadStore.turns`, capped) for continuity. Pass map/history as stable prefix where possible (cache-friendly), the new prompt last.
- Split suggestions into `existing` (an id already in the map → addable immediately) and `candidate` (name/url only → must pass through **I-identify-tool** + **I-guards** before any commit, so an unknown is never auto-added). `chatCreate` itself never commits; it returns intent.
- The conversational `answer` is clamped to `ChatThreadStore.maxAnswerChars (900)`; matched/added ids filtered to those in the live map by `ChatThreadStore.append` (existing logic) — no new persistence code.
- Offline (no key) → fall back to `QueryEngine.run(prompt, in:)` for the one-line answer + match cards; preserves the "no key" nudge.

## Prompt / contract
- **Schema (extends the core envelope):**
```json
{
  "schema_version": 1,
  "found": true,
  "confidence": 0.0,
  "answer": "string (<= 900 chars, the conversational reply)",
  "suggestions": [
    {
      "type": "existing|candidate",
      "id": "string|null",        // set when type == existing (must be a map id)
      "name": "string",
      "reason": "string (one line)",
      "url": "string|null"        // hint for candidate identification
    }
  ]
}
```
- `existing` suggestions carry a real map `id`; `candidate` suggestions carry `name`/`url` only and are gated through identify+guards before being added. `answer` length mirrors `ChatThreadStore.maxAnswerChars`.

## Interface / contract (Swift signatures only)
```swift
extension IntelligenceService {
    func chatCreate(prompt: String, map: [Tool], history: [ChatTurn]) async -> IntelligenceResult<StackSuggestion>
}
struct StackSuggestion: Sendable {
    let answer: String
    let existingIds: [String]               // already in the map → addable now
    let candidates: [SuggestedTool]         // need identify+guards before commit
    let confidence: Double
}
struct SuggestedTool: Sendable { let name: String; let reason: String; let url: URL? }
```

## Tests (mocked/recorded Claude responses — no live calls)
- `Tests/MyAIMapTests/ChatCreateTests.swift`, Swift Testing; stub `ClaudeClient`; map from `UniverseSeed`/fixtures; build `ChatTurn`s inline like `QueryEngineTests`.
- `suggestsExistingMapToolsByValidId` — recorded payload with `existing` ids present in the map → `existingIds` filtered to live ids only.
- `unknownToolBecomesCandidateNotAutoAdded` — `candidate` suggestion → lands in `candidates`, never in `existingIds`; assert it is not committed. **(refuses unknown — no auto-add)**
- `existingNotBlanket` — model returns many ids; assert dropped ids absent from the map are filtered (no blanket add). **(pinpoint-not-blanket)**
- `answerClampedAndThreadAppendSafe` — long `answer` clamped to 900; ids passed to `ChatThreadStore.append` are de-staled (reuse `ChatThreadStoreTests` expectations).
- `offlineFallsBackToQueryEngine` — `.offline` path returns a `QueryEngine`-shaped answer + matches.

## Done criteria (checklist)
- [ ] Existing suggestions resolve to real map ids; unknown ones become candidates, never auto-added.
- [ ] No commit happens inside `chatCreate`; candidates route through identify + guards.
- [ ] Answer respects `ChatThreadStore` clamps; thread persistence reuses existing store.
- [ ] Offline path returns a `QueryEngine` answer; "add key" nudge still surfaces.

## Dependencies
- **I-intelligence-service-core** — hard dependency.
- **I-identify-tool** + **I-guards** (gate candidates before any add).
- `ChatThreadStore` / `ChatTurn` (already in repo) for persistence; App-quality chat-scroll/discoverability tasks own the view wiring.
