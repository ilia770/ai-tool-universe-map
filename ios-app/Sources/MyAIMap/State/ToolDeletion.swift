import Foundation

/// A record that a tool was removed from the universe. P2 emits this through
/// `UniverseViewModel.deletionSink`; P4's history store is the eventual consumer.
/// Kept deliberately self-contained (no P4 type) so the two parts merge cleanly.
struct ToolDeletion: Equatable, Sendable {
    let toolID: String
    let toolName: String
    let category: ToolCategoryId
    let date: Date

    init(tool: Tool, date: Date = Date()) {
        self.toolID = tool.id
        self.toolName = tool.name
        self.category = tool.category
        self.date = date
    }
}
