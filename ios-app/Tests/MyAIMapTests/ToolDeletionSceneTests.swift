import Testing
@testable import MyAIMap

@Suite("Tool deletion — scene node pruning")
@MainActor
struct ToolDeletionSceneTests {

    @Test func prunedNamesAreEntitiesWhoseToolIsNoLongerLive() {
        let liveIDs: Set<String> = ["founder-os", "figma"]
        let entityNames = [
            "tool:founder-os", "tool:figma", "tool:midjourney",
            "tool-label:midjourney", "link:design-midjourney",
            "link:core-design", "cat:design", "ring:design", "universe"
        ]
        let toPrune = UniverseView.entitiesToPrune(entityNames: entityNames, liveToolIDs: liveIDs)
        #expect(Set(toPrune) == ["tool:midjourney", "tool-label:midjourney", "link:design-midjourney"])
    }

    @Test func nothingPrunedWhenAllToolsLive() {
        let liveIDs: Set<String> = ["founder-os", "figma"]
        let names = ["tool:founder-os", "tool:figma", "cat:design", "link:core-design"]
        #expect(UniverseView.entitiesToPrune(entityNames: names, liveToolIDs: liveIDs).isEmpty)
    }

    /// Many seed tool ids contain dashes (e.g. `claude-code`), so the link
    /// suffix can't be split on the last '-'. Pruning must still match the
    /// whole tool id and remove the deleted tool's entity families.
    @Test func prunesDashedToolIDEntities() {
        // claude-code is a real seed tool (coding category). Delete it.
        guard let claudeCode = UniverseSeed.tools.first(where: { $0.id == "claude-code" }) else {
            Issue.record("seed needs the claude-code tool")
            return
        }
        let liveIDs = Set(UniverseSeed.tools.map(\.id)).subtracting(["claude-code"])
        let cat = claudeCode.category.rawValue
        let names = [
            "tool:claude-code", "tool-label:claude-code", "link:\(cat)-claude-code",
            "tool:founder-os", "link:core-\(cat)"
        ]
        let toPrune = UniverseView.entitiesToPrune(entityNames: names, liveToolIDs: liveIDs)
        #expect(Set(toPrune) == ["tool:claude-code", "tool-label:claude-code", "link:\(cat)-claude-code"])
    }
}
