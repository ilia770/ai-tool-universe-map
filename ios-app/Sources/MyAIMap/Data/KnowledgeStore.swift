import Foundation

/// Tool knowledge, decoded once from the bundled canonical `knowledge.json`.
///
/// The JSON is emitted byte-identically from the web source of truth
/// (`src/playground/knowledge.data.ts`) by `scripts/gen-knowledge-json.mjs`,
/// then copied into `Sources/MyAIMap/Resources/`. This makes drift between the
/// two ports impossible — there is a single authored source and a committed
/// artifact shared by both lanes (the same contract as `ai-tool-universe.seed.json`).
enum KnowledgeStore {
    /// See `UniverseSeed.BundleToken` — resolves the app bundle for both the
    /// XcodeGen app target and the host-app unit test bundle.
    private final class BundleToken {}

    /// Keyed by tool id, matching `UniverseSeed.tools[*].id`.
    static let all: [String: Knowledge] = {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "knowledge", withExtension: "json") else {
            fatalError("Missing bundled resource knowledge.json — build-time invariant (XcodeGen copies it from Sources/MyAIMap/Resources; run `npm run gen:knowledge` to regenerate).")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: Knowledge].self, from: data)
        } catch {
            fatalError("Failed to decode knowledge.json: \(error)")
        }
    }()

    /// Best available knowledge for a tool id, or `nil` if none is bundled.
    static func knowledge(for id: String) -> Knowledge? {
        all[id]
    }
}
