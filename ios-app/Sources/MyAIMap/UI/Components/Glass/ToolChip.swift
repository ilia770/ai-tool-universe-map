import SwiftUI

/// Canonical compact tool/source chip — favicon-sized logo + short name, sized
/// to content. Promoted verbatim from `ChatScreen`'s private `ChatToolChip`
/// (LIQUID_GLASS_VISUAL_SPEC §3): the shared neutral action-chip chrome; accent
/// lives only on the tool logo glyph. Adds no styling of its own beyond that
/// shared chip chrome.
struct ToolChip: View {
    let tool: Tool
    let onOpen: () -> Void

    private var category: ToolCategory {
        UniverseSeed.category(tool.category)
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: BrandSpacing.s.value) {
                ToolLogoView(tool: tool, accent: category.color.swiftUIColor, size: 16)
                Text(tool.name)
                    .font(BrandTypography.chip)
                    .foregroundStyle(BrandColor.textPrimary)
                    .lineLimit(1)
            }
            .actionChipBackground()
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: .light, pressedOpacity: 0.9))
        .hitArea()
        .accessibilityLabel("Open \(tool.name) details")
        .accessibilityIdentifier("ChatScreen.ToolCard.\(tool.id)")
    }
}
