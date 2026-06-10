import SwiftUI

/// App entry point.
///
/// Phase 2: injects the single `UniverseViewModel` via environment per
/// the Phase 2 decision log.
@main
struct MyAIMapApp: App {
    @State private var model = UniverseViewModel()

    var body: some Scene {
        WindowGroup {
            UniverseScreen()
                .environment(model)
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
        }
    }
}
