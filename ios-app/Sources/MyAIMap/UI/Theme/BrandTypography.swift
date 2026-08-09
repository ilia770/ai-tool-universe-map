import SwiftUI

/// Named text styles. SF Pro via the system, Dynamic Type honored.
/// Rounded type is reserved for the deliberately friendly empty state; product
/// chrome, reading text, and graph labels use the quieter default design.
enum BrandTypography {
    /// Large semibold — large modal/sheet titles.
    static let displayLarge: Font = .system(.largeTitle, design: .default, weight: .semibold)

    /// Title semibold — sheet titles.
    static let display: Font = .system(.title, design: .default, weight: .semibold)

    /// Friendly display role used only on onboarding/empty-state invitations.
    static let emptyStateDisplay: Font = .system(.title, design: .rounded, weight: .semibold)

    /// `.title3` semibold — section headers.
    static let title: Font = .system(.title3, design: .default, weight: .semibold)

    /// `.body` — descriptions, paragraph copy.
    static let body: Font = .system(.body, design: .default)

    /// `.callout` — secondary paragraph copy (tool summaries). Scales with
    /// Dynamic Type; do not replace with a fixed `.system(size:)`.
    static let bodySecondary: Font = .system(.callout, design: .default)

    /// `.footnote` semibold — category chips.
    static let chip: Font = .system(.footnote, design: .default, weight: .semibold)

    /// Primary control label — buttons, pills, tab/segment labels.
    static let controlLabel: Font = .system(.subheadline, design: .default, weight: .semibold)

    /// Compact labels anchored to 2D constellation nodes.
    static let graphLabel: Font = .system(.caption, design: .default, weight: .medium)
    static let graphLabelFocused: Font = .system(.footnote, design: .default, weight: .semibold)
    static let graphToolLabel: Font = .system(.caption2, design: .default, weight: .medium)
    static let graphMetadata: Font = .system(.caption2, design: .default, weight: .regular)
    static let graphCoreLabel: Font = .system(.subheadline, design: .default, weight: .semibold)

    /// Caption semibold uppercase — eyebrow kicker over a section.
    /// Pair with `.kerning(1.8)` and `.textCase(.uppercase)`.
    static let eyebrow: Font = .system(.caption2, design: .default, weight: .semibold)

    /// `.callout` monospaced — confidence percentages, counters.
    static let mono: Font = .system(.callout, design: .monospaced)
}

extension View {
    /// Shorthand for `.font(BrandTypography.eyebrow)` plus the kerning
    /// + uppercase that the eyebrow style always wants.
    func brandEyebrow() -> some View {
        self
            .font(BrandTypography.eyebrow)
            .kerning(1.8)
            .textCase(.uppercase)
    }
}
