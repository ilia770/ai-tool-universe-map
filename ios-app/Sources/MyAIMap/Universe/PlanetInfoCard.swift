import SwiftUI

struct PlanetInfoCard: View {
    let planet: PlanetData
    let selectedTool: Tool
    let isFocusedOnTool: Bool
    let mode: UniverseMode
    let onOpenDetails: () -> Void

    var body: some View {
        Group {
            if isFocusedOnTool {
                Button(action: onOpenDetails) {
                    cardContent
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: .light, pressedOpacity: 0.94))
            } else {
                cardContent
            }
        }
        .accessibilityLabel("Selected planet details")
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 12) {
            statusOrb

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(modeLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.78))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(planet.swiftUIColor, in: Capsule())

                    Text(isFocusedOnTool ? selectedTool.name : planet.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(BrandColor.textPrimary)
                        .lineLimit(1)
                }

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(BrandColor.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isFocusedOnTool {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(planet.swiftUIColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous),
            tint: planet.swiftUIColor,
            strokeStrength: 0.09
        )
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
}
