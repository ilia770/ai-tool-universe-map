/// Pure overview/pocket visibility rule for overlay badges. No SwiftUI / RealityKit.
enum DeclutterRule {
    enum BadgeKind: Sendable, Equatable {
        case category(ToolCategoryId)
        case tool(category: ToolCategoryId)
        case core
    }

    /// 0…1 opacity for a badge given current selection + depth.
    static func badgeVisibility(kind: BadgeKind, activeCategory: ToolCategoryId,
                                selectedToolID: String, thisID: String,
                                depthScale: Float) -> Double {
        let depthFade = depthFactor(depthScale)
        switch kind {
        case .core, .category:
            return depthFade                       // hubs/pills always shown
        case .tool(let category):
            if thisID == selectedToolID { return depthFade }
            let inOpenPocket = (activeCategory != .core && activeCategory == category)
            return inOpenPocket ? depthFade * 0.92 : 0
        }
    }

    /// Linear fade: full inside ref depth, gone when far (depthScale ≤ 0.35).
    static func depthFactor(_ depthScale: Float) -> Double {
        let lo: Float = 0.35, hi: Float = 0.9
        if depthScale >= hi { return 1 }
        if depthScale <= lo { return 0 }
        return Double((depthScale - lo) / (hi - lo))
    }
}
