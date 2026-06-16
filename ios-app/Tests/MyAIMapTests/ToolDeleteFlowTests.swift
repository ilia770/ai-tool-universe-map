import Testing
@testable import MyAIMap

@Suite("Tool delete flow — confirm wiring")
@MainActor
struct ToolDeleteFlowTests {

    @Test func confirmDeleteRemovesToolAndLogsIt() {
        let model = UniverseViewModel()
        var logged: [ToolDeletion] = []
        model.deletionSink = { logged.append($0) }
        model.selectCategory(.design)
        guard let victim = UniverseSeed.tools(in: .design).first else {
            Issue.record("seed needs a design tool")
            return
        }
        model.selectTool(victim.id)

        // Mirrors ToolDetailSection.performDelete.
        model.deleteTool(victim.id)

        #expect(model.tools.contains { $0.id == victim.id } == false)
        #expect(logged.first?.toolID == victim.id)
    }

    @Test func founderCoreIsNotDeletable() {
        // ToolDetailSection.canDelete mirror: founder-os is excluded.
        #expect(ToolDetailSection.canDelete(toolID: "founder-os") == false)
        #expect(ToolDetailSection.canDelete(toolID: "figma"))
    }
}
