import SwiftUI

/// App entry point.
///
/// Phase 0: a single window with the `UniverseView` placeholder scene.
/// Later phases will swap this for a `NavigationStack` + bottom sheet
/// per the iPhone overlay patterns in `docs/DESIGN_REFS.md`.
@main
struct MyAIMapApp: App {
    var body: some Scene {
        WindowGroup {
            UniverseView()
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
        }
    }
}
