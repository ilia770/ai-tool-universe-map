import Foundation

/// Pricing model, mirroring the web app's `PricingModel` union
/// (`src/playground/knowledge.ts`). `CaseIterable` so integrity tests can
/// assert the decoded value is one of the known cases.
enum PricingModel: String, CaseIterable, Codable, Sendable {
    case free
    case openSource = "open-source"
    case freemium
    case subscription
    case usageBased = "usage-based"
    case enterprise
    case mixed
    case unknown
}

/// Pricing facts for one tool. Mirror of the web `ToolPricing`.
struct ToolPricing: Codable, Sendable {
    let model: PricingModel
    let summary: String
}

/// Rich, web-researched knowledge for one tool. Direct mirror of the web
/// app's `ToolKnowledge` (`src/playground/knowledge.ts`) minus the runtime
/// `enriched` flag — every record bundled in `knowledge.json` is enriched by
/// definition. Decoded from `Resources/knowledge.json`, which is emitted
/// byte-identically from `src/playground/knowledge.data.ts`.
struct Knowledge: Codable, Sendable {
    let killerFeatures: [String]
    let whatFor: String
    let advantages: [String]
    let weaknesses: [String]
    let whoUses: String
    let pricing: ToolPricing
}
