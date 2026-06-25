import Foundation
import Testing
@testable import MyAIMap

/// Pure-logic tests for the bundled-logo domain resolution. Mirrors the web
/// app's `getToolLogoDomain` / `getDomainFromUrl` (src/lib/tool-logos.ts) so
/// the iOS logo lookup resolves the same brand domains the web does.
@Suite("ToolLogoDomain — bundled-logo lookup")
struct ToolLogoDomainTests {

    private func tool(
        id: String,
        url: String? = nil,
        logoDomain: String? = nil
    ) -> Tool {
        Tool(
            id: id,
            name: id,
            category: .coding,
            summary: "",
            stage: .execution,
            orbit: .inner,
            angle: 0,
            url: url.flatMap(URL.init(string:)),
            logoDomain: logoDomain,
            relationIds: [],
            classification: nil
        )
    }

    @Test func explicitLogoDomainWins() {
        let t = tool(id: "posthog", url: "https://posthog.com", logoDomain: "posthog.com")
        #expect(ToolLogoDomain.resolve(for: t) == "posthog.com")
    }

    @Test func perIdOverrideResolvesGitHub() {
        // GitHub-hosted tools have a github.com url but we override by id to be
        // explicit and bundle the GitHub mark for them.
        let t = tool(id: "deer-flow", url: "https://github.com/bytedance/deer-flow")
        #expect(ToolLogoDomain.resolve(for: t) == "github.com")
    }

    @Test func fallsBackToUrlHost() {
        let t = tool(id: "unknown", url: "https://www.example.com/path")
        #expect(ToolLogoDomain.resolve(for: t) == "example.com")
    }

    @Test func noUrlNoOverrideResolvesNil() {
        let t = tool(id: "mystery")
        #expect(ToolLogoDomain.resolve(for: t) == nil)
    }

    @Test func assetCandidatesDotsBecomeDashes() {
        let t = tool(id: "deer-flow", url: "https://github.com/bytedance/deer-flow")
        // id first, then dashed domain (the asset name), then raw domain.
        #expect(ToolLogoDomain.assetCandidates(for: t) == ["deer-flow", "github-com", "github.com"])
    }

    @Test func gitHubBackedToolsResolveToBundledGitHubAsset() {
        // Every GitHub-hosted seed tool must resolve to the bundled `github-com`
        // asset key, so they render the GitHub mark instead of a bare monogram.
        let gitHubIds = ["deer-flow", "agent-skills", "mattpocock-skills", "designer-skills", "shannon", "api-mega-list"]
        for id in gitHubIds {
            let t = tool(id: id, url: "https://github.com/org/\(id)")
            #expect(ToolLogoDomain.assetCandidates(for: t).contains("github-com"))
        }
        // `openswarm` is in the override map but has NO url in the seed — the
        // override alone must still resolve it to the GitHub asset.
        #expect(ToolLogoDomain.assetCandidates(for: tool(id: "openswarm")).contains("github-com"))
    }
}
