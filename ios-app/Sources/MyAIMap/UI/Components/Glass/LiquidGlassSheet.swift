import SwiftUI

/// Canonical glass-sheet presentation chrome — captures the repeated large
/// detent + drag indicator + 42pt corner radius combo that `RootShell` applies
/// to its presented sheets (account, add-tool). Adds no styling of its own; it
/// only groups the existing presentation modifiers so every full sheet reads
/// identically.
struct LiquidGlassSheet: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(BrandRadius.sheetPresentation.value)
    }
}

extension View {
    /// Applies the canonical full-height glass-sheet presentation chrome
    /// (large detent + drag indicator + 42pt corners). See `LiquidGlassSheet`.
    func liquidGlassSheet() -> some View {
        modifier(LiquidGlassSheet())
    }
}
