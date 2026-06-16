import Foundation

/// Decodes the shared `relationship-fixtures.json` (byte-identical to
/// `src/lib/relationship-fixtures.json`, the same JSON the web fixture test
/// asserts) and exposes its universe + candidates so both lanes drive their
/// inference engine from one source of truth — the P0 `knowledge.json` pattern.
///
/// Lives in the app target (not the test target) so `Bundle(for:)` of its
/// token resolves the **app** bundle where the resource is copied — a token
/// defined in the test bundle would resolve `MyAIMapTests.xctest`, which does
/// not contain the JSON. Mirrors `UniverseSeed.BundleToken`.
enum RelationshipFixtures {
    private final class BundleToken {}

    struct ExpectedEdge: Decodable, Sendable {
        let toId: String
        let kind: RelationKind
    }

    struct Case: Decodable, Sendable {
        let candidate: Tool
        let expect: [ExpectedEdge]
        let forbid: [String]?
    }

    private struct FixtureFile: Decodable {
        let universe: [Tool]
        let cases: [Case]
    }

    private static let file: FixtureFile = {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "relationship-fixtures", withExtension: "json") else {
            fatalError("Missing bundled resource relationship-fixtures.json (XcodeGen copies it from Sources/MyAIMap/Resources).")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(FixtureFile.self, from: data)
        } catch {
            fatalError("Failed to decode relationship-fixtures.json: \(error)")
        }
    }()

    static var universe: [Tool] { file.universe }
    static var cases: [Case] { file.cases }

    static func candidate(_ id: String) -> Tool {
        guard let c = file.cases.first(where: { $0.candidate.id == id })?.candidate else {
            fatalError("No fixture candidate with id \(id)")
        }
        return c
    }

    /// Minimal in-memory tool for tests that don't come from the fixture
    /// (e.g. the hub-over-connect synthetic universe).
    static func tool(id: String, name: String, category: ToolCategoryId, stage: WorkflowStageId) -> Tool {
        Tool(
            id: id, name: name, category: category, summary: "",
            stage: stage, orbit: .middle, angle: 0,
            url: nil, logoDomain: nil, relationIds: [], classification: nil
        )
    }
}
