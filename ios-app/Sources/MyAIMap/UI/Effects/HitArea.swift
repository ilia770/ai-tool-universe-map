import SwiftUI

/// HIG minimum tap target. `floored` is the pure size math (unit-tested);
/// `.hitArea()` applies it to a view plus a hit-testable content shape.
enum HitArea {
    static let minimum: CGFloat = 44

    static func floored(_ size: CGSize, min: CGFloat = minimum) -> CGSize {
        CGSize(width: Swift.max(size.width, min), height: Swift.max(size.height, min))
    }
}

extension View {
    /// Guarantees a >= `min` x `min` tappable region around a control,
    /// regardless of its visual size, and makes the whole region hit-testable.
    func hitArea(min: CGFloat = HitArea.minimum) -> some View {
        frame(minWidth: min, minHeight: min).contentShape(Rectangle())
    }
}
