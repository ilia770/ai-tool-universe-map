import SwiftUI

/// Canonical inline action-chip chrome — the neutral capsule fill + hairline
/// used by `SearchDock`'s tool-access and add-suggestion chips
/// (LIQUID_GLASS_VISUAL_SPEC §3/C6): `.white.opacity(0.08)` fill with a
/// `.white.opacity(0.10)` hairline, no accent on the fill. Accent (if any) lives
/// on the chip's leading glyph, supplied by the caller. Adds no styling beyond
/// the shared chip chrome.
struct ActionChipBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.white.opacity(0.08), in: Capsule())
            .overlay { Capsule().stroke(.white.opacity(0.10), lineWidth: 0.5) }
    }
}

extension View {
    /// Applies the canonical inline action-chip chrome. See `ActionChipBackground`.
    func actionChipBackground() -> some View {
        modifier(ActionChipBackground())
    }
}
