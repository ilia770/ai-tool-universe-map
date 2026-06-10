import SwiftUI

/// Scroll-driven 3D effects. iOS 17 introduced `scrollTransition`
/// which lets every row react to its own visibility; we wrap it in
/// brand-aware modifiers so call sites stay readable.
///
/// Usage:
///
/// ```swift
/// ScrollView(.horizontal) {
///     LazyHStack { ForEach(categories) { CategoryChip($0).scrollDepth() } }
/// }
/// ```
extension View {
    /// Subtle scale + rotation as a row scrolls toward the screen
    /// edge. Mirrors the way Apple Music's "now playing" rotates
    /// album art on hand-off.
    func scrollDepth() -> some View {
        scrollTransition(.interactive(timingCurve: .easeInOut)) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                .rotation3DEffect(
                    .degrees(phase.value * 12),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(phase.isIdentity ? 1 : 0.75)
        }
    }

    /// For vertical lists. Rows entering from the bottom scale up
    /// gently — used on the bottom-sheet tool list.
    func scrollLift() -> some View {
        scrollTransition(.interactive(timingCurve: .easeOut)) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                .opacity(phase.isIdentity ? 1 : 0.55)
                .blur(radius: phase.isIdentity ? 0 : 1.5)
        }
    }

    /// Apply when a heading should fade into the navigation bar as
    /// the user scrolls — same trick the App Store's product page
    /// uses.
    func scrollHeaderFade() -> some View {
        scrollTransition(axis: .vertical) { content, phase in
            content
                .opacity(1 - Double(abs(phase.value)) * 0.8)
                .blur(radius: Double(abs(phase.value)) * 3)
        }
    }
}

/// Pull-to-refresh indicator with the same Liquid Glass treatment as
/// the rest of the app. Drop into the toolbar of a scroll view.
struct PullRefreshIndicator: View {
    var isRefreshing: Bool

    var body: some View {
        HStack(spacing: BrandSpacing.s.value) {
            ProgressOrb(color: BrandColor.core, size: 10)
            Text(isRefreshing ? "Syncing" : "Pull to refresh")
                .font(BrandTypography.chip)
                .foregroundStyle(BrandColor.textSecondary)
        }
        .padding(.horizontal, BrandSpacing.m.value)
        .padding(.vertical, BrandSpacing.s.value)
        .liquidGlass(cornerRadius: BrandRadius.pill.value)
    }
}
