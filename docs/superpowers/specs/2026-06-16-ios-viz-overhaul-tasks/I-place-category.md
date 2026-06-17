# Place Category
**Phase:** I · **Lens:** intelligence

## Goal (1-2 lines)
`placeCategory(tool, categories)` → slot a tool into the correct existing branch (e.g. PostHog → analytics), or, when nothing fits, **propose a new, well-named category** instead of forcing a wrong bucket. This fixes the "PostHog landed in social" class of error at placement time.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Intelligence/PlaceCategory.swift` — request builder, schema, payload → placement.
- modify `Sources/MyAIMap/Intelligence/IntelligenceService.swift` — add `placeCategory(...)`.
- reuse (no edit) `Data/ToolCategory.swift` (`ToolCategoryId`, `ToolCategory`, `ColorHex`), `Data/UniverseSeed.swift` (`UniverseSeed.category(_:)`).

## Approach (bullet steps)
- System tail: "Place this tool in the single best-fitting existing category. Only if NONE of the existing categories genuinely fit, propose ONE new category with a short, well-chosen name and a one-line description. Do not stretch an existing category to make it fit; do not invent a category when an existing one is correct."
- User content: tool (`name`, `summary`, `whatFor` if from identify) + the existing categories as JSON (`id`, `name`, `description`) drawn from `UniverseSeed` so the model sees the real taxonomy.
- If `placement == "existing"`, validate the returned id against `ToolCategoryId`; an invalid id is treated as a malformed response → re-ask is out of scope, so fall back to `"propose"` handling or `.offline`.
- If `placement == "new"`, return a `ProposedCategory` (name + description + suggested color/glow defaulting to a neutral `ColorHex` if absent). The app commits a new category only after the user accepts (commit/UI is owned by Shell/App-quality add-tool flow, not this task).
- Low confidence (`< 0.6`) on an *existing* placement → defer to **I-guards** clarify rather than silently filing.
- Offline (no key) → fall back to the rule-based `classify-ai-tool` parity path / `QueryEngine` category hints; never block the add flow.

## Prompt / contract
- **Schema (extends the core envelope):**
```json
{
  "schema_version": 1,
  "found": true,
  "confidence": 0.0,
  "placement": "existing|new",
  "categoryId": "coding|design|research|media|distribution|infrastructure|knowledge|analytics|core|null",
  "newCategory": { "name": "string", "description": "string", "colorHint": "#rrggbb|null" }
}
```
- `categoryId` enum mirrors `ToolCategoryId` exactly; non-null only when `placement == "existing"`. `newCategory` non-null only when `placement == "new"`. `colorHint` parses via existing `ColorHex` (hex or rgba); `nil` → neutral default.

## Interface / contract (Swift signatures only)
```swift
extension IntelligenceService {
    func placeCategory(for tool: ToolIdentity, in categories: [ToolCategory]) async -> IntelligenceResult<CategoryPlacement>
}
enum CategoryPlacement: Sendable {
    case existing(ToolCategoryId, confidence: Double)
    case propose(ProposedCategory)
}
struct ProposedCategory: Sendable { let name: String; let description: String; let color: ColorHex }
```

## Tests (mocked/recorded Claude responses — no live calls)
- `Tests/MyAIMapTests/PlaceCategoryTests.swift`, Swift Testing; stub `ClaudeClient`; categories from `UniverseSeed`.
- `slotsPosthogIntoAnalytics` — recorded `{ placement:"existing", categoryId:"analytics" }` → `.existing(.analytics, …)`. **(correct categorization)**
- `proposesNewCategoryWhenNoneFit` — recorded `{ placement:"new", newCategory:{ name:"Observability", … } }` → `.propose(ProposedCategory(name:"Observability", …))`. **(new-category fallback)**
- `invalidExistingIdDoesNotMisfile` — `categoryId:"socialz"` (bad) → not silently filed; degrades to propose/offline.
- `colorHintParsesOrDefaults` — `colorHint:"#3366ff"` parses; `null` → neutral default `ColorHex`.
- `lowConfidenceExistingDefersToGuards` — `placement:"existing", confidence:0.4` flagged for clarify (assert it is not committed as final).

## Done criteria (checklist)
- [ ] Returns a valid `ToolCategoryId` OR a named proposal — never a wrong/forced bucket.
- [ ] New-category proposal carries a usable name, description, and `ColorHex`.
- [ ] Existing-placement id validated against the enum; invalid ids never silently file.
- [ ] All assertions against recorded JSON; no live calls.

## Dependencies
- **I-intelligence-service-core** — hard dependency.
- **I-identify-tool** (supplies `ToolIdentity`, and `category == nil` triggers this).
- **I-guards** (low-confidence clarify). Commit of a new category → Shell add-tool flow (out of scope here).
