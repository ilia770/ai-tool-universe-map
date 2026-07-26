import SwiftUI

/// Named text styles. SF Pro Display via the system, Dynamic Type
/// honored. No custom font shipped in Phase 0–3.
enum BrandTypography {
    /// Large semibold — large modal/sheet titles.
    static let displayLarge: Font = .system(.largeTitle, design: .rounded, weight: .semibold)

    /// Title semibold — sheet titles.
    static let display: Font = .system(.title, design: .rounded, weight: .semibold)

    /// `.title3` semibold — section headers.
    static let title: Font = .system(.title3, design: .rounded, weight: .semibold)

    /// `.body` — descriptions, paragraph copy.
    static let body: Font = .system(.body, design: .rounded)

    /// `.callout` — secondary paragraph copy (tool summaries). Scales with
    /// Dynamic Type; do not replace with a fixed `.system(size:)`.
    static let bodySecondary: Font = .system(.callout, design: .rounded)

    /// `.footnote` semibold — category chips.
    static let chip: Font = .system(.footnote, design: .default, weight: .semibold)

    /// Primary control label — buttons, pills, tab/segment labels. Rounded so
    /// the interactive layer reads as one tactile family (secondary/metadata
    /// stay `.default`).
    static let controlLabel: Font = .system(.subheadline, design: .rounded, weight: .semibold)

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
