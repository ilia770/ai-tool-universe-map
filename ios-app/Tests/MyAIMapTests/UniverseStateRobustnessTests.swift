import Testing
import Foundation
import UIKit
@testable import MyAIMap

/// Robustness coverage for the state layer's input-handling and mutation paths,
/// driven through the public `UniverseViewModel` surface (the URL/slug/dedup
/// helpers themselves are private, so they are pinned via `addCustomTool` /
/// `createBranch` / `deleteTool` behaviour). Each model is backed by an isolated
/// store so persistence never leaks between cases.
@Suite("UniverseViewModel — input robustness")
@MainActor
struct UniverseStateRobustnessTests {
    private func makeModel(sample: Bool = false) -> UniverseViewModel {
        let defaults = UserDefaults(suiteName: "robust-\(UUID().uuidString)")!
        let model = UniverseViewModel(store: UniverseStore(defaults: defaults))
        if sample { model.loadSampleUniverse() }
        return model
    }

    private func tool(_ model: UniverseViewModel, named name: String) -> Tool? {
        model.allTools.first { $0.name == name }
    }

    // MARK: - URL normalization (via addCustomTool)

    @Test func bareDomainBecomesHTTPSWithStrippedHost() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "Bare", urlString: "Example.com", category: .analytics))
        let t = tool(model, named: "Bare")!
        #expect(t.url?.scheme == "https")
        #expect(t.logoDomain == "example.com")
        // A real URL was captured, so the classifier confidence is the
        // website-backed value, not the unverified one.
        #expect(t.classification?.confidence == 0.74)
    }

    @Test func httpSchemeIsUpgradedToHTTPS() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "Upgrade", urlString: "HTTP://Example.com/path", category: .analytics))
        let t = tool(model, named: "Upgrade")!
        #expect(t.url?.scheme == "https")
        #expect(t.logoDomain == "example.com")
    }

    @Test func wwwPrefixStrippedFromLogoDomain() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "Dubdub", urlString: "https://www.example.com", category: .analytics))
        #expect(tool(model, named: "Dubdub")?.logoDomain == "example.com")
    }

    @Test func nonHTTPSchemeIsRejectedButToolStillAdds() {
        let model = makeModel()
        // A valid name with an unusable URL: the tool is created but flagged
        // unverified (no URL captured, lower-confidence classification).
        #expect(model.addCustomTool(name: "FtpTool", urlString: "ftp://files.example.com", category: .analytics))
        let t = tool(model, named: "FtpTool")!
        #expect(t.url == nil)
        #expect(t.logoDomain == nil)
        #expect(t.classification?.confidence == 0.48)
    }

    @Test func emptyURLLeavesToolUnverified() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "NoSite", urlString: "   ", category: .analytics))
        let t = tool(model, named: "NoSite")!
        #expect(t.url == nil)
        #expect(t.logoDomain == nil)
    }

    // MARK: - Name slug / punctuation edge cases

    @Test func punctuationOnlyNameStillAddsWithFallbackID() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "!!!", urlString: "", category: .analytics))
        // slug("!!!") == "" → uniqueID falls back to "tool"; the display name is
        // preserved verbatim.
        let t = tool(model, named: "!!!")!
        #expect(t.id == "tool")
        #expect(model.allTools.count == 1)
    }

    @Test func secondPunctuationOnlyNameDedupesToFirst() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "!!!", urlString: "", category: .analytics))
        // Both slug to "" so the second add resolves to the existing tool
        // (focus, not a new node) — no ID-space pollution.
        #expect(model.addCustomTool(name: "@@@", urlString: "", category: .design))
        #expect(model.allTools.count == 1)
    }

    @Test func nonLatinNameSurvivesSlugging() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "你好", urlString: "", category: .analytics))
        // CJK characters are alphanumeric in Unicode, so they survive slugging
        // (unlike pure ASCII punctuation) and yield a real id — not the "tool"
        // fallback. Pin that distinction.
        #expect(tool(model, named: "你好")?.id == "你好")
    }

    // MARK: - Duplicate detection

    @Test func sameNameSameDataDoesNotDuplicate() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "Linear", urlString: "linear.app", category: .coding))
        #expect(model.addCustomTool(name: "Linear", urlString: "linear.app", category: .coding))
        #expect(model.allTools.filter { $0.name == "Linear" }.count == 1)
    }

    @Test func sameNameDifferentURLResolvesToExistingBySlug() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "Linear", urlString: "linear.app", category: .coding))
        // Different host, but the name slug matches → resolves to the existing
        // tool rather than minting a near-duplicate.
        #expect(model.addCustomTool(name: "Linear", urlString: "other.example.com", category: .design))
        #expect(model.allTools.filter { $0.name == "Linear" }.count == 1)
        // The original (linear.app) is the one kept.
        #expect(tool(model, named: "Linear")?.logoDomain == "linear.app")
    }

    // MARK: - .core rejection

    @Test func cannotAddToolToCoreAndNoActivityRecorded() {
        let model = makeModel()
        let before = model.activityHistory.count
        #expect(model.addCustomTool(name: "CoreSquatter", urlString: "x.com", category: .core) == false)
        #expect(model.allTools.isEmpty)
        #expect(model.activityHistory.count == before)
    }

    @Test func cannotAddToolWithBlankName() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "   ", urlString: "x.com", category: .analytics) == false)
        #expect(model.allTools.isEmpty)
    }

    // MARK: - deleteTool mode cleanup

    @Test func deletingSelectedToolStepsBackToBranch() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "Sel", urlString: "", category: .analytics))
        let id = tool(model, named: "Sel")!.id
        model.universeMode = .detail(.analytics, id)
        #expect(model.deleteTool(id))
        #expect(model.universeMode == .branchFocus(.analytics))
    }

    @Test func deletingSiblingLeavesOpenDetailUntouched() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "Keep", urlString: "", category: .analytics))
        #expect(model.addCustomTool(name: "Drop", urlString: "", category: .analytics))
        let keep = tool(model, named: "Keep")!.id
        let drop = tool(model, named: "Drop")!.id
        model.universeMode = .detail(.analytics, keep)
        #expect(model.deleteTool(drop))
        // Deleting a sibling must not disturb the open detail of another tool.
        #expect(model.universeMode == .detail(.analytics, keep))
        #expect(!model.visibleAllTools.contains { $0.id == drop })
    }

    @Test func cannotDeleteCoreTool() {
        let model = makeModel(sample: true)
        // The central core tool is never user-removable.
        #expect(model.deleteTool(PlanetData.centralCoreToolID) == false)
    }

    // MARK: - createBranch

    @Test func emptyBranchNameFallsBackToBranchSlug() {
        let model = makeModel()
        #expect(model.createBranch(name: "   ").rawValue == "branch")
    }

    @Test func branchNameSlugsAndRegisters() {
        let model = makeModel()
        let id = model.createBranch(name: "Ops")
        #expect(id.rawValue == "ops")
        // Registered so it resolves to a real category everywhere.
        #expect(UniverseSeed.category(id).name == "Ops")
        #expect(model.allCategories.contains { $0.id == id })
    }

    @Test func sameBranchNameMintsUniqueSlug() {
        // NOTE: the createBranch doc comment claims it is "idempotent on slug"
        // (returns the existing branch), but the implementation always mints a
        // unique slug via uniqueCategorySlug. This pins the ACTUAL behaviour;
        // if idempotence is intended the code (not this test) should change.
        let model = makeModel()
        let first = model.createBranch(name: "Ops")
        let second = model.createBranch(name: "Ops")
        #expect(first.rawValue == "ops")
        #expect(second.rawValue == "ops-2")
        #expect(first != second)
    }
}

