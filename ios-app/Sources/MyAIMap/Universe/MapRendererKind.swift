/// Typed release renderer selection. Legacy RealityKit files remain in-tree
/// but are not allocated by the mounted map path.
enum MapRendererKind: Sendable, Equatable {
    case constellation2D

    static let release: Self = .constellation2D
}
