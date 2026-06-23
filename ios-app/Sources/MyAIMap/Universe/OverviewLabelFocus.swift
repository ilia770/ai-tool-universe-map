import CoreGraphics

/// In overview only one sun speaks: the one nearest the screen centre
/// (locked design default). Everything else stays silent (principle 6).
enum OverviewLabelFocus {
    static func centeredSunID(
        _ candidates: [(id: ToolCategoryId, point: CGPoint)],
        screenCenter: CGPoint
    ) -> ToolCategoryId? {
        candidates.min(by: {
            hypot($0.point.x - screenCenter.x, $0.point.y - screenCenter.y)
                < hypot($1.point.x - screenCenter.x, $1.point.y - screenCenter.y)
        })?.id
    }
}
