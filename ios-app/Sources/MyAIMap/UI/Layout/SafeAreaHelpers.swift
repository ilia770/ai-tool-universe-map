import SwiftUI

/// Safe-area utilities. The universe canvas always edges-out to fill
/// the screen, but its overlays must respect the notch / home
/// indicator / status bar.
extension View {
    /// Pin a view to the top safe area as an inset, matching the way
    /// the search dock and toolbar live above the universe canvas.
    func topSafeAreaInset<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        safeAreaInset(edge: .top, spacing: 0) { content() }
    }

    /// Pin a view to the bottom safe area — the input bar above the
    /// keyboard, the bottom sheet handle, etc.
    func bottomSafeAreaInset<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { content() }
    }

    /// Pad bottom by the system home-indicator height even when the
    /// view edges-out. Helps when the inner content is interactive
    /// (you don't want a tap target overlapping the home indicator).
    func avoidHomeIndicator() -> some View {
        padding(.bottom, BrandSpacing.l.value)
    }
}

/// Reads the current safe-area insets into the environment so deep
/// children can compute their own offsets without re-querying.
struct SafeAreaReporter: ViewModifier {
    @Binding var insets: EdgeInsets

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { insets = proxy.safeAreaInsets }
                        .onChange(of: proxy.safeAreaInsets) { _, new in insets = new }
                }
            }
    }
}

extension View {
    func reportSafeAreaInsets(into binding: Binding<EdgeInsets>) -> some View {
        modifier(SafeAreaReporter(insets: binding))
    }
}
