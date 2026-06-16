import Foundation

/// Pure helpers behind the rich detail view — kept free of SwiftUI so they
/// are unit-testable and mirror the web `derivedUrl` / connection resolve in
/// `src/playground/ToolDetail.tsx`.
enum ToolDetailModel {

    /// Best-effort destination for url-less seed tools: explicit `url`, else
    /// `https://<logoDomain>`, else nil. Mirrors `derivedUrl` in ToolDetail.tsx.
    static func derivedURL(for tool: Tool) -> URL? {
        if let url = tool.url { return url }
        if let domain = tool.logoDomain, !domain.isEmpty {
            return URL(string: "https://\(domain)")
        }
        return nil
    }

    /// Resolves `relationIds` against a library, preserving order and skipping
    /// ids that don't resolve (defensive — stale refs must never crash).
    static func connections(for tool: Tool, in library: [Tool]) -> [Tool] {
        let byID = Dictionary(library.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return tool.relationIds.compactMap { byID[$0] }
    }

    /// Which knowledge sections render, mirroring the `k && …` guards in
    /// ToolDetail.tsx. A `nil` record (no bundled knowledge for the tool) is the
    /// un-enriched case: only "What it does" (from the tool summary) shows.
    struct Gating {
        let showsKillerFeatures: Bool
        let showsStrengthsWatchouts: Bool
        let showsWhoUses: Bool
        let showsPricing: Bool
    }

    static func gating(for knowledge: Knowledge?) -> Gating {
        guard let k = knowledge else {
            return Gating(
                showsKillerFeatures: false,
                showsStrengthsWatchouts: false,
                showsWhoUses: false,
                showsPricing: false
            )
        }
        return Gating(
            showsKillerFeatures: !k.killerFeatures.isEmpty,
            showsStrengthsWatchouts: !k.advantages.isEmpty || !k.weaknesses.isEmpty,
            showsWhoUses: !k.whoUses.isEmpty,
            showsPricing: k.pricing.model != .unknown
        )
    }
}
