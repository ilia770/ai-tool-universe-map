import SwiftUI

/// Minimal floating glass reveal for the focused tool-planet (principle:
/// minimal typography, large negative space, glass surface). One primary
/// action routes to the full detail.
struct SpatialRevealCard: View {
    let toolName: String
    let categoryName: String
    let summary: String
    let tint: Color
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                Text(categoryName.uppercased())
                    .brandEyebrow()
                    .foregroundStyle(tint.opacity(0.9))
                Text(toolName)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(BrandColor.textPrimary)
                    .lineLimit(1)
                Text(summary)
                    .font(.system(.footnote))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: BrandSpacing.s.value) {
                    Text("Open")
                        .font(BrandTypography.controlLabel)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, BrandSpacing.xl.value)
            .padding(.horizontal, BrandSpacing.xl.value)
            .liquidGlass(in: RoundedRectangle(cornerRadius: BrandRadius.revealCard.value, style: .continuous), tint: tint.opacity(0.4))
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98, haptic: nil, pressedOpacity: 0.92))
        .frame(maxWidth: 340)
        .accessibilityLabel("Open \(toolName) detail")
    }
}
