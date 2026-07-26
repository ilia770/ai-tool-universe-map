import Foundation

/// Compact detail presentation state. The route retains the precise map mode
/// that must be restored after the system sheet is dismissed.
struct DetailRoute: Identifiable, Equatable {
    let toolID: String
    let returnMode: UniverseMode

    var id: String { toolID }
}
