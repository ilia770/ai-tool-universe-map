import CoreGraphics
import Foundation
import simd

/// Pure screen-space label de-overlap ("bubble soup" fix).
///
/// Given projected label anchors with sizes and priorities, decide where each
/// label sits so that placed labels do not overlap, every position is clamped
/// inside a safe screen area, and any label that cannot find a free slot is
/// culled. Pinned labels (e.g. the current selection) are always placed.
///
/// This is intentionally free of SwiftUI so it can be unit-tested directly.
enum LabelPacker {
    struct SafeInsets: Equatable, Sendable {
        var top: CGFloat
        var leading: CGFloat
        var bottom: CGFloat
        var trailing: CGFloat
    }

    struct Candidate: Equatable, Sendable {
        let id: String
        /// Projected anchor (where the label *wants* to be before de-overlap).
        let anchor: CGPoint
        let size: CGSize
        /// Lower value == more important (placed first, wins contested slots).
        let priority: Int
        /// Pinned labels are always placed (selection must stay legible).
        var pinned: Bool = false
    }

    struct Placement: Equatable, Sendable {
        let id: String
        let position: CGPoint
    }

    /// Default candidate offsets tried, in order, to dodge a collision.
    static let defaultOffsets: [CGSize] = [
        .zero,
        CGSize(width: 0, height: -34),
        CGSize(width: 0, height: 34),
        CGSize(width: -36, height: 0),
        CGSize(width: 36, height: 0),
        CGSize(width: -36, height: -30),
        CGSize(width: 36, height: 30),
    ]

    /// Pack labels. Deterministic for a fixed input.
    /// - Parameter reserved: screen rects already occupied by labels from
    ///   another layer (e.g. the focused planet label when packing tool
    ///   labels). Non-pinned candidates dodge these too, so the two label
    ///   layers do not overlap each other ("cross-layer" de-overlap).
    /// - Returns: placements for the labels that survived de-overlap, in
    ///   placement order (pinned + highest priority first).
    static func pack(
        _ candidates: [Candidate],
        bounds: CGRect,
        safe: SafeInsets,
        maxCount: Int,
        offsets: [CGSize] = defaultOffsets,
        reserved: [CGRect] = []
    ) -> [Placement] {
        // Stable ordering: pinned first, then by ascending priority, then by id
        // so the result never depends on input order.
        let ordered = candidates.enumerated().sorted { lhs, rhs in
            if lhs.element.pinned != rhs.element.pinned { return lhs.element.pinned }
            if lhs.element.priority != rhs.element.priority {
                return lhs.element.priority < rhs.element.priority
            }
            return lhs.element.id < rhs.element.id
        }.map(\.element)

        var placed: [Placement] = []
        // Seed with cross-layer reserved rects so this layer's labels dodge
        // labels already placed by another layer.
        var occupied: [CGRect] = reserved
        // Always include the anchor itself as a fallback offset so a label that
        // dodges off every offset still lands at its clamped anchor.
        let tryOffsets = offsets.isEmpty ? [CGSize.zero] : offsets

        for candidate in ordered {
            let isPinned = candidate.pinned
            if !isPinned && placed.count >= maxCount { continue }

            var chosen: CGPoint?
            for offset in tryOffsets {
                let raw = CGPoint(
                    x: candidate.anchor.x + offset.width,
                    y: candidate.anchor.y + offset.height
                )
                let clamped = clamp(raw, size: candidate.size, bounds: bounds, safe: safe)
                let rect = rect(center: clamped, size: candidate.size)
                if !occupied.contains(where: { $0.intersects(rect) }) {
                    chosen = clamped
                    break
                }
            }

            if let chosen {
                placed.append(Placement(id: candidate.id, position: chosen))
                occupied.append(rect(center: chosen, size: candidate.size))
            } else if isPinned {
                // Pinned labels must remain visible even when every slot is
                // contested: place at the clamped anchor regardless of overlap.
                let clamped = clamp(candidate.anchor, size: candidate.size, bounds: bounds, safe: safe)
                placed.append(Placement(id: candidate.id, position: clamped))
                occupied.append(rect(center: clamped, size: candidate.size))
            }
            // Non-pinned with no free slot: culled (drop it).
        }

        return placed
    }

    static func clamp(_ point: CGPoint, size: CGSize, bounds: CGRect, safe: SafeInsets) -> CGPoint {
        let halfW = size.width / 2
        let halfH = size.height / 2
        let minX = safe.leading + halfW
        let maxX = bounds.width - safe.trailing - halfW
        let minY = safe.top + halfH
        let maxY = bounds.height - safe.bottom - halfH
        return CGPoint(
            x: minX <= maxX ? min(max(point.x, minX), maxX) : (minX + maxX) / 2,
            y: minY <= maxY ? min(max(point.y, minY), maxY) : (minY + maxY) / 2
        )
    }

    private static func rect(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

/// Shared spatial math for RealityKit entities and SwiftUI overlays.
///
/// Keeping satellite positions here lets labels, connector beams, and hit
/// targets line up with the actual 3D nodes. When generated spheres are
/// replaced with USDZ/Spline assets later, keep this contract stable.
enum UniverseSpatialLayout {
    static let categoryOrbitX: Float = 6.2
    static let categoryOrbitZ: Float = 4.75

    private static let categoryAngles: [ToolCategoryId: Float] = [
        .coding: -150,
        .design: -105,
        .research: -60,
        .analytics: -15,
        .media: 30,
        .distribution: 75,
        .infrastructure: 120,
        .knowledge: 165,
    ]

    static func categoryPosition(
        for category: ToolCategory,
        branchIndex: Int,
        branchCount: Int
    ) -> SIMD3<Float> {
        let fallbackStep = Float.pi * 2 / Float(max(branchCount, 1))
        let fallbackAngle = -Float.pi * 0.84 + Float(branchIndex) * fallbackStep
        let radians = (categoryAngles[category.id] ?? (fallbackAngle * 180 / .pi)) * .pi / 180
        return SIMD3<Float>(
            cos(radians) * categoryOrbitX,
            sin(radians * 1.36) * 0.84,
            sin(radians) * categoryOrbitZ
        )
    }

    static func satelliteOffset(index: Int, count: Int, orbit: OrbitRing) -> SIMD3<Float> {
        let safeCount = max(count, 1)
        let step = Float.pi * 2 / Float(safeCount)
        let angle = Float(index) * step + Float(orbit.rawValue) * 0.72 - .pi * 0.14
        let radius = 1.82 + Float(orbit.rawValue) * 0.62
        let vertical = sin(angle * 1.5) * 0.34
        return SIMD3<Float>(cos(angle) * radius, vertical, sin(angle) * radius * 0.82)
    }

    static func satelliteWorldPosition(
        for tool: Tool,
        in planet: PlanetData,
        index: Int,
        count: Int
    ) -> SIMD3<Float> {
        planet.position3D + satelliteOffset(index: index, count: count, orbit: tool.orbit)
    }
}
