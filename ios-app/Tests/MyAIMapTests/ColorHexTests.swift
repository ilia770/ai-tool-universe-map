import Testing
import UIKit
@testable import MyAIMap

/// Guards `ColorHex` parsing. The bundled seed stores every category `glow` as a
/// CSS `rgba(...)` string, so the rgba branch is the load-bearing path for planet
/// glows / accents (WS9.6). The 6-digit hex path and the `.white` fallback must
/// keep working unchanged.
@Suite("ColorHex parsing")
struct ColorHexTests {

    private let tol = 0.001

    /// Reads back a `UIColor`'s components in a compatible space.
    private func rgba(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    @Test func rgbaWithAlphaParsesToTintNotWhite() throws {
        // The exact string the seed ships for the `coding` category glow.
        let c = try #require(ColorHex.parse("rgba(110, 231, 255, 0.34)"))
        #expect(abs(c.r - 110.0 / 255.0) < tol)
        #expect(abs(c.g - 231.0 / 255.0) < tol)
        #expect(abs(c.b - 1.0) < tol)          // 255/255
        #expect(abs(c.a - 0.34) < tol)

        // And the built UIColor is the tint, not the old white fallback.
        let ui = rgba(ColorHex(stringLiteral: "rgba(110, 231, 255, 0.34)").uiColor)
        #expect(abs(ui.r - 110.0 / 255.0) < tol)
        #expect(abs(ui.g - 231.0 / 255.0) < tol)
        #expect(abs(ui.b - 1.0) < tol)
        #expect(abs(ui.a - 0.34) < tol)
        #expect(!(ui.r == 1 && ui.g == 1 && ui.b == 1), "glow rendered as white")
    }

    @Test func rgbWithoutAlphaDefaultsToOpaque() throws {
        let c = try #require(ColorHex.parse("rgb(255, 139, 210)"))
        #expect(abs(c.r - 1.0) < tol)
        #expect(abs(c.g - 139.0 / 255.0) < tol)
        #expect(abs(c.b - 210.0 / 255.0) < tol)
        #expect(c.a == 1)
    }

    @Test func sixDigitHexStillParses() throws {
        // Preserves the original hex path (the `analytics` glow is a hex string).
        let c = try #require(ColorHex.parse("#6ee7ff"))
        #expect(abs(c.r - Double(0x6e) / 255.0) < tol)
        #expect(abs(c.g - Double(0xe7) / 255.0) < tol)
        #expect(abs(c.b - Double(0xff) / 255.0) < tol)
        #expect(c.a == 1)
    }

    @Test func threeDigitHexExpands() throws {
        let c = try #require(ColorHex.parse("#0f0"))
        #expect(c.r == 0)
        #expect(c.g == 1)
        #expect(c.b == 0)
        #expect(c.a == 1)
    }

    @Test func eightDigitHexCarriesAlpha() throws {
        let c = try #require(ColorHex.parse("#6ee7ff56"))
        #expect(abs(c.r - Double(0x6e) / 255.0) < tol)
        #expect(abs(c.a - Double(0x56) / 255.0) < tol)
    }

    @Test func garbageFallsBackToWhite() {
        #expect(ColorHex.parse("not-a-color") == nil)
        #expect(ColorHex.parse("rgba(1, 2)") == nil)      // too few components
        let ui = rgba(ColorHex(stringLiteral: "not-a-color").uiColor)
        #expect(ui.r == 1 && ui.g == 1 && ui.b == 1 && ui.a == 1)
    }
}
