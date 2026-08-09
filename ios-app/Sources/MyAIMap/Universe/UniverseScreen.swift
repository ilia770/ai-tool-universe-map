import SwiftUI

/// App entry point for the AI Universe Map.
///
/// The production prototype now lives in `UniverseMapView`: SwiftUI
/// constellation renderer for the primary map, plus glass overlay and sheets.
struct UniverseScreen: View {
    var body: some View {
        UniverseMapView()
    }
}

#Preview {
    UniverseScreen()
        .environment(UniverseViewModel())
}
