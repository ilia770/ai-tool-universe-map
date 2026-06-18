import Foundation
import SwiftUI
import UIKit

/// Swift mirror of the web app's `ToolCategoryId` discriminated union.
/// Kept exhaustive so the compiler enforces parity with the data file
/// in `src/data/ai-tool-universe.ts`.
enum ToolCategoryId: String, CaseIterable, Codable, Sendable, Identifiable {
    case coding
    case design
    case research
    case analytics
    case media
    case distribution
    case infrastructure
    case knowledge
    case core

    var id: String { rawValue }
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
