import Testing
import CoreGraphics
@testable import MyAIMap

// MARK: - Helpers

private func makeNode(
    id: String,
    role: OrbRole,
    orbit: Int = 1,
    isSelected: Bool = false,
    inOpenPocket: Bool = false,
    depthScale: CGFloat = 1.0,
    screen: CGPoint = .zero
) -> NodeVisibilityInput {
    NodeVisibilityInput(
        id: id,
        role: role,
        orbit: orbit,
        isSelected: isSelected,
        inOpenPocket: inOpenPocket,
        depthScale: depthScale,
        screen: screen
    )
}

// MARK: - Suite

@Suite("DeclutterRule — pure node-visibility arbiter")
struct DeclutterRuleTests {

    // MARK: Overview mode

    @Test func overviewHidesToolLabelsKeepsCategoriesAndCore() {
        let nodes: [NodeVisibilityInput] = [
            makeNode(id: "core",    role: .core),
            makeNode(id: "cat-A",   role: .category),
            makeNode(id: "cat-B",   role: .category),
            makeNode(id: "tool-1",  role: .tool),
            makeNode(id: "tool-2",  role: .tool),
        ]

        let result = DeclutterRule.decide(mode: .overview, nodes: nodes)

        #expect((result["core"]  ?? 0) > 0, "core must be visible in overview")
        #expect((result["cat-A"] ?? 0) > 0, "category A must be visible in overview")
        #expect((result["cat-B"] ?? 0) > 0, "category B must be visible in overview")
        #expect((result["tool-1"] ?? 1) == 0, "non-selected tool must be hidden in overview")
        #expect((result["tool-2"] ?? 1) == 0, "non-selected tool must be hidden in overview")
    }

    @Test func overviewSelectedToolIsAlwaysVisible() {
        let nodes: [NodeVisibilityInput] = [
            makeNode(id: "core",    role: .core),
            makeNode(id: "cat-A",   role: .category),
            makeNode(id: "tool-1",  role: .tool, isSelected: true),
            makeNode(id: "tool-2",  role: .tool),
        ]

        let result = DeclutterRule.decide(mode: .overview, nodes: nodes)

        #expect((result["tool-1"] ?? 0) > 0, "selected tool must be visible even in overview")
        #expect((result["tool-2"] ?? 1) == 0, "unselected tool must be hidden in overview")
    }

    @Test func overviewCountsNoBadgesMoreThanCategoryPillsPlusCore() {
        // Build 3 categories + 10 tools (none selected).
        var nodes: [NodeVisibilityInput] = [
            makeNode(id: "core", role: .core),
        ]
        for i in 0..<3 {
            nodes.append(makeNode(id: "cat-\(i)", role: .category))
        }
        for i in 0..<10 {
            nodes.append(makeNode(id: "tool-\(i)", role: .tool))
        }

        let result = DeclutterRule.decide(mode: .overview, nodes: nodes)

        let visibleCount = result.values.filter { $0 > 0 }.count
        // Only core + 3 categories should be visible (tools hidden).
        #expect(visibleCount == 4, "overview should emit core + categories only, got \(visibleCount)")
    }

    // MARK: Pocket mode

    @Test func pocketRevealsOpenCategoryTools() {
        let nodes: [NodeVisibilityInput] = [
            makeNode(id: "core",   role: .core),
            makeNode(id: "cat-A",  role: .category),
            makeNode(id: "tool-open-1", role: .tool, inOpenPocket: true,  depthScale: 1.4),
            makeNode(id: "tool-open-2", role: .tool, inOpenPocket: true,  depthScale: 1.2),
            makeNode(id: "tool-other",  role: .tool, inOpenPocket: false, depthScale: 1.0),
        ]

        let result = DeclutterRule.decide(mode: .pocket, nodes: nodes)

        #expect((result["tool-open-1"] ?? 0) > 0, "open-pocket tool should be visible")
        #expect((result["tool-open-2"] ?? 0) > 0, "open-pocket tool should be visible")
        #expect((result["tool-other"] ?? 1) == 0, "other-category tool should be hidden in pocket mode")
    }

    @Test func pocketCoreAndCategoriesStayVisible() {
        let nodes: [NodeVisibilityInput] = [
            makeNode(id: "core",  role: .core),
            makeNode(id: "cat-A", role: .category),
            makeNode(id: "cat-B", role: .category),
        ]

        let result = DeclutterRule.decide(mode: .pocket, nodes: nodes)

        #expect((result["core"]  ?? 0) > 0)
        #expect((result["cat-A"] ?? 0) > 0)
        #expect((result["cat-B"] ?? 0) > 0)
    }