/// Coverage for the `UniverseSeed` custom-category registry. The registry is a
/// process-static, so every test clears it on entry and exit to stay hermetic
/// (the registry's lack of reset is itself a latent cross-test hazard).
@Suite("UniverseSeed custom-category registry")
@MainActor
struct UniverseSeedRegistryTests {
    private func cat(_ id: String) -> ToolCategory {
        ToolCategory(
            id: ToolCategoryId(rawValue: id),
            name: id.capitalized,
            shortName: id.capitalized,
            description: "test",
            color: ColorHex(stringLiteral: "#34D399"),
            glow: ColorHex(stringLiteral: "#A7F3D0"),
            angle: 0
        )
    }

    @Test func registerResolvesCustomCategory() {
        UniverseSeed.registerCustomCategories([])
        defer { UniverseSeed.registerCustomCategories([]) }
        let a = cat("alpha")
        UniverseSeed.registerCustomCategories([a])
        #expect(UniverseSeed.category(a.id).name == "Alpha")
    }

    @Test func registerIsFullReplaceNotMerge() {
        UniverseSeed.registerCustomCategories([])
        defer { UniverseSeed.registerCustomCategories([]) }
        let a = cat("alpha"), b = cat("bravo"), c = cat("charlie")
        UniverseSeed.registerCustomCategories([a, b])
        UniverseSeed.registerCustomCategories([b, c])
        // Full replace: alpha is gone, charlie is present. (The view model always
        // passes the complete set, so this is correct — but it's worth pinning.)
        #expect(UniverseSeed.customCategories[a.id] == nil)
        #expect(UniverseSeed.customCategories[c.id] != nil)
    }

    @Test func unknownIDGetsDeterministicGeneratedCategory() {
        UniverseSeed.registerCustomCategories([])
        defer { UniverseSeed.registerCustomCategories([]) }
        let id = ToolCategoryId(rawValue: "totally-unknown-branch")
        let first = UniverseSeed.generatedCategory(for: id)
        let second = UniverseSeed.generatedCategory(for: id)
        // Deterministic: same id → same color + angle across calls + launches.
        #expect(first.angle == second.angle)
        #expect(first.color.rawValue == second.color.rawValue)
        #expect(first.name == "Totally Unknown Branch")
    }
}

/// Coverage for hex → color parsing, used for seed and generated branch colors.
@Suite("ColorHex parsing")
struct ColorHexTests {
    private func rgb(_ color: UIColor) -> (CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    @Test func parsesSixDigitHexWithHash() {
        let (r, g, b) = rgb(ColorHex(stringLiteral: "#FF8800").uiColor)
        #expect(abs(r - 1.0) < 0.001)
        #expect(abs(g - 0x88 / 255.0) < 0.001)
        #expect(abs(b - 0.0) < 0.001)
    }

    @Test func parsesHexWithoutHashAndLowercase() {
        let (r, g, b) = rgb(ColorHex(stringLiteral: "ff8800").uiColor)
        #expect(abs(r - 1.0) < 0.001)
        #expect(abs(g - 0x88 / 255.0) < 0.001)
        #expect(abs(b - 0.0) < 0.001)
    }

    @Test func invalidHexFallsBackToWhite() {
        let white = rgb(UIColor.white)
        #expect(rgb(ColorHex(stringLiteral: "nope").uiColor) == white)
        // Three-digit shorthand is not supported → white.
        #expect(rgb(ColorHex(stringLiteral: "#FFF").uiColor) == white)
        #expect(rgb(ColorHex(stringLiteral: "").uiColor) == white)
    }
}
