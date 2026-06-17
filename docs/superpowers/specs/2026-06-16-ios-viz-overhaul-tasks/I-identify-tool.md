# Identify Tool
**Phase:** I · **Lens:** intelligence

## Goal (1-2 lines)
`identifyTool(query | url)` → a structured identity for a real AI tool (category, description, pricing, killer features, pros/cons, who-uses, confidence), or a not-found result. It must refuse to hallucinate: when it cannot identify the service it returns `found: false` and the UI says "couldn't identify — paste a link," never inventing a fake tool.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Intelligence/IdentifyTool.swift` — request builder, schema, response → domain mapping.
- modify `Sources/MyAIMap/Intelligence/IntelligenceModels.swift` — add `ToolIdentity` DTO + `IdentifyOutcome`.
- modify `Sources/MyAIMap/Intelligence/IntelligenceService.swift` — add `identifyTool(...)`.
- reuse (no edit) `Data/Tool.swift` (`Tool`, `ToolCategoryId`, `Tool.Classification`), `Data/Knowledge.swift` (`Knowledge`, `ToolPricing`, `PricingModel`).

## Approach (bullet steps)
- Build a focused system tail: "Identify exactly one real, known AI tool from the user's text or URL. If you are not confident it exists, set found=false — do NOT guess a plausible-sounding tool. Categorize correctly (e.g. PostHog → analytics, never social)."
- User content: the raw query or URL string. For a URL, instruct the model to treat the domain as the identity hint, not as license to invent.
- Map the returned `category` string onto the closed `ToolCategoryId` enum; if it does not map, hand off to **I-place-category** (propose-new-category), do not force a wrong bucket.
- On `found: false` OR `confidence < 0.55` → `IdentifyOutcome.notFound` (UI: "paste a link"). The low-confidence branch is owned by **I-guards**.
- Build a `Knowledge`-shaped record from the payload so the existing `ToolDetailModel.gating` / detail sections render with no new view code; `pricing.model` decodes into `PricingModel` (fallback `.unknown`).
- Offline fallback (no key): return `.offline`; caller runs `SearchCore`/`QueryEngine` over the seed so a seed tool is still found by name.

## Prompt / contract
- **Schema (extends the core envelope):**
```json
{
  "schema_version": 1,
  "found": true,
  "confidence": 0.0,
  "tool": {
    "name": "string",
    "category": "coding|design|research|media|distribution|infrastructure|knowledge|analytics|other",
    "description": "string",
    "whoUses": "string",
    "killerFeatures": ["string"],
    "pros": ["string"],
    "cons": ["string"],
    "pricing": { "model": "free|open-source|freemium|subscription|usage-based|enterprise|mixed|unknown", "summary": "string" },
    "logoDomain": "string|null",
    "url": "string|null"
  }
}
```
- `category` enum mirrors `ToolCategoryId` plus `"other"` (→ triggers place-category). `pricing.model` enum mirrors `PricingModel` raw values exactly. When `found:false`, `tool` may be null.

## Interface / contract (Swift signatures only)
```swift
extension IntelligenceService {
    func identifyTool(query: String) async -> IntelligenceResult<IdentifyOutcome>
}
enum IdentifyOutcome: Sendable { case found(ToolIdentity), notFound }
struct ToolIdentity: Sendable {
    let name: String; let category: ToolCategoryId?  // nil → needs place-category
    let knowledge: Knowledge; let logoDomain: String?; let url: URL?
    let confidence: Double
}
```

## Tests (mocked/recorded Claude responses — no live calls)
- `Tests/MyAIMapTests/IdentifyToolTests.swift`, Swift Testing, stub `ClaudeClient` like `IntelligenceServiceTests`.
- `refusesUnknownTool` — recorded `{ found:false }` for "asdfqwer ai" → `.ok(.notFound)`; assert no fabricated `ToolIdentity`. **(refuses unknown)**
- `posthogIsAnalyticsNotSocial` — recorded PostHog payload → `category == .analytics`. **(correct categorization)**
- `unknownCategoryDefersToPlaceCategory` — payload `category:"other"` → `ToolIdentity.category == nil`.
- `pricingDecodesToKnownModel` — `pricing.model:"usage-based"` → `PricingModel.usageBased`; bad value → `.unknown` (parity with `KnowledgeIntegrityTests.pricingModelDecodesForEveryRecord`).
- `lowConfidenceIsNotFound` — `confidence:0.3` → `.notFound`.
- `offlineFallsBackToSeed` — `.offline` path leaves seed lookup to caller (assert result is `.offline`, not a fake tool).

## Done criteria (checklist)
- [ ] Never returns a tool when `found:false` or confidence below threshold.
- [ ] Category always resolves to a real `ToolCategoryId` or `nil` (never a wrong bucket).
- [ ] Produces a `Knowledge` record so existing detail UI renders unchanged.
- [ ] All assertions run against recorded JSON; no live calls.

## Dependencies
- **I-intelligence-service-core** (transport, key gate, result enum) — hard dependency.
- **I-place-category** (consumes `category == nil`).
- **I-guards** (low-confidence clarify, giant/ambiguous confirm before commit).
