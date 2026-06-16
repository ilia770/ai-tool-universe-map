import Testing
@testable import MyAIMap

@Suite("HistoryChipModel — chip presentation logic")
@MainActor
struct HistoryStripModelTests {

    private var figmaID: String {
        UniverseSeed.tools.first(where: { $0.id == "figma" })?.id
            ?? UniverseSeed.tools[0].id
    }

    @Test func chipUsesSeedToolName() {
        let tool = UniverseSeed.tools.first { $0.id == figmaID }!
        let event = ToolHistory.Event(id: .init(), toolID: figmaID,
                                      kind: .added, timestamp: .init())
        let chip = HistoryChipModel(event: event)
        #expect(chip.title == tool.name)
        #expect(chip.isDeleted == false)
    }

    @Test func deletedEventIsMarkedAndAccessible() {
        let event = ToolHistory.Event(id: .init(), toolID: figmaID,
                                      kind: .deleted, timestamp: .init())
        let chip = HistoryChipModel(event: event)
        #expect(chip.isDeleted)
        #expect(chip.accessibilityLabel.contains("Removed"))
    }

    @Test func unknownToolFallsBackToRawID() {
        let event = ToolHistory.Event(id: .init(), toolID: "ghost-tool",
                                      kind: .added, timestamp: .init())
        let chip = HistoryChipModel(event: event)
        #expect(chip.title == "ghost-tool")
    }
}
