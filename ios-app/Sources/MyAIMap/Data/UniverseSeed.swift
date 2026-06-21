import Foundation

/// Decodable root mirroring the shape of `src/data/ai-tool-universe.seed.json`.
///
/// The iOS port decodes a bundled `ai-tool-universe.seed.json` from the app
/// target. NOTE: this iOS seed is an intentional fork / superset of the web
/// seed, not a verbatim copy. The iOS seed currently has 9 categories and 53
/// tools — including an extra `analytics` category and tools such as `posthog`
/// — whereas the documented web seed in `src/data/` has 8 categories and 49
/// tools and no `analytics` category. The two payloads share the same schema
/// but their contents have deliberately diverged. Any future change to the iOS
/// seed shape must be intentional: the parity/invariants test in
/// `Tests/MyAIMapTests/UniverseSeedParityTests.swift` pins the current shape
/// (category/tool counts, `analytics` presence, and core invariants) and will
/// fail if the seed drifts unexpectedly.
private struct SeedFile: Decodable {
    let version: Int
    let categories: [ToolCategory]
    let tools: [Tool]
    let workflowLinks: [UniverseLink]
    // `workflowStages` is an object keyed by stage id in the web JSON; nothing
    // on iOS consumes it yet, so it is intentionally not decoded.
}

/// Universe seed data, decoded once from the bundled canonical JSON.
///
/// Public API is unchanged from the old hand-written Phase-0 stub
/// (`categories`, `tools`, `category(_:)`, `tools(in:)`) so every existing
/// consumer keeps compiling untouched.
enum UniverseSeed {
    /// Resolves the bundle that contains the app's resources. For an XcodeGen
    /// app target (no SwiftPM `Bundle.module`), `Bundle(for:)` of a type
    /// defined in the target returns the app bundle. Unit tests run inside the
    /// host app (`TEST_HOST` / `BUNDLE_LOADER`), so the same bundle resolves
    /// there too.
    private final class BundleToken {}

    private static let seed: SeedFile = {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "ai-tool-universe.seed", withExtension: "json") else {
            fatalError("Missing bundled resource ai-tool-universe.seed.json — this is a build-time invariant (XcodeGen copies it from Sources/MyAIMap/Resources).")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SeedFile.self, from: data)
        } catch {
            fatalError("Failed to decode ai-tool-universe.seed.json: \(error)")
        }
    }()

    static var categories: [ToolCategory] { seed.categories }

    static var tools: [Tool] { seed.tools }

    static var workflowLinks: [UniverseLink] { seed.workflowLinks }

    static func category(_ id: ToolCategoryId) -> ToolCategory {
        categories.first { $0.id == id } ?? categories[0]
    }

    static func tools(in category: ToolCategoryId) -> [Tool] {
        tools.filter { $0.category == category }
    }
}
