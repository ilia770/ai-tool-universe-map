import SwiftUI

/// Adaptive layout helpers. The same `UniverseScreen` should render
/// as a single-column iPhone overlay, a NavigationSplitView on iPad,
/// and a windowed scene on visionOS without duplicating the view tree
/// per device.
///
/// All decisions here go through size classes, not device idiom
/// checks — that's the Apple-recommended path and it survives the
/// inevitable foldable / external display moments.
enum AdaptiveLayout {

    /// True on compact-width screens (iPhone in any orientation,
    /// iPad in slide-over). A missing size class is treated as compact
    /// because UI-test / hosted SwiftUI roots can report nil before the
    /// environment resolves, and the bottom sheet is the safer fallback.
    @MainActor
    static func isCompact(_ horizontal: UserInterfaceSizeClass?) -> Bool {
        switch horizontal {
        case .compact, .none:
            return true
        case .regular:
            return false
        @unknown default:
            return true
        }
    }

    /// Recommended bottom-sheet detents per size class. Compact gets
    /// peek / mid / expanded; regular skips peek (the side rail
    /// covers that role).
    static func sheetDetents(for horizontal: UserInterfaceSizeClass?) -> Set<PresentationDetent> {
        switch horizontal {
        case .compact, .none:
            return [.height(120), .fraction(0.5), .large]
        case .regular:
            return [.fraction(0.4), .large]
        @unknown default:
            return [.medium, .large]
        }
    }

    /// Recommended max content width — keeps reading lines from
    /// stretching to absurd lengths on iPad / Mac Catalyst.
    static let readableContentMaxWidth: CGFloat = 720
}

/// Drops a value into the SwiftUI environment so views deep in the
/// tree know whether they're compact without re-reading the size
/// class.
private struct CompactKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var isCompactLayout: Bool {
        get { self[CompactKey.self] }
        set { self[CompactKey.self] = newValue }
    }
}

extension View {
    /// Reads the horizontal size class and injects `isCompactLayout`
    /// into the environment so descendants don't have to read it
    /// themselves. Apply at the top of `UniverseScreen`.
    @MainActor
    func resolveCompactLayout(_ horizontal: UserInterfaceSizeClass?) -> some View {
        environment(\.isCompactLayout, AdaptiveLayout.isCompact(horizontal))
    }
}

/// A container that switches between a sheet overlay (compact) and an
/// inline trailing panel (regular). Use as the root for the tool
/// detail.
struct AdaptiveDetailContainer<Detail: View, Universe: View>: View {
    @ViewBuilder var universe: () -> Universe
    @ViewBuilder var detail: () -> Detail
    @Binding var detailVisible: Bool

    @Environment(\.horizontalSizeClass) private var horizontal

    var body: some View {
        Group {
            if AdaptiveLayout.isCompact(horizontal) {
                universe()
                    .sheet(isPresented: $detailVisible) {
                        detail()
                            .presentationDetents(AdaptiveLayout.sheetDetents(for: horizontal))
                            .presentationDragIndicator(.visible)
                            .presentationBackgroundInteraction(.enabled)
                            .presentationCornerRadius(BrandRadius.card.value)
                            .presentationBackground(.thinMaterial)
                    }
            } else {
                HStack(spacing: 0) {
                    universe()
                        .frame(maxWidth: .infinity)
                    if detailVisible {
                        detail()
                            .frame(width: 360)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .brandAnimation(BrandMotion.entry, value: detailVisible)
            }
        }
    }
}
