import SwiftUI

/// Canonical inline action-chip chrome — the neutral capsule fill + hairline
/// used by `SearchDock`'s tool-access and add-suggestion chips
/// (LIQUID_GLASS_VISUAL_SPEC §3/C6): a `BrandColor` neutral fill and hairline,
/// with no accent on the fill. Accent (if any) lives on the chip's leading
/// glyph, supplied by the caller. Adds no styling beyond the shared chip chrome.
struct ActionChipBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, BrandSpacing.m.value)
            .padding(.vertical, BrandSpacing.s.value)
            .frame(minHeight: HitArea.minimum)
            .background(BrandColor.card, in: Capsule())
            .overlay { Capsule().stroke(BrandColor.stroke, lineWidth: 0.5) }
    }
}

extension View {
    /// Applies the canonical inline action-chip chrome. See `ActionChipBackground`.
    func actionChipBackground() -> some View {
        modifier(ActionChipBackground())
    }
}
