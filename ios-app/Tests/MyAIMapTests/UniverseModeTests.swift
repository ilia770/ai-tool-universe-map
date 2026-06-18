import Testing
@testable import MyAIMap

@Suite("UniverseMode — map-driven interaction model")
struct UniverseModeTests {

    @Test func overviewShowsBranchesButNoSatellites() {
        let mode = UniverseMode.overview

        #expect(mode.focusedCategory == .core)
        #expect(mode.selectedToolID == nil)
        #expect(!mode.showsSatellites)
        #expect(mode.showsPlanetLabels)
        #expect(mode.planetOpacity(for: .coding) > 0.7)
    }

    @Test func branchFocusRevealsOnlySelectedBranchSatellites() {
        let mode = UniverseMode.branchFocus(.analytics)

        #expect(mode.focusedCategory == .analytics)
        #expect(mode.selectedToolID == nil)
        #expect(mode.showsSatellites)
        #expect(mode.showsToolLabels)
        #expect(mode.planetOpacity(for: .analytics) == 1)
        #expect(mode.planetOpacity(for: .design) < 0.45)
    }

    @Test func toolSelectedKeepsBranchAndHighlightsOneTool() {
        let mode = UniverseMode.toolSelected(.analytics, "posthog")

        #expect(mode.focusedCategory == .analytics)
        #expect(mode.selectedToolID == "posthog")
        #expect(mode.showsSatellites)
        #expect(mode.showsToolAnchor)
        #expect(mode.showsToolLabels)
        #expect(mode.satelliteOpacity(for: "posthog") == 1)
        #expect(mode.satelliteOpacity(for: "other-tool") < 0.5)
    }

    @Test func coreToolSelectionRevealsCoreSatellites() {
        // Selecting a non-founder core tool (e.g. OpenSwarm) must surface
        // satellites around the core so the tool has an on-map node.
        let mode = UniverseMode.toolSelected(.core, "openswarm")

        #expect(mode.focusedCategory == .core)
        #expect(mode.selectedToolID == "openswarm")
        #expect(mode.showsSatellites)
    }

    @Test func detailAndChatSuppressMapNoise() {
        let detail = UniverseMode.detail(.analytics, "posthog")
        let chat = UniverseMode.chatOpen(.analytics, "posthog")

        #expect(!detail.allowsMapGestures)
        #expect(!detail.showsPlanetLabels)
        #expect(detail.mapBlurRadius > 0)
        #expect(detail.mapBlurRadius <= 3)
        #expect(detail.orbitOpacityMultiplier == 0)
        #expect(detail.planetOpacity(for: .design) < 0.08)
        #expect(chat.isChatOpen)
        #expect(!chat.showsSatellites)
        #expect(chat.mapOpacity <= 0.25)
        #expect(chat.orbitOpacityMultiplier == 0)
    }
}
