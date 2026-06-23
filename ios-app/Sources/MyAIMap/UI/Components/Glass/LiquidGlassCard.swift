import SwiftUI

/// Canonical glass container for a rounded "card" role — wraps arbitrary
/// content in the `glassSurface(in: RoundedRectangle(...))` pattern that the
/// empty-state onboarding card uses today. Composes the existing `glassSurface`
/// primitive and `BrandRadius` tokens; it adds no styling of its own.
struct LiquidGlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    var tint: Color?
    var interactive: Bool
    @ViewBuilder var content: () -> Content

    init(
        cornerRadius: CGFloat = 28,
        tint: Color? = nil,
        interactive: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.interactive = interactive
        self.content = content
    }

    var body: some View {
        content()
            .glassSurface(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint,
                interactive: interactive
            )
    }
}
