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
        let hex = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return .white }
        let r = Double((value >> 16) & 0xff) / 255
        let g = Double((value >> 8) & 0xff) / 255
        let b = Double(value & 0xff) / 255
        return Color(red: r, green: g, blue: b)
    }

    var uiColor: UIColor {
        let hex = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return .white }
        let r = CGFloat((value >> 16) & 0xff) / 255
        let g = CGFloat((value >> 8) & 0xff) / 255
        let b = CGFloat(value & 0xff) / 255
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }
}
