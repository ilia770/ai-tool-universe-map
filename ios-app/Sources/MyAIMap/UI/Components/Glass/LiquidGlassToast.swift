import SwiftUI

/// Canonical glass toast banner — a labeled, icon-led glass capsule generalized
/// from `CopyToast`'s private `CopyToastBanner`. Composes the existing
/// `glassSurface` primitive + `BrandColor`/`BrandSpacing` tokens; it adds no
/// styling of its own. `CopyToast` builds its confirmation banner on this; new
/// transient confirmations should reuse it rather than re-inlining the capsule.
struct LiquidGlassToast: View {
    let message: String
    var systemImage: String = "checkmark.circle.fill"
    var tint: Color = BrandColor.core.opacity(0.10)

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(BrandTypography.controlLabel)
            .foregroundStyle(.white)
            .labelStyle(.titleAndIcon)
            .symbolRenderingMode(.hierarchical)
            .padding(.horizontal, BrandSpacing.l.value)
            .padding(.vertical, BrandSpacing.sm.value)
            .glassSurface(in: Capsule(), tint: tint)
    }
}
