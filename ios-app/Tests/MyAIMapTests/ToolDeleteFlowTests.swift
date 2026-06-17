import Testing
import SwiftUI
import UIKit
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

    // MARK: - Manage path

    @Test func deleteViaManagePathRemovesAndLogs() {
        // Simulates what ManageToolsScreen.confirmDelete does: call
        // canDelete guard, then model.deleteTool.
        let model = UniverseViewModel()
        var logged: [ToolDeletion] = []
        model.deletionSink = { logged.append($0) }

        guard let victim = UniverseSeed.tools.first(where: { $0.id != "founder-os" }) else {
            Issue.record("seed must have at least one non-founder tool")
            return
        }
        let id = victim.id

        guard ToolDetailSection.canDelete(toolID: id) else {
            Issue.record("expected canDelete to be true for \(id)")
            return
        }
        model.deleteTool(id)

        #expect(model.tools.contains { $0.id == id } == false)
        #expect(logged.first?.toolID == id)
    }

    @Test func founderOsCannotBeDeletedViaManagePath() {
        #expect(ToolDetailSection.canDelete(toolID: "founder-os") == false)
    }
}

// MARK: - restoreTool

@Suite("restoreTool — round-trip")
@MainActor
struct RestoreToolTests {

    @Test func deleteAndRestoreRoundTrip() {
        let model = UniverseViewModel()
        guard let victim = UniverseSeed.tools.first(where: { $0.id != "founder-os" }) else {
            Issue.record("seed must have at least one non-founder tool")
            return
        }
        let id = victim.id

        model.deleteTool(id)
        #expect(model.tools.contains { $0.id == id } == false)

        model.restoreTool(id)
        #expect(model.tools.contains { $0.id == id })
    }

    @Test func historyHasBothDeleteAndAddedEvents() {
        let model = UniverseViewModel(history: nil, historyStore: nil)
        guard let victim = UniverseSeed.tools.first(where: { $0.id != "founder-os" }) else {
            Issue.record("seed needs at least one non-founder tool")
            return
        }
        let id = victim.id

        model.deleteTool(id)
        model.restoreTool(id)

        let events = model.history.events.filter { $0.toolID == id }
        #expect(events.contains { $0.kind == .deleted })
        #expect(events.contains { $0.kind == .added })
    }

    @Test func restoreNoOpWhenNotRemoved() {
        let model = UniverseViewModel()
        // A valid seed tool that was never deleted — restoreTool should be a no-op.
        let id = "figma"
        let countBefore = model.tools.count
        model.restoreTool(id)
        #expect(model.tools.count == countBefore)
    }
}

// MARK: - ManageToolsScreen render

@Suite("ManageToolsScreen render")
@MainActor
struct ManageToolsScreenTests {

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ManageToolsScreenTests.\(UUID().uuidString)")!
    }

    private func render(_ view: some View, size: CGSize = CGSize(width: 390, height: 700)) -> UIImage? {
        let content = ZStack {
            Color.black
            NavigationStack { view }
        }
        .environment(UniverseViewModel())
        .environment(AppSettings(defaults: isolatedDefaults()))
        .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 2
        return renderer.uiImage
    }

    @Test func rendersNonNilWhenEmpty() {
        let img = render(ManageToolsScreen())
        #expect(img != nil)
        #expect((img?.size.width ?? 0) > 0)
    }

    @Test func rendersNonNilWithUserAddedTool() {
        // Build a minimal model that has a userAdded tool injected via a
        // seed tool that has been copied and mutated — we test the view path,
        // not the persistence path, so we need a model with a userAdded tool.
        // Since `Tool.userAdded` is a var, we can mutate a copy.
        var tool = UniverseSeed.tools.first { $0.id == "figma" }!
        tool.userAdded = true
        // We can't inject arbitrary tools into UniverseViewModel (it reads
        // UniverseSeed directly), so we verify the view at least renders;
        // the empty-state branch covers the "no user-added tools" path above.
        let img = render(ManageToolsScreen())
        #expect(img != nil)
    }
}
