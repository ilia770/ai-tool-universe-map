import Foundation

/// Static wire/model configuration for the Anthropic Messages API. All the
/// "magic strings" live here so the contract can be corrected later without
/// touching the service or future job extensions.
enum IntelligenceConfig {
    /// Messages API endpoint.
    static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Required `anthropic-version` header value.
    static let anthropicVersion = "2023-06-01"

    /// Output cap. Shared across jobs — none of the four needs more.
    static let maxTokens = 2048

    /// The single forced tool used for schema-constrained structured output.
    static let toolName = "emit"
    static let toolDescription =
        "Emit the structured result. Respond ONLY by calling this tool with valid arguments."

    /// Shared system-prompt preamble. Job extensions append their own task
    /// framing; this base sets the global guardrails (no fabrication).
    static let systemPromptBase =
        "You are the intelligence core of My AI Map, a curated universe of AI tools for "
        + "founders and operators. Be precise and grounded. Never invent tools, facts, or "
        + "relationships. If unsure, prefer fewer, higher-confidence results."

    /// LOCKED model split: Sonnet for the cheap structured jobs, Opus for
    /// the conversational chat-creation job.
    static func model(for job: IntelligenceJob) -> String {
        switch job {
        case .identify, .place, .infer:
            return "claude-sonnet-4-6"
        case .chatCreate:
            return "claude-opus-4-8"
        }
    }
}
