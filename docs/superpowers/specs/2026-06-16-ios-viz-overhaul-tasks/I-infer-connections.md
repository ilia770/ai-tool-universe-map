# Infer Connections
**Phase:** I · **Lens:** intelligence

## Goal (1-2 lines)
`inferConnections(tool, existingMap)` → a small set of **pinpoint** edges, each with a reason and confidence. Connections must be real and specific — a giant like Google does NOT link to everything; it links only to genuine relations (its Chrome extensions, its SDKs). This is the Claude-backed upgrade of the rule-based `RelationshipIntelligence`.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Intelligence/InferConnections.swift` — request builder, schema, payload → `[InferredEdge]`.
- modify `Sources/MyAIMap/Intelligence/IntelligenceService.swift` — add `inferConnections(...)`.
- reuse (no edit) `Data/RelationshipIntelligence.swift` (`InferredEdge`, `RelationKind`), used as both the offline fallback and the output type.

## Approach (bullet steps)
- System tail: "Return only real, specific relationships between THIS tool and tools in the provided map. A large vendor connects to its OWN products and direct integrations, NOT to every tool in its category. Prefer few precise edges over many weak ones. Every edge needs a one-sentence reason and a confidence."
- User content: the candidate (`name`, `category`, `summary`, `logoDomain`, `url`) + a compact JSON list of existing map tools (`id`, `name`, `category`, `logoDomain`) so the model can only point at ids that exist.
- Map each returned `kind` onto the closed `RelationKind` enum (`extension-of`, `integrates-with`, `same-vendor`, `data-flows-to`, `alternative-to`); drop edges whose `toId` is not in the map (defensive, like `ToolDetailModel.connections`).
- Enforce anti-blanket guards in code regardless of model output: drop `confidence < RelationshipIntelligence.confidenceThreshold (0.4)`; cap per kind at `RelationshipIntelligence.maxEdgesPerKind (4)`; apply the same deterministic sort as the rule engine so output is stable and a hub cannot over-connect.
- Offline (no key) → fall back to `RelationshipIntelligence.infer(candidate:universe:)` — identical `[InferredEdge]` shape, zero UI change.

## Prompt / contract
- **Schema (extends the core envelope):**
```json
{
  "schema_version": 1,
  "found": true,
  "confidence": 0.0,
  "edges": [
    {
      "toId": "string (MUST be an id from the provided map)",
      "kind": "extension-of|integrates-with|same-vendor|data-flows-to|alternative-to",
      "reason": "string (one sentence, specific)",
      "confidence": 0.0
    }
  ]
}
```
- `kind` raw values are byte-identical to `RelationKind`. `confidence ∈ [0,1]` mirrors `InferredEdge.confidence`. `toId` is validated against the map; unknown ids are dropped, not trusted.

## Interface / contract (Swift signatures only)
```swift
extension IntelligenceService {
    func inferConnections(for tool: Tool, in map: [Tool]) async -> IntelligenceResult<[InferredEdge]>
}
// Post-filter (also unit-testable in isolation):
enum ConnectionGuards {
    static func clamp(_ edges: [InferredEdge], map: [Tool]) -> [InferredEdge]
}
```

## Tests (mocked/recorded Claude responses — no live calls)
- `Tests/MyAIMapTests/InferConnectionsTests.swift`, Swift Testing; reuse `RelationshipFixtures.universe` for the map and stub `ClaudeClient`.
- `pinpointNotBlanketForGiant` — recorded payload where the model returns 30 edges for "Google"; assert clamp drops the unrelated ones and total ≤ 12 (mirrors `RelationshipIntelligenceTests.hubDoesNotOverConnect`). **(pinpoint-not-blanket)**
- `chromeExtensionLinksToVendorOnly` — payload links `g-ext` → `google` as `.extensionOf`, and does NOT link to `figma`; assert both (mirrors `chromeExtensionLinksToGoogleNotUnrelated`).
- `dropsEdgesToUnknownIds` — payload references a `toId` not in the map → filtered out.
- `dropsLowConfidenceEdges` — `confidence:0.2` edge removed by the 0.4 threshold.
- `offlineUsesRuleEngine` — `.offline` path returns `RelationshipIntelligence.infer(...)` output for the same candidate.

## Done criteria (checklist)
- [ ] No edge survives to an id absent from the map.
- [ ] Per-kind cap + confidence threshold enforced in code (model output is never trusted blindly).
- [ ] A giant/hub cannot produce a blanket of edges.
- [ ] Output type is exactly `[InferredEdge]`; offline path is the existing rule engine.

## Dependencies
- **I-intelligence-service-core** — hard dependency.
- `RelationshipIntelligence` (offline fallback + guard constants) — already in repo.
- Feeds the "connected because" detail UI (reason string) already present in `ToolDetailSection`.
