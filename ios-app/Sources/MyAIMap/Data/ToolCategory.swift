import Foundation
import SwiftUI
import UIKit

/// Swift mirror of the web app's `ToolCategoryId` discriminated union.
///
/// Originally a fixed `enum`, this is now an extensible string-backed struct so
/// the user (or the AI/Auto path) can create NEW branches at runtime (blueprint
/// §8). The eight seed branches plus `.core` remain available as static
/// constants, so every existing `.coding` / `.design` / … literal keeps
/// compiling. Encodes as a BARE STRING to preserve seed-JSON and persistence
/// parity with the old `RawValue == String` enum.
struct ToolCategoryId: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }

    var id: String { rawValue }

    static let coding = ToolCategoryId(rawValue: "coding")
    static let design = ToolCategoryId(rawValue: "design")
    static let research = ToolCategoryId(rawValue: "research")
    static let analytics = ToolCategoryId(rawValue: "analytics")
    static let media = ToolCategoryId(rawValue: "media")
    static let distribution = ToolCategoryId(rawValue: "distribution")
    static let infrastructure = ToolCategoryId(rawValue: "infrastructure")
    static let knowledge = ToolCategoryId(rawValue: "knowledge")
    static let core = ToolCategoryId(rawValue: "core")

    /// The eight selectable branches (excludes `.core`, the centre). Replaces
    /// the old `allCases` for any caller that iterates the built-in branches.
    static let builtins: [ToolCategoryId] = [
        .coding, .design, .research, .analytics,
        .media, .distribution, .infrastructure, .knowledge,
    ]

    /// True for the eight seed branches plus `.core`; false for user/AI-created
    /// custom branches.
    var isBuiltin: Bool { Self.builtins.contains(self) || self == .core }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// One category orbit in the universe. `angle` is degrees, matching the
/// web app so we can drop in the same `categoryPosition(angle)` math
/// without converting units.
struct ToolCategory: Identifiable, Codable, Equatable, Sendable {
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
struct ColorHex: Codable, Equatable, Sendable, ExpressibleByStringLiteral {
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
        guard let c = Self.parse(rawValue) else { return .white }
        return Color(red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }

    var uiColor: UIColor {
        guard let c = Self.parse(rawValue) else { return .white }
        return UIColor(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }

    /// Parses the stored string into normalised RGBA components (each 0...1),
    /// or `nil` when the string is unrecognisable. Shared by `swiftUIColor`
    /// and `uiColor` so both stay in lockstep.
    ///
    /// Accepts:
    /// - CSS `rgb(r, g, b)` / `rgba(r, g, b, a)` — the form the seed uses for
    ///   every category `glow` (e.g. `"rgba(110, 231, 255, 0.34)"`); `r,g,b`
    ///   are 0...255, `a` is 0...1. Case-insensitive and space-tolerant.
    /// - Hex `#RGB`, `#RRGGBB`, and `#RRGGBBAA` (leading `#` optional).
    static func parse(_ raw: String) -> (r: Double, g: Double, b: Double, a: Double)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.lowercased().hasPrefix("rgb") {
            guard let open = trimmed.firstIndex(of: "("),
                  let close = trimmed.firstIndex(of: ")") else { return nil }
            let parts = trimmed[trimmed.index(after: open)..<close]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 3 || parts.count == 4,
                  let r = Double(parts[0]),
                  let g = Double(parts[1]),
                  let b = Double(parts[2]) else { return nil }
            let a = parts.count == 4 ? (Double(parts[3]) ?? 1) : 1
            return (r / 255, g / 255, b / 255, a)
        }

        let hex = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let value = UInt32(hex, radix: 16) else { return nil }
        switch hex.count {
        case 3:
            let r = Double((value >> 8) & 0xf) / 15
            let g = Double((value >> 4) & 0xf) / 15
            let b = Double(value & 0xf) / 15
            return (r, g, b, 1)
        case 6:
            let r = Double((value >> 16) & 0xff) / 255
            let g = Double((value >> 8) & 0xff) / 255
            let b = Double(value & 0xff) / 255
            return (r, g, b, 1)
        case 8:
            let r = Double((value >> 24) & 0xff) / 255
            let g = Double((value >> 16) & 0xff) / 255
            let b = Double((value >> 8) & 0xff) / 255
            let a = Double(value & 0xff) / 255
            return (r, g, b, a)
        default:
            return nil
        }
    }
}
