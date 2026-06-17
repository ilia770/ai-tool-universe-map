import Foundation

/// The single Claude-backed intelligence core. An `actor` so concurrent job
/// calls serialize safely. Reads the user-pasted key from the Keychain on
/// every request, sends one request/response via the injected
/// `ClaudeClient`, decodes schema-constrained JSON, and degrades to
/// `.offline` for every expected failure (no key / auth / transient /
/// malformed). It never throws to the caller for those, and never
/// fabricates a result.
///
/// The four jobs (identify / place / infer / chatCreate) are built as
/// extensions on top of the generic `complete(...)` below — this file is
/// only the core plumbing.
actor IntelligenceService {
    private let keychain: APIKeyStore
    private let client: ClaudeClient

    init(keychain: APIKeyStore = APIKeyStore(), client: ClaudeClient = .live) {
        self.keychain = keychain
        self.client = client
    }

    /// True when a key is present in the Keychain. Cheap gate the UI can
    /// use to decide whether to offer AI features.
    func isConfigured() async -> Bool {
        keychain.read() != nil
    }

    /// Run one job: build the forced-tool request, send it, and decode the
    /// `tool_use` output into `T`. The schema is a `JSONSchema` value type —
    /// pre-encoded `Data`, so it is `Sendable` and crosses the actor
    /// boundary cleanly. (A raw `[String: Any]` is not Sendable and cannot
    /// be passed to an actor-isolated method under Swift 6 strict
    /// concurrency; `JSONSchema(["type": ...])` builds one ergonomically.)
    ///
    /// Failure mapping (never throws):
    /// - no key            → `.offline(.noKey)`  (client is NOT invoked)
    /// - 401/403           → `.offline(.authFailed)`
    /// - 429/5xx/529/net   → `.offline(.transient)`
    /// - `stop_reason ==`
    ///   `"refusal"`       → `.refused` (content is never read/decoded)
    /// - malformed JSON    → `.offline(.transient)` (unknown; nudge retry)
    /// - 400 (our bug)     → `.offline(.transient)` (don't crash the UI)
    func complete<T: Decodable & Sendable>(
        job: IntelligenceJob,
        system: String,
        user: String,
        schema: JSONSchema,
        as type: T.Type
    ) async -> IntelligenceResult<T> {
        // Key gate FIRST. nil → offline immediately; the client is never
        // touched (the secret only ever lives in the Keychain).
        guard let apiKey = keychain.read() else {
            return .offline(reason: .noKey)
        }

        let request = ClaudeRequest(
            model: IntelligenceConfig.model(for: job),
            maxTokens: IntelligenceConfig.maxTokens,
            system: system,
            user: user,
            schema: schema
        )

        let response: ClaudeResponse
        do {
            response = try await client.send(request, apiKey)
        } catch let error as IntelligenceError {
            return map(error)
        } catch {
            return .offline(reason: .transient)
        }

        // Check the stop reason BEFORE reading any content — a refusal must
        // not be decoded as a (possibly partial) result.
        if response.stopReason == "refusal" {
            return .refused
        }

        guard let input = response.toolInput else {
            // No structured output and not a refusal — unknown, retryable.
            return .offline(reason: .transient)
        }

        do {
            let value = try JSONDecoder().decode(T.self, from: input)
            return .ok(value)
        } catch {
            // Body didn't match the schema. Treat as unknown rather than
            // fabricate; `.transient` so the UI nudges a retry.
            return .offline(reason: .transient)
        }
    }

    /// Map a thrown `IntelligenceError` to the caller-facing result.
    private func map<T>(_ error: IntelligenceError) -> IntelligenceResult<T> {
        switch error {
        case .authFailed:
            return .offline(reason: .authFailed)
        case .transient, .decode, .badRequest:
            // `.badRequest` is our own bug; surface as transient so the UI
            // stays usable rather than crashing or implying user fault.
            return .offline(reason: .transient)
        }
    }
}
