import SwiftUI

/// App entry point.
///
/// Phase 2: injects the single `UniverseViewModel` via environment per
/// the Phase 2 decision log. product-v2 P1 adds the persisted
/// `AppSettings` store alongside it.
@main
struct MyAIMapApp: App {
    @State private var model = UniverseViewModel()
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            UniverseScreen()
                .environment(model)
                .environment(settings)
                .preferredColorScheme(.dark)
        }
    }
}
