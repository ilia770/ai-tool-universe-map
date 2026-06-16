import Foundation
import SwiftUI
import UIKit

/// Swift mirror of the web app's `ToolCategoryId` discriminated union.
/// Kept exhaustive so the compiler enforces parity with the data file
/// in `src/data/ai-tool-universe.ts`.
enum ToolCategoryId: String, CaseIterable, Codable, Sendable {
    case coding
    case design
    case research
    case media
    case distribution
    case infrastructure
    case knowledge
    case core
    case analytics
}

/// One category orbit in the universe. `angle` is degrees, matching the
/// web app so we can drop in the same `categoryPosition(angle)` math
/// without converting units.
struct ToolCategory: Identifiable, Codable, Sendable {
    let id: ToolCategoryId
    let name: String
    let shortName: String
    let description: String
    let color: ColorHex
    let glow: ColorHex
    let angle: Float
}

/// Hex-string color wrapper so JSON / Codable round-trips stay
/// human-readable. Use `swiftUIColor` when handing to a view.
struct ColorHex: Codable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init(stringLiteral value: String) {
        self.rawValue = value
    }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var swiftUIColor: Color {
        let c = Self.components(rawValue) ?? (1, 1, 1, 1)
        return Color(red: c.r, green: c.g, blue: c.b).opacity(c.a)
    }

    var uiColor: UIColor {
        let c = Self.components(rawValue) ?? (1, 1, 1, 1)
        return UIColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)
    }

    /// Parses both `#rrggbb` hex and CSS `rgba(r, g, b, a)` strings (the web
    /// seed uses hex for `color` and rgba for `glow`). Returns components in
    /// 0...1, or `nil` if the string isn't a recognised colour.
    private static func components(_ raw: String) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasPrefix("rgba(") || trimmed.lowercased().hasPrefix("rgb(") {
            let inner = trimmed.drop { $0 != "(" }.dropFirst().prefix { $0 != ")" }
            let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 3,
                  let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2]) else { return nil }
            let a = parts.count >= 4 ? (Double(parts[3]) ?? 1) : 1
            return (CGFloat(r / 255), CGFloat(g / 255), CGFloat(b / 255), CGFloat(a))
        }
        let hex = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        return (
            CGFloat((value >> 16) & 0xff) / 255,
            CGFloat((value >> 8) & 0xff) / 255,
            CGFloat(value & 0xff) / 255,
            1
        )
    }
}
