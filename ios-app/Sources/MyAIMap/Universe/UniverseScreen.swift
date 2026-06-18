import SwiftUI

/// App entry point for the AI Universe Map.
///
/// The production prototype now lives in `UniverseMapView`: native RealityKit
/// scene for the 3D universe, SwiftUI for the glass overlay and sheets.
struct UniverseScreen: View {
    var body: some View {
        UniverseMapView()
    }
}

#Preview {
    UniverseScreen()
        .environment(UniverseViewModel())
}
