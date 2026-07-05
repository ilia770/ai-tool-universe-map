import Testing
@testable import MyAIMap

/// Pure seed-mapping tests for the Bloom graph (WS5.1b). Verifies the fresh
/// graph opens on the current selection, and that the mapper always returns an
/// id present in the adjacency (never crashes the engine with a phantom seed).
@Suite("BloomGraphView — selection → seed mapping")
struct BloomGraphSeedTests {

    // Small hand id-set standing in for a built adjacency's keys.
    private let validIDs: Set<String> = ["founder-os", "notion", "figma"]
    private let core = "founder-os"

    @Test func toolSelectedSeedsThatTool() {
        let mode = UniverseMode.toolSelected(.core, "notion")
        #expect(BloomGraphView.seedID(for: mode, coreID: core, validIDs: validIDs) == "notion")
    }

    @Test func detailModeSeedsItsTool() {
        let mode = UniverseMode.detail(.core, "figma")
        #expect(BloomGraphView.seedID(for: mode, coreID: core, validIDs: validIDs) == "figma")
    }

    @Test func chatOpenWithToolSeedsThatTool() {
        let mode = UniverseMode.chatOpen(.core, "notion")
        #expect(BloomGraphView.seedID(for: mode, coreID: core, validIDs: validIDs) == "notion")
    }

    @Test func overviewSeedsCore() {
        #expect(BloomGraphView.seedID(for: .overview, coreID: core, validIDs: validIDs) == core)
    }

    // Categories are not Bloom nodes, so branch focus falls back to the core.
    @Test func branchFocusFallsBackToCore() {
        let mode = UniverseMode.branchFocus(.core)
        #expect(BloomGraphView.seedID(for: mode, coreID: core, validIDs: validIDs) == core)
    }

    // A selected id absent from the adjacency must never be seeded — fall back.
    @Test func invalidSelectionFallsBackToCore() {
        let mode = UniverseMode.toolSelected(.core, "ghost-tool")
        #expect(BloomGraphView.seedID(for: mode, coreID: core, validIDs: validIDs) == core)
    }
}
