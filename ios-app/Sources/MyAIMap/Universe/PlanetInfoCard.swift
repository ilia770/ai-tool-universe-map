import SwiftUI

struct PlanetInfoCard: View {
    let planet: PlanetData
    let selectedTool: Tool
    let isFocusedOnTool: Bool
    let mode: UniverseMode
    let onOpenDetails: () -> Void
    /// Trailing info glyph scales with Dynamic Type within the compact overlay.
    @ScaledMetric(relativeTo: .subheadline) private var infoGlyph: CGFloat = 18

    var body: some View {
        content
            // Compact floating map overlay: text scales with Dynamic Type but is
            // clamped so the single-row card does not clip over the map.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    @ViewBuilder
    private var content: some View {
        if isFocusedOnTool {
            Button(action: onOpenDetails) {
                cardContent
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.94))
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Opens details")
            .accessibilityIdentifier("PlanetInfoCard.SelectedDetails")
        } else {
            cardContent
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier("PlanetInfoCard.SelectedBranch")
        }
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 12) {
            statusOrb

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(modeLabel)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(.black.opacity(0.78))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(planet.swiftUIColor, in: Capsule())

                    Text(isFocusedOnTool ? selectedTool.name : planet.title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(BrandColor.textPrimary)
                        .lineLimit(2)
                }

                Text(subtitle)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(BrandColor.textMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if isFocusedOnTool {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: infoGlyph, weight: .semibold))
                    .foregroundStyle(planet.swiftUIColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // Translucent card: ultraThinMaterial frosts the universe behind it
        // (light back-blur) instead of a flat opaque fill.
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
                .stroke(planet.swiftUIColor.opacity(0.45), lineWidth: 0.5)
        }
    }

    private var statusOrb: some View {
        ZStack {
            Circle()
                .fill(planet.swiftUIColor.opacity(0.20))
                .frame(width: 44, height: 44)
            Circle()
                .stroke(planet.swiftUIColor.opacity(isFocusedOnTool ? 0.82 : 0.42), lineWidth: 1.2)
                .frame(width: isFocusedOnTool ? 34 : 30, height: isFocusedOnTool ? 34 : 30)
            Circle()
                .fill(planet.swiftUIColor)
                .frame(width: isFocusedOnTool ? 14 : 11, height: isFocusedOnTool ? 14 : 11)
                .shadow(color: planet.swiftUIColor.opacity(0.8), radius: 12)
        }
    }

    private var modeLabel: String {
        switch mode {
        case .overview:
            return "OVERVIEW"
        case .branchFocus:
            return "BRANCH"
        case .toolSelected:
            return "TOOL"
        case .detail:
            return "DETAIL"
        case .chatOpen:
            return "CHAT"
        }
    }

    private var subtitle: String {
        if isFocusedOnTool {
            return selectedTool.summary
        }
        if planet.id == .core {
            return "Choose a branch to reveal its tools"
        }
        if planet.id == .media {
            return "Tap Remotion or a nearby satellite to inspect the Media branch"
        }
        return "\(planet.toolCount) satellites · \(planet.subtitle)"
    }

    private var accessibilityLabel: String {
        if isFocusedOnTool {
            return "Selected tool, \(selectedTool.name), \(subtitle)"
        }
        return "Selected branch, \(planet.title), \(subtitle)"
    }
}
