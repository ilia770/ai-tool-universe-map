import SwiftUI

/// Canonical compact tool/source chip — favicon-sized logo + short name, sized
/// to content. Promoted verbatim from `ChatScreen`'s private `ChatToolChip`
/// (LIQUID_GLASS_VISUAL_SPEC §3): neutral fill (`ChatTheme.surfaceRaised`) +
/// neutral hairline; accent lives only on the tool logo glyph. Adds no styling
/// of its own beyond that shared chip chrome.
struct ToolChip: View {
    let tool: Tool
    let onOpen: () -> Void

    private var category: ToolCategory {
        UniverseSeed.category(tool.category)
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 6) {
                ToolLogoView(tool: tool, accent: category.color.swiftUIColor, size: 16)
                Text(tool.name)
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(ChatTheme.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, BrandSpacing.sm.value)
            .padding(.vertical, 6)
            .background(ChatTheme.surfaceRaised, in: Capsule())
            .overlay {
                Capsule().stroke(BrandColor.stroke, lineWidth: 0.8)
            }
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: .light))
        .accessibilityLabel("Open \(tool.name) details")
        .accessibilityIdentifier("ChatScreen.ToolCard.\(tool.id)")
    }
}
