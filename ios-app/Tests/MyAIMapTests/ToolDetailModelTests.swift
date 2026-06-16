import Foundation
import Testing
@testable import MyAIMap

@Suite("ToolDetailModel — pure resolvers")
struct ToolDetailModelTests {

    private func tool(
        id: String, url: URL? = nil, logoDomain: String? = nil, relationIds: [String] = []
    ) -> Tool {
        Tool(
            id: id, name: id.capitalized, category: .coding, summary: "—",
            stage: .execution, orbit: .inner, angle: 0,
            url: url, logoDomain: logoDomain, relationIds: relationIds, classification: nil
        )
    }

    @Test func derivedURLPrefersExplicitURL() {
        let t = tool(id: "a", url: URL(string: "https://a.com"), logoDomain: "b.com")
        #expect(ToolDetailModel.derivedURL(for: t)?.absoluteString == "https://a.com")
    }

    @Test func derivedURLFallsBackToLogoDomain() {
        let t = tool(id: "a", url: nil, logoDomain: "figma.com")
        #expect(ToolDetailModel.derivedURL(for: t)?.absoluteString == "https://figma.com")
    }

    @Test func derivedURLIsNilWhenNothingToOpen() {
        #expect(ToolDetailModel.derivedURL(for: tool(id: "a")) == nil)
    }

    @Test func connectionsResolveAndSkipMissingIDs() {
        let library = [tool(id: "a"), tool(id: "b")]
        let subject = tool(id: "s", relationIds: ["b", "ghost", "a"])
        let resolved = ToolDetailModel.connections(for: subject, in: library)
        #expect(resolved.map(\.id) == ["b", "a"])  // order preserved, ghost dropped
    }
}
