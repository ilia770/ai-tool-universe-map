import Foundation

/// Product identities shared by persistence and presentation layers.
///
/// Keeping this outside the renderer prevents durable catalog validation from
/// depending on RealityKit/SwiftUI presentation types.
enum UniverseIdentity {
    static let centralCoreToolID = "founder-os"
}
