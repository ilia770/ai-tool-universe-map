import CoreGraphics

/// 4 px spacing grid. The whole app pulls gaps from here. Inline
/// magic numbers in `Spacer().frame(width:)` or `.padding(20)` are
/// not allowed — add a token here first.
enum BrandSpacing: CGFloat {
    /// 2 — hairline gaps between dense rows.
    case hair = 2

    /// 4 — chip inner gap.
    case xs = 4

    /// 8 — between chips, between an icon and its label.
    case s = 8

    /// 10 — compact control vertical rhythm (composer/card/notice insets that
    /// sit between s and m).
    case sm = 10

    /// 12 — card inner padding.
    case m = 12

    /// 16 — bottom sheet inner padding, default safe-area-relative gap.
    case l = 16

    /// 20 — between detent stops.
    case xl = 20

    /// 24 — top-level sheet padding.
    case xxl = 24

    /// 32 — between major sheet sections.
    case section = 32

    var value: CGFloat { rawValue }
}
