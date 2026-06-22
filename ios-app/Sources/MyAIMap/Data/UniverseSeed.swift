import Foundation

/// Decodable root mirroring the shape of `src/data/ai-tool-universe.seed.json`.
///
/// The iOS port decodes a bundled `ai-tool-universe.seed.json` from the app
/// target. NOTE: this iOS seed is an intentional fork / superset of the web
/// seed, not a verbatim copy. The iOS seed currently has 9 categories and 53
/// tools — including an extra `analytics` category and tools such as `posthog`
/// — whereas the documented web seed in `src/data/` has 8 categories and 49
/// tools and no `analytics` category. The two payloads share the same schema
/// but their contents have deliberately diverged. Any future change to the iOS
/// seed shape must be intentional: the parity/invariants test in
/// `Tests/MyAIMapTests/UniverseSeedParityTests.swift` pins the current shape
/// (category/tool counts, `analytics` presence, and core invariants) and will
/// fail if the seed drifts unexpectedly.
private struct SeedFile: Decodable {
    let version: Int
    let categories: [ToolCategory]
    let tools: [Tool]
    let workflowLinks: [UniverseLink]
    // `workflowStages` is an object keyed by stage id in the web JSON; nothing
    // on iOS consumes it yet, so it is intentionally not decoded.
}

/// Universe seed data, decoded once from the bundled canonical JSON.
///
/// Public API is unchanged from the old hand-written Phase-0 stub
/// (`categories`, `tools`, `category(_:)`, `tools(in:)`) so every existing
/// consumer keeps compiling untouched.
enum UniverseSeed {
    /// Resolves the bundle that contains the app's resources. For an XcodeGen
    /// app target (no SwiftPM `Bundle.module`), `Bundle(for:)` of a type
    /// defined in the target returns the app bundle. Unit tests run inside the
    /// host app (`TEST_HOST` / `BUNDLE_LOADER`), so the same bundle resolves
    /// there too.
    private final class BundleToken {}

    private static let seed: SeedFile = {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "ai-tool-universe.seed", withExtension: "json") else {
            fatalError("Missing bundled resource ai-tool-universe.seed.json — this is a build-time invariant (XcodeGen copies it from Sources/MyAIMap/Resources).")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SeedFile.self, from: data)
        } catch {
            fatalError("Failed to decode ai-tool-universe.seed.json: \(error)")
        }
    }()

    static var categories: [ToolCategory] { seed.categories }

    static var tools: [Tool] { seed.tools }

    static var workflowLinks: [UniverseLink] { seed.workflowLinks }

    /// User/AI-created branches, registered at runtime by `UniverseViewModel`
    /// after load and on every mutation. `category(_:)` consults this registry
    /// so custom branches resolve to a real `ToolCategory` everywhere the seed
    /// static is called (rail, labels, logos, assistant) without each call site
    /// having to thread the view model through.
    /// `nonisolated(unsafe)`: every write goes through the `@MainActor`
    /// `UniverseViewModel` (load + each mutation), and reads happen on the main
    /// actor from SwiftUI views, so access is effectively main-actor-confined.
    nonisolated(unsafe) static private(set) var customCategories: [ToolCategoryId: ToolCategory] = [:]

    /// Replaces the custom-category registry with `list`. Idempotent — safe to
    /// call on every load and mutation.
    static func registerCustomCategories(_ list: [ToolCategory]) {
        customCategories = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    /// Resolves a branch id to its category. Order: seed match → custom
    /// registry → a DETERMINISTIC generated fallback. The fallback never
    /// crashes (the old `categories[0]` default would mislabel custom ids as the
    /// first seed category) and is stable across launches because its color,
    /// glow, and angle derive from a hash of the raw id.
    static func category(_ id: ToolCategoryId) -> ToolCategory {
        if let seedMatch = categories.first(where: { $0.id == id }) { return seedMatch }
        if let custom = customCategories[id] { return custom }
        return generatedCategory(for: id)
    }

    /// Builds a stable placeholder category for an id that is neither in the
    /// seed nor the registry (e.g. a persisted custom branch read before the
    /// view model has registered it, or a stale id). Deterministic so the same
    /// id always renders the same color/angle.
    static func generatedCategory(for id: ToolCategoryId) -> ToolCategory {
        let raw = id.rawValue
        let hash = stableHash(raw)
        let hue = Double(hash % 360) / 360
        let color = ColorHex(stringLiteral: hexString(hue: hue, saturation: 0.62, brightness: 0.86))
        let glow = ColorHex(stringLiteral: hexString(hue: hue, saturation: 0.5, brightness: 0.98))
        let angle = Float(hash % 360)
        let name = raw
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
        let display = name.isEmpty ? "Branch" : name
        return ToolCategory(
            id: id,
            name: display,
            shortName: display,
            description: "Custom branch.",
            color: color,
            glow: glow,
            angle: angle
        )
    }

    /// FNV-1a over the id's UTF-8 bytes. A plain `String.hashValue` is salted
    /// per-process and would change between launches, breaking the "stable
    /// color" contract; this is deterministic.
    private static func stableHash(_ value: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return Int(hash % UInt64(Int.max))
    }

    private static func hexString(hue: Double, saturation: Double, brightness: Double) -> String {
        let (r, g, b) = hsbToRGB(hue: hue, saturation: saturation, brightness: brightness)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private static func hsbToRGB(hue: Double, saturation: Double, brightness: Double) -> (Double, Double, Double) {
        let h = (hue.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let c = brightness * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        let (r1, g1, b1): (Double, Double, Double)
        switch Int(h) {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        return (r1 + m, g1 + m, b1 + m)
    }

    static func tools(in category: ToolCategoryId) -> [Tool] {
        tools.filter { $0.category == category }
    }
}
