/// Pure logic behind `GlassMorphCluster`: which `glassEffectID` each option
/// carries, and a clamp that defends a stored selection against a shrunken
/// option set. Kept free of SwiftUI so it is unit-testable.
enum GlassMorphSelection {
    /// The selected option shares the single travelling "active" id so exactly
    /// one glass shape morphs between slots; others get a stable per-slot id.
    static func glassID(optionIndex: Int, selectedIndex: Int, base: String) -> String {
        optionIndex == selectedIndex ? "\(base).active" : "\(base).option\(optionIndex)"
    }

    static func clamped(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Swift.min(Swift.max(index, 0), count - 1)
    }
}
