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

    /// 20pt rounding shared by chat bubbles (inline transcript + full chat
    /// screen, was 19 vs 20) and floating glass notices/popovers (3D
    /// experimental banner, attach menu) so these never disagree.
    case bubble = 20

    /// Chat starter-prompt card.
    case promptCard = 14

    /// Spatial reveal card (the 3D tool-summary card).
    case revealCard = 26

    /// Large floating glass card (empty-state / onboarding card).
    case floatingCard = 28

    /// Graph node label pill (2D map node captions).
    case graphLabel = 9

    /// Bottom-sheet presentation corner radius (system sheet rounding).
    case sheetPresentation = 42

    var value: CGFloat { rawValue }
}
