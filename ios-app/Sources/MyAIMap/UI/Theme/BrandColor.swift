import SwiftUI

/// Canonical brand + surface palette. The web build accumulated inline
/// hex strings; we are not repeating that. Every visible colour goes
/// through this enum so a future re-skin is a single edit.
enum BrandColor {
    // MARK: - Brand

    /// Accent on selected nodes, founder OS core glow, the `AccentColor`
    /// in the asset catalog.
    static let core = Color(red: 155.0 / 255, green: 232.0 / 255, blue: 255.0 / 255)
    static let cyan = Color(red: 34.0 / 255, green: 211.0 / 255, blue: 238.0 / 255)
    static let violet = Color(red: 93.0 / 255, green: 89.0 / 255, blue: 255.0 / 255)
    static let pink = Color(red: 236.0 / 255, green: 72.0 / 255, blue: 153.0 / 255)
    static let teal = Color(red: 20.0 / 255, green: 184.0 / 255, blue: 166.0 / 255)
    static let orange = Color(red: 249.0 / 255, green: 115.0 / 255, blue: 22.0 / 255)
    static let lime = Color(red: 163.0 / 255, green: 230.0 / 255, blue: 53.0 / 255)
    static let amber = Color(red: 250.0 / 255, green: 204.0 / 255, blue: 21.0 / 255)
    static let white = Color.white

    // MARK: - Surface

    /// Behind the RealityKit canvas. Near-black, not pure black, so the
    /// procedural starfield retains contrast on OLED displays.
    static let void = Color(red: 3.0 / 255, green: 4.0 / 255, blue: 10.0 / 255)

    /// Glass background under the bottom sheet. Use with
    /// `.background(.thinMaterial)` underneath for the layered look.
    static let glass = Color(red: 5.0 / 255, green: 8.0 / 255, blue: 20.0 / 255, opacity: 0.76)

    /// Opaque surface for the Reduce Transparency fallback of `glassSurface`.
    /// Slightly above `void` so a glass control still reads as a distinct
    /// floating layer when translucency is disabled (no blur, no material).
    static let glassSolid = Color(red: 14.0 / 255, green: 17.0 / 255, blue: 28.0 / 255)

    /// Selected-tool card. Layered over the universe canvas.
    static let card = Color.white.opacity(0.06)

    /// Inactive chips, secondary controls.
    static let muted = Color.white.opacity(0.035)

    static let stroke = Color.white.opacity(0.10)
    static let strokeStrong = Color.white.opacity(0.18)

    // MARK: - Text

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.74)
    static let textMuted = Color.white.opacity(0.46)
}

