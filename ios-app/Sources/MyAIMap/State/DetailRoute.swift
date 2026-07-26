import Foundation

/// Compact detail presentation state. The route retains the precise map mode
/// that must be restored after the system sheet is dismissed.
struct DetailRoute: Identifiable, Equatable {
    /// Stable for the lifetime of one presented sheet. Related-tool replacement
    /// changes content, not the system presentation identity.
    let id: UUID
    let toolID: String
    let returnMode: UniverseMode

    init(id: UUID = UUID(), toolID: String, returnMode: UniverseMode) {
        self.id = id
        self.toolID = toolID
        self.returnMode = returnMode
    }
}
