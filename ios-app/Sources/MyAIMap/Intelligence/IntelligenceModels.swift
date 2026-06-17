import Foundation

/// Which of the four future jobs is being run. The job selects the model
/// (`IntelligenceConfig.model(for:)`) — the model split is LOCKED there,
/// not at call sites.
enum IntelligenceJob: Sendable {
    case identify
    case place
    case infer
    case chatCreate
}

/// Why the service fell back to offline. Surfaced to the UI so it can
/// nudge the right recovery (paste a key, retry later).
enum OfflineReason: Sendable {
    /// No key in the Keychain — prompt the user to paste one.
    case noKey
    /// 401/403 — the pasted key is wrong or revoked.
    case authFailed
    /// 429/5xx/529, a transport failure, or an unparseable body. The
    /// honest "we don't know, try again" bucket: never fabricate a result.
    case transient
}

/// The result of one job. Never throws to the caller for the expected
/// failure modes — those degrade to `.offline`. `.refused` is distinct:
/// the model declined, so there is nothing to retry or fall back to.
enum IntelligenceResult<T: Sendable>: Sendable {
    case ok(T)
    case offline(reason: OfflineReason)
    case refused
}

/// Internal errors thrown across the `ClaudeClient` boundary. The service
/// maps these to `IntelligenceResult`; they never reach feature callers.
enum IntelligenceError: Error {
    /// HTTP 400 — a malformed request we built. A bug, not a user problem.
    case badRequest(String)
    /// 401/403 — auth. Mapped to `.offline(.authFailed)`.
    case authFailed
    /// 429/5xx/529 or a URLSession transport error. → `.offline(.transient)`.
    case transient(Error?)
    /// JSON decode failed. → `.offline(.transient)` (treated as unknown).
    case decode(Error)
}

// MARK: - Schema

/// A JSON Schema object passed as the tool's `input_schema`. Modelled as
/// pre-encoded `Data` so the value is `Sendable` (a raw `[String: Any]`
/// is not) and crosses the actor boundary cleanly. Build one from a
/// Swift dictionary literal at the call site via `init(_:)`.
struct JSONSchema: Sendable {
    /// The schema serialized as a JSON object.
    let data: Data

    /// Wrap an already-encoded JSON object.
    init(data: Data) {
        self.data = data
    }

    /// Encode a plain dictionary literal into the schema. The dictionary
    /// is consumed synchronously here — `Any` never escapes onto the wire
    /// or across an isolation boundary.
    init(_ object: [String: Any]) {
        // `JSONSerialization` is the only practical encoder for an
        // untyped `[String: Any]`. A malformed literal is a programmer
        // error; fall back to an empty object rather than trapping.
        self.data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
    }
}

// MARK: - Wire DTOs

/// Anthropic Messages API request body. Structured output is achieved with
/// a single forced tool (`emit`) whose `input_schema` is the caller's
/// schema — keeping the wire contract entirely inside this layer.
struct ClaudeRequest: Sendable {
    let model: String
    let maxTokens: Int
    let system: String
    let user: String
    /// The `emit` tool's input schema (the caller's JSON Schema).
    let schema: JSONSchema
}

extension ClaudeRequest {
    /// Serialize to the Messages API JSON body. Built by hand (rather than
    /// `Codable`) because `input_schema` is an arbitrary nested JSON object
    /// that we already hold as encoded `Data`.
    func httpBody() throws -> Data {
        let schemaObject = try JSONSerialization.jsonObject(with: schema.data)
        let toolName = IntelligenceConfig.toolName
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [
                ["role": "user", "content": user],
            ],
            "tools": [
                [
                    "name": toolName,
                    "description": IntelligenceConfig.toolDescription,
                    "input_schema": schemaObject,
                ],
            ],
            "tool_choice": ["type": "tool", "name": toolName],
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }
}

/// The slice of the Messages API response the service needs: the stop
/// reason (checked first) and the forced `tool_use` block's `input`, which
/// holds the structured JSON object to decode into `T`.
struct ClaudeResponse: Sendable {
    let stopReason: String?
    /// The `input` object from the `tool_use` content block, re-encoded as
    /// JSON `Data` ready to decode into the caller's type. `nil` when no
    /// `tool_use` block is present.
    let toolInput: Data?
}

extension ClaudeResponse {
    /// Parse a raw Messages API response body into the fields we need.
    /// Throws `IntelligenceError.decode` on a body we can't read at all;
    /// a missing `tool_use` block yields `toolInput == nil` (not a throw)
    /// so the service can map it to a refusal/transient as appropriate.
    static func decode(_ data: Data) throws -> ClaudeResponse {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw IntelligenceError.decode(error)
        }
        guard let object = root as? [String: Any] else {
            throw IntelligenceError.decode(DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Response root is not an object")
            ))
        }

        let stopReason = object["stop_reason"] as? String

        var toolInput: Data?
        if let content = object["content"] as? [[String: Any]],
           let block = content.first(where: { ($0["type"] as? String) == "tool_use" }),
           let input = block["input"] {
            toolInput = try? JSONSerialization.data(withJSONObject: input)
        }

        return ClaudeResponse(stopReason: stopReason, toolInput: toolInput)
    }
}
