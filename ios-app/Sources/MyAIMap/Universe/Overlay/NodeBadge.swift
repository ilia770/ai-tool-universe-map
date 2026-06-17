import SwiftUI

// MARK: - BadgeRole

/// Semantic role driving size, typography, and max-width of the badge.
enum BadgeRole {
    /// Category orbit label — largest pill.
    case category
    /// Individual tool node — medium pill.
    case tool
    /// Focused / selected tool — widest pill with prominent type.
    case focused
}

// MARK: - NodeBadgeMetrics

/// Pure, testable constants for badge geometry per role.
/// All values are in points (logical pixels). No SwiftUI View dependency (uses Font/CGFloat).
enum NodeBadgeMetrics {

    // MARK: Plate height

    /// Plate (capsule) height in points per role.
    static func height(for role: BadgeRole) -> CGFloat {
        switch role {
        case .tool:     return 22
        case .category: return 26
        case .focused:  return 30
        }
    }

    // MARK: Max label width

    /// Maximum label width in points per role (excludes horizontal padding).
    static func maxWidth(for role: BadgeRole) -> CGFloat {
        switch role {
        case .tool:     return 116
        case .category: return 160
        case .focused:  return 232
        }
    }

    // MARK: Font

    /// Base font (before Dynamic Type scaling) per role.
    static func font(for role: BadgeRole) -> Font {
        switch role {
        case .tool:     return .system(.caption2, design: .default, weight: .semibold)
        case .category: return .system(.caption,  design: .default, weight: .bold)
        case .focused:  return .system(.subheadline, design: .default, weight: .bold)
        }
    }

    // MARK: Horizontal padding

    static func horizontalPadding(for role: BadgeRole) -> CGFloat {
        switch role {
        case .tool:     return 8
        case .category: return 10
        case .focused:  return 12
        }
    }

    // MARK: Dot size (tool indicator)

    static let dotDiameter: CGFloat = 5
}

// MARK: - NodeBadge

/// Screen-space glass-pill label for universe nodes.
///
/// Place this view in a SwiftUI overlay at the screen-space position
/// returned by `UniverseProjection.project(...)` — positioning is the
/// caller's responsibility. The view itself is entirely fixed-size and
/// does **not** scale with camera distance.
///
/// Visual anatomy (back → front):
/// 1. Dark translucent vertical gradient plate (`#0E1726`@0.86 → `#040812`@0.76)
/// 2. 1px white@0.18 border, tinted to `categoryColor`@0.40 for `.category` role
/// 3. Inner-top sheen (liquid-glass highlight)
/// 4. Optional category-color dot (tool roles) or leading icon
/// 5. Dynamic Type label with dark shadow for legibility over starfield
struct NodeBadge: View {

    let title: String
    let role: BadgeRole
    let categoryColor: Color
    /// Optional leading icon. Pass `nil` to show the category dot instead
    /// (tool roles) or nothing (category roles).
    let icon: Image?
    /// Overall opacity; lets callers fade the badge with distance or depth.
    let opacity: CGFloat
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    // Scaled height so Dynamic Type stretches the capsule naturally.
    @ScaledMetric(relativeTo: .caption) private var scaledBase: CGFloat = 1

    var body: some View {
        Button(action: {
            onTap()
        }) {
            pillContent
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: .light, pressedOpacity: 0.88))
        .opacity(appeared ? Double(opacity) : 0)
        .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.85))
        .onAppear {
            withAnimation(UniverseMotion.transition(reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
    }

    // MARK: - Pill content

    private var pillContent: some View {
        HStack(spacing: 4) {
            leadingDecoration
            label
        }
        .padding(.horizontal, NodeBadgeMetrics.horizontalPadding(for: role))
        .frame(height: pillHeight)
        .frame(maxWidth: NodeBadgeMetrics.maxWidth(for: role))
        .background(plateBackground)
        .overlay(strokeOverlay)
        .overlay(sheenOverlay)
        .clipShape(Capsule())
    }

    // MARK: - Leading decoration

    @ViewBuilder
    private var leadingDecoration: some View {
        if let icon {
            icon
                .resizable()
                .scaledToFit()
                .frame(width: pillHeight * 0.55, height: pillHeight * 0.55)
                .foregroundStyle(categoryColor)
        } else if role == .tool {
            Circle()
                .fill(categoryColor)
                .frame(
                    width: NodeBadgeMetrics.dotDiameter,
                    height: NodeBadgeMetrics.dotDiameter
                )
        }
    }

    // MARK: - Label

    private var label: some View {
        Text(title)
            .font(NodeBadgeMetrics.font(for: role))
            .foregroundStyle(Color(red: 0.973, green: 0.988, blue: 1.0).opacity(0.96))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            // Dark outline via layered shadow for legibility on bright nebula.
            .shadow(color: .black.opacity(0.8), radius: 0, x: 1,  y: 1)
            .shadow(color: .black.opacity(0.6), radius: 2, x: 0,  y: 0)
    }

    // MARK: - Background

    private var plateBackground: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.055, green: 0.090, blue: 0.149).opacity(0.86),
                        Color(red: 0.016, green: 0.031, blue: 0.071).opacity(0.76)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: - Stroke

    private var strokeBorderColor: Color {
        switch role {
        case .category:
            // Tint the border toward the category color at 40%.
            return Color.white.opacity(0.18).mix(with: categoryColor, by: 0.40)
        case .tool, .focused:
            return Color.white.opacity(0.18)
        }
    }

    private var strokeOverlay: some View {
        Capsule()
            .strokeBorder(strokeBorderColor, lineWidth: 1)
    }

    // MARK: - Inner top sheen (liquid-glass highlight)

    private var sheenOverlay: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.22), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                ),
                lineWidth: 1
            )
            .blendMode(.overlay)
    }

    // MARK: - Computed height

    /// Height scaled proportionally with Dynamic Type.
    private var pillHeight: CGFloat {
        NodeBadgeMetrics.height(for: role) * scaledBase
    }
}

// MARK: - Preview

#Preview("NodeBadge roles") {
    ZStack {
        Color(red: 0.012, green: 0.016, blue: 0.039).ignoresSafeArea()
        VStack(spacing: 16) {
            NodeBadge(
                title: "Coding",
                role: .category,
                categoryColor: BrandColor.violet,
                icon: nil,
                opacity: 1,
                onTap: {}
            )
            NodeBadge(
                title: "Cursor",
                role: .tool,
                categoryColor: BrandColor.cyan,
                icon: nil,
                opacity: 1,
                onTap: {}
            )
            NodeBadge(
                title: "Cursor — AI Code Editor",
                role: .focused,
                categoryColor: BrandColor.cyan,
                icon: nil,
                opacity: 1,
                onTap: {}
            )
            NodeBadge(
                title: "With Icon",
                role: .tool,
                categoryColor: BrandColor.pink,
                icon: Image(systemName: "star.fill"),
                opacity: 1,
                onTap: {}
            )
        }
    }
    .preferredColorScheme(.dark)
}
