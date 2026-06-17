# Intelligence Service Core
**Phase:** I · **Lens:** intelligence

## Goal (1-2 lines)
A single `IntelligenceService` that wraps the Claude Messages API (raw `URLSession`, no Swift SDK exists): reads the user-pasted key from Keychain, sends one request/response, decodes structured JSON, and degrades gracefully to an offline rule fallback (`SearchCore`/`QueryEngine`/`RelationshipIntelligence`) plus an "add key" nudge when no key is set.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Intelligence/IntelligenceService.swift` — actor + public async API.
- create `Sources/MyAIMap/Intelligence/ClaudeClient.swift` — `URLSession` POST to `/v1/messages`, headers, decode, typed errors.
- create `Sources/MyAIMap/Intelligence/IntelligenceModels.swift` — `Codable` request/response DTOs + `IntelligenceError`, `IntelligenceResult<T>` (`.ok` / `.offline` / `.refused`).
- create `Sources/MyAIMap/Intelligence/IntelligenceConfig.swift` — model id, base URL, `maxTokens`, system-prompt constants.
- modify `Sources/MyAIMap/State/AppSettings.swift` — only if a `hasIntelligenceKey` convenience is needed for the nudge (read-only via the keychain task's accessor; do not store the key here).

## Approach (bullet steps)
- Pure transport in `ClaudeClient`: build `POST https://api.anthropic.com/v1/messages`, headers `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`. Body: `{ model: "claude-opus-4-8", max_tokens, system, messages, output_config:{ format:{ type:"json_schema", schema } }, thinking:{ type:"adaptive" } }`.
- `IntelligenceService` is an `actor`; ctor takes a `KeychainStore` (from S-keychain-api-key) and a `ClaudeClient` (injectable → tests pass a mock that returns recorded JSON; no live calls in tests).
- Key gate: every public method first asks Keychain for the key. Missing key → return `.offline` immediately; never throw. The caller renders the existing rule-based result + a "Add your Anthropic key for smart features" nudge.
- Map HTTP status via the migration/error tables: 401/403 → `.offline` + actionable message (bad/absent key); 429/5xx/529 → `.offline` (transient, retry hint); 400 → `IntelligenceError.badRequest` (developer bug, surfaced in debug only).
- `stop_reason == "refusal"` → `.refused` (not `.ok`); never read `content[0]` before checking `stop_reason`.
- Decode the single text block as JSON-schema-constrained output; on decode failure → `.offline` (treat as unknown, never fabricate).
- No `temperature`/`top_p`/`budget_tokens` (removed on `claude-opus-4-8` → 400).

## Prompt / contract
- **System (shared base):** "You are the classification brain for My AI Map, a curated universe of real AI tools for founders. Only describe tools you actually know. If unsure a tool exists, return found=false. Never invent. Respond with JSON matching the schema." Task-specific tails are appended by `identifyTool` / `inferConnections` / `placeCategory` / `chatCreate`.
- **User:** the query/url plus a compact JSON snapshot of the current map (ids, names, categories) when relevant.
- **Structured-output contract:** every call sets `output_config.format = { type: "json_schema", schema: <task schema> }`. The envelope this task owns:
```json
{ "schema_version": 1, "found": true, "confidence": 0.0 }
```
  `found` + `confidence ∈ [0,1]` are present on every task payload; downstream tasks extend it. `confidence` mirrors `UniverseLink.confidence` / `InferredEdge.confidence` ranges.

## Interface / contract (Swift signatures only)
```swift
actor IntelligenceService {
    init(keychain: KeychainStore, client: ClaudeClient = .live)
    func isConfigured() async -> Bool
    // task entrypoints declared in their own specs; all return IntelligenceResult<…>
}
enum IntelligenceResult<T: Sendable>: Sendable { case ok(T), offline(reason: OfflineReason), refused }
enum OfflineReason: Sendable { case noKey, authFailed, transient }
struct ClaudeClient: Sendable { var send: @Sendable (ClaudeRequest, String) async throws -> ClaudeResponse; static let live: ClaudeClient }
enum IntelligenceError: Error { case badRequest(String), transport(Error), decode(Error) }
```

## Tests (mocked/recorded Claude responses — no live calls)
- New `Tests/MyAIMapTests/IntelligenceServiceTests.swift`, Swift Testing (`@Suite`/`@Test`/`#expect`) like `QueryEngineTests`.
- Inject a stub `ClaudeClient` whose `send` returns recorded JSON fixtures (mirror `RelationshipFixtures` bundled-JSON pattern, or inline strings).
- `noKeyReturnsOfflineNudge` — keychain empty → `.offline(reason: .noKey)`, client never invoked.
- `authErrorMapsToOffline` — stub throws 401 → `.offline(reason: .authFailed)`.
- `transientErrorMapsToOffline` — stub throws 529 → `.offline(reason: .transient)`.
- `refusalIsNotOk` — response with `stop_reason:"refusal"` → `.refused`, content never decoded.
- `malformedJSONDegrades` — non-schema body → `.offline`, no crash.

## Done criteria (checklist)
- [ ] No live network in tests; client fully injectable.
- [ ] Missing key never throws; always `.offline(.noKey)`.
- [ ] Uses `claude-opus-4-8`, `anthropic-version: 2023-06-01`, no removed params.
- [ ] `stop_reason` checked before reading content.
- [ ] Secret key only ever read from Keychain, never logged or persisted in `AppSettings`/`UserDefaults`.
- [ ] `typecheck → lint → unit tests → build` green; Swift 6 (no isolated-conformance).

## Dependencies
- **S-keychain-api-key** (provides `KeychainStore` + key accessor) — hard dependency.
- Foundation `URLSession` only; no SDK.
- Consumed by **I-identify-tool**, **I-infer-connections**, **I-place-category**, **I-chat-create**, **I-guards**.
