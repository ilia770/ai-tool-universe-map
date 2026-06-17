# Intelligence Guards
**Phase:** I · **Lens:** intelligence

## Goal (1-2 lines)
The judgment gate that sits between every intelligence result and any commit to the map: confirm giants/ambiguous names ("instagram", "google" → "are you sure / which one?"), turn unknowns into an ask-for-link instead of a guess, and route low-confidence results to a clarify step instead of silently mis-filing. Pure decision logic so it is fully unit-testable.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Intelligence/IntelligenceGuards.swift` — pure `enum` of guard rules + `GuardDecision`.
- modify `Sources/MyAIMap/Intelligence/IntelligenceService.swift` — apply guards before returning committable results from identify / place-category / chat-create candidates.
- reuse (no edit) `Data/Tool.swift`, `Data/ToolCategory.swift`; thresholds align with `RelationshipIntelligence.confidenceThreshold`.

## Approach (bullet steps)
- Three orthogonal rules, applied in order, all pure (no I/O):
  1. **Unknown → ask-for-link.** `IdentifyOutcome.notFound` (or `found:false`) → `.askForLink`. Never proceed to add.
  2. **Giant / ambiguous → confirm.** A small curated `ambiguousNames` set (`google`, `instagram`, `meta`, `apple`, `amazon`, `x`, `microsoft`, …) matched case/diacritic-folded against the query/identity name → `.confirm(question:options:)` before commit. The model may also flag ambiguity (`confidence` mid-band + multiple plausible reads) → same `.confirm`.
  3. **Low confidence → clarify.** `confidence < clarifyThreshold (0.6)` on an otherwise-found result → `.clarify(reason:)`, asking the user to confirm/correct rather than filing.
- Only when all three pass does the guard return `.proceed(payload)`.
- Folding reuses the `QueryEngine.fold` approach (case- + diacritic-insensitive) so "Instagram"/"instagram"/"ИНСТАГРАМ-style" inputs all match.
- Guards are the single choke point: identify, place-category, and chat-create candidates all run through `IntelligenceGuards.evaluate(...)` before any add. UI presentation of confirm/clarify/ask-for-link is owned by the App-quality add-tool-fab / chat tasks; this task returns the decision only.

## Prompt / contract
- **No new Claude call.** Guards consume the structured `confidence` / `found` already in the identify / place-category / chat-create payloads (the core envelope `{ found, confidence }`). The contract is purely: given a result + the originating query, decide proceed / confirm / clarify / ask-for-link. Any model-emitted ambiguity hint (e.g. a future `ambiguous: true` field) is honored if present but the curated giant list is authoritative offline.

## Interface / contract (Swift signatures only)
```swift
enum IntelligenceGuards {
    static let clarifyThreshold = 0.6
    static let ambiguousNames: Set<String>
    static func evaluate<T>(_ result: GuardInput<T>) -> GuardDecision<T>
}
struct GuardInput<T: Sendable>: Sendable { let payload: T?; let name: String?; let found: Bool; let confidence: Double; let query: String }
enum GuardDecision<T: Sendable>: Sendable {
    case proceed(T)
    case confirm(question: String, options: [String])
    case clarify(reason: String)
    case askForLink
}
```

## Tests (mocked/recorded Claude responses — no live calls)
- `Tests/MyAIMapTests/IntelligenceGuardsTests.swift`, Swift Testing — pure, no stub needed (mirrors `RelationshipIntelligenceTests` purity).
- `unknownAsksForLink` — `found:false` → `.askForLink`. **(refuses unknown → ask-for-link)**
- `giantTriggersConfirm` — name "Google" (and "instagram", folded) → `.confirm(...)` with options, even at high confidence. **(giant/ambiguous confirm)**
- `lowConfidenceClarifies` — `found:true, confidence:0.4` → `.clarify(...)`.
- `cleanHighConfidenceProceeds` — niche tool, `confidence:0.9`, not in giant list → `.proceed(payload)`.
- `foldingMatchesCasingAndDiacritics` — "ИНСТАГРАМ"/"Instagram " variants all hit the ambiguous set.
- `guardsAreSingleChokePoint` — identify-found-but-giant routed through `evaluate` returns `.confirm`, not `.proceed` (no commit slips past).

## Done criteria (checklist)
- [ ] Unknown never proceeds — always `.askForLink`.
- [ ] Curated giants/ambiguous names always force `.confirm` before commit, even at high confidence.
- [ ] Low-confidence found results route to `.clarify`, never silently filed.
- [ ] Pure, deterministic, no network; every add path funnels through `evaluate`.

## Dependencies
- **I-intelligence-service-core** (result/confidence envelope) — hard dependency.
- **I-identify-tool**, **I-place-category**, **I-chat-create** (all feed `evaluate` before commit).
- UI surfaces for confirm/clarify/ask-for-link → App-quality add-tool-fab + Shell tasks (out of scope here).
