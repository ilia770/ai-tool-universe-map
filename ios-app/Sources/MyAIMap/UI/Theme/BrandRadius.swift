import CoreGraphics

/// Single source of truth for corner radii. Inline radii in views are
/// not allowed — add a token here first.
enum BrandRadius: CGFloat {
    /// Chips, the lens-bar drag handle.
    case pill = 999

    /// Tool detail card, top of the bottom sheet.
    case card = 18

    /// Inline tool-row buttons inside the lens panel.
    case node = 8

    /// Tight controls — segmented chips, picker dots.
    case tight = 6

    /// Containers above containers (e.g. nested glass surfaces).
    case nested = 12

    /// Floating glass control container (composer pill rounded form).
    case glassControl = 22

    /// Glass icon-button container.
    case glassButton = 16

    /// Chat message bubble — same shape in the inline transcript and the full
    /// chat screen, so both read from this and never disagree (was 19 vs 20).
    case bubble = 20

    var value: CGFloat { rawValue }
}
