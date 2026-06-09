import SwiftUI

/// App entry point.
///
/// Phase 1: a native product shell around the RealityKit universe scene.
@main
struct MyAIMapApp: App {
    var body: some Scene {
        WindowGroup {
            UniverseScreen()
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
        }
    }
}
