import SwiftUI

/// Named text styles. SF Pro Display via the system, Dynamic Type
/// honored. No custom font shipped in Phase 0–3.
enum BrandTypography {
    /// 28 pt semibold — sheet titles.
    static let display: Font = .system(size: 28, weight: .semibold, design: .default)

    /// `.title3` semibold — section headers.
    static let title: Font = .system(.title3, design: .default, weight: .semibold)

    /// `.body` — descriptions, paragraph copy.
    static let body: Font = .system(.body, design: .default)

    /// `.footnote` semibold — category chips.
    static let chip: Font = .system(.footnote, design: .default, weight: .semibold)

    /// 10 pt semibold uppercase — eyebrow kicker over a section.
    /// Pair with `.kerning(1.8)` and `.textCase(.uppercase)`.
    static let eyebrow: Font = .system(size: 10, weight: .semibold, design: .default)

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
