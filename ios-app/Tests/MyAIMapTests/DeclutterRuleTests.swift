import Testing
@testable import MyAIMap

@Suite("DeclutterRule")
struct DeclutterRuleTests {
    @Test func overviewShowsCategoriesAndSelectionOnly() {
        let d = DeclutterRule.badgeVisibility(
            kind: .tool(category: .coding),
            activeCategory: .core, selectedToolID: "x", thisID: "y", depthScale: 1.0)
        #expect(d == 0)  // unselected tool hidden in overview
    }
    @Test func categoryPillAlwaysVisibleInOverview() {
        let d = DeclutterRule.badgeVisibility(
            kind: .category(.coding), activeCategory: .core,
            selectedToolID: "x", thisID: "coding", depthScale: 1.0)
        #expect(d > 0.9)
    }
    @Test func pocketRevealsItsTools() {
        let d = DeclutterRule.badgeVisibility(
            kind: .tool(category: .coding), activeCategory: .coding,
            selectedToolID: "x", thisID: "y", depthScale: 1.0)
        #expect(d > 0.5)
    }
    @Test func distanceFadesOutFarNodes() {
        let near = DeclutterRule.badgeVisibility(
            kind: .tool(category: .coding), activeCategory: .coding,
            selectedToolID: "x", thisID: "y", depthScale: 1.2)
        let far = DeclutterRule.badgeVisibility(
            kind: .tool(category: .coding), activeCategory: .coding,
            selectedToolID: "x", thisID: "y", depthScale: 0.4)
        #expect(near > far)
    }
}
