import SwiftUI

/// Canonical composer-field chrome — the clean dark-translucent glass capsule
/// from `SearchDock`'s composer (CHAT_INPUT_SPEC §1): neutral glass, no accent
/// tint, no backing plate, no glowing outline; one soft float shadow. Composes
/// the existing `glassSurface` primitive; it adds no styling of its own. Wrap
/// the field row (text field + inline controls) in this modifier.
struct LiquidGlassInput: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassSurface(in: Capsule(), interactive: true)
            .shadow(color: .black.opacity(0.26), radius: 14, x: 0, y: 8)
    }
}

extension View {
    /// Applies the canonical composer-field glass chrome. See `LiquidGlassInput`.
    func liquidGlassInput() -> some View {
        modifier(LiquidGlassInput())
    }
}