    @Test func pocketFadesOtherCategoryToolsToZero() {
        let nodes: [NodeVisibilityInput] = [
            makeNode(id: "tool-in",  role: .tool, inOpenPocket: true),
            makeNode(id: "tool-out", role: .tool, inOpenPocket: false),
        ]

        let result = DeclutterRule.decide(mode: .pocket, nodes: nodes)

        #expect((result["tool-out"] ?? 1) == 0)
    }

    // MARK: Selected tool always visible

    @Test func selectedToolVisibleInAnyMode() {
        for mode in [ViewMode.overview, ViewMode.pocket, ViewMode.node] {
            let nodes: [NodeVisibilityInput] = [
                makeNode(id: "selected", role: .tool, isSelected: true),
            ]
            let result = DeclutterRule.decide(mode: mode, nodes: nodes)
            #expect((result["selected"] ?? 0) > 0, "selected tool hidden in mode \(mode)")
        }
    }

    // MARK: Screen-space collision

    @Test func collisionReducesLowerPriorityWhenOverlapping() {
        // Two pocket tools at the same screen position → lower orbit gets reduced.
        // depthScale 2.0 → distance = 18/2 = 9 world units, which is between
        // ToolLabelFade.nearDistance (6) and farDistance (18), so base opacity > 0.
        // Without that both nodes resolve to 0 and the collision branch never fires.
        let high = makeNode(id: "inner", role: .tool, orbit: 1, inOpenPocket: true, depthScale: 2.0, screen: CGPoint(x: 100, y: 100))
        let low  = makeNode(id: "outer", role: .tool, orbit: 3, inOpenPocket: true, depthScale: 2.0, screen: CGPoint(x: 110, y: 100))
        // 10 pt apart — well inside default 36 pt radius.

        let result = DeclutterRule.decide(mode: .pocket, nodes: [high, low], collisionRadiusPt: 36)

        let highOpacity = result["inner"] ?? 0
        let lowOpacity  = result["outer"] ?? 0

        #expect(highOpacity > lowOpacity, "inner-orbit badge should survive collision, outer should be reduced")
    }

    @Test func noCollisionWhenFarApart() {
        let a = makeNode(id: "a", role: .category, screen: CGPoint(x: 0,   y: 0))
        let b = makeNode(id: "b", role: .category, screen: CGPoint(x: 200, y: 0))
        // 200 pt apart — outside 36 pt radius; both should be fully visible.

        let result = DeclutterRule.decide(mode: .pocket, nodes: [a, b], collisionRadiusPt: 36)

        #expect((result["a"] ?? 0) == 1.0)
        #expect((result["b"] ?? 0) == 1.0)
    }

    @Test func selectedBeatsCategoryInCollision() {
        // Selected tool at same position as category badge → category gets reduced.
        let selected = makeNode(id: "sel",  role: .tool,     isSelected: true, screen: CGPoint(x: 50, y: 50))
        let cat      = makeNode(id: "cat",  role: .category,                   screen: CGPoint(x: 55, y: 50))

        let result = DeclutterRule.decide(mode: .overview, nodes: [selected, cat], collisionRadiusPt: 36)

        #expect((result["sel"] ?? 0) > (result["cat"] ?? 0))
    }

    // MARK: Output invariants

    @Test func allOpacitiesClampedToUnitInterval() {
        var nodes: [NodeVisibilityInput] = []
        nodes.append(makeNode(id: "core", role: .core, depthScale: 0.001))
        for i in 0..<5 {
            nodes.append(makeNode(id: "cat-\(i)", role: .category, depthScale: 5.0, screen: CGPoint(x: CGFloat(i * 5), y: 0)))
        }
        for i in 0..<10 {
            nodes.append(makeNode(id: "tool-\(i)", role: .tool, inOpenPocket: true, depthScale: 0.6, screen: CGPoint(x: CGFloat(i * 3), y: 0)))
        }

        for mode in [ViewMode.overview, ViewMode.pocket] {
            let result = DeclutterRule.decide(mode: mode, nodes: nodes)
            for (id, opacity) in result {
                #expect(opacity >= 0 && opacity <= 1, "opacity out of [0,1] for \(id) in mode \(mode): \(opacity)")
            }
        }
    }

    @Test func deterministicForFixedInput() {
        let nodes: [NodeVisibilityInput] = [
            makeNode(id: "core",   role: .core),
            makeNode(id: "cat-A",  role: .category, screen: CGPoint(x: 10, y: 10)),
            makeNode(id: "tool-1", role: .tool, inOpenPocket: true, depthScale: 1.1, screen: CGPoint(x: 12, y: 10)),
        ]

        let first  = DeclutterRule.decide(mode: .pocket, nodes: nodes)
        let second = DeclutterRule.decide(mode: .pocket, nodes: nodes)

        #expect(first == second, "DeclutterRule must be deterministic")
    }
}
