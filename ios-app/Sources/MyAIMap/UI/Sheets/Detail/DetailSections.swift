import SwiftUI

/// Eyebrow + content wrapper, matching the web `Section` (uppercase label).
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            Text(title)
                .brandEyebrow()
                .foregroundStyle(BrandColor.textMuted)
            content
        }
    }
}

/// "What it does": 3-line clamp with an inline More/Less toggle.
struct ClampText: View {
    let text: String
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
            Text(text)
                .font(BrandTypography.body)
                .foregroundStyle(BrandColor.textSecondary)
                .lineSpacing(3)
                .lineLimit(expanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)

            if text.count > 140 {  // cheap clampable heuristic — avoids a measure pass
                Button(expanded ? "Less" : "More") {
                    BrandHaptics.fire(.light)
                    withAnimation(reduceMotion ? nil : BrandMotion.flow) { expanded.toggle() }
                }
                .font(BrandTypography.chip)
                .foregroundStyle(BrandColor.cyan)
                .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
            }
        }
    }
}

/// Killer features: staggered bulleted list with an accent marker.
struct KillerFeaturesList: View {
    let features: [String]
    let accent: Color
    let appeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            ForEach(Array(features.enumerated()), id: \.element) { index, feature in
                HStack(alignment: .top, spacing: BrandSpacing.s.value) {
                    Text("▸").foregroundStyle(accent)
                    Text(feature)
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(x: reduceMotion ? 0 : (appeared ? 0 : -6))
                .animation(
                    reduceMotion ? nil
                        : BrandMotion.flow.delay(0.06 + Double(min(index, 6)) * 0.03),
                    value: appeared
                )
            }
        }
    }
}

/// Strengths / Watch-outs as a two-column block.
struct StrengthsWatchouts: View {
    let advantages: [String]
    let weaknesses: [String]

    var body: some View {
        HStack(alignment: .top, spacing: BrandSpacing.l.value) {
            if !advantages.isEmpty {
                DetailSection(title: "Strengths") {
                    bulletColumn(advantages, marker: "+", color: BrandColor.lime)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !weaknesses.isEmpty {
                DetailSection(title: "Watch-outs") {
                    bulletColumn(weaknesses, marker: "–", color: BrandColor.amber)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func bulletColumn(_ items: [String], marker: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text(marker).foregroundStyle(color)
                    Text(item)
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Pricing card: model eyebrow + summary, on a faint glass plate.
struct PricingCard: View {
    let pricing: ToolPricing

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
            Text(pricing.model.rawValue)
                .brandEyebrow()
                .foregroundStyle(BrandColor.textMuted)
            Text(pricing.summary)
                .font(BrandTypography.body)
                .foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BrandSpacing.m.value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
    }
}
