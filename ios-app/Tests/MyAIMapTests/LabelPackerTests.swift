import Testing
import CoreGraphics
@testable import MyAIMap

@Suite("LabelPacker — pure screen-space label de-overlap")
struct LabelPackerTests {

    private let bounds = CGRect(x: 0, y: 0, width: 390, height: 844)
    private let safe = LabelPacker.SafeInsets(top: 100, leading: 70, bottom: 240, trailing: 100)
    private let labelSize = CGSize(width: 120, height: 44)

    private func candidate(
        _ id: String,
        x: CGFloat,
        y: CGFloat,
        priority: Int = 5,
        pinned: Bool = false
    ) -> LabelPacker.Candidate {
        LabelPacker.Candidate(
            id: id,
            anchor: CGPoint(x: x, y: y),
            size: labelSize,
            priority: priority,
            pinned: pinned
        )
    }

    @Test func nonOverlappingCandidatesAreAllPlaced() {
        let candidates = [
            candidate("a", x: 120, y: 300),
            candidate("b", x: 120, y: 600),
        ]
        let placed = LabelPacker.pack(candidates, bounds: bounds, safe: safe, maxCount: 8)
        #expect(placed.count == 2)
        #expect(Set(placed.map(\.id)) == ["a", "b"])
    }

    @Test func collidingCandidatesAreOffsetOrCulledSoNoneOverlap() {
        // Five candidates stacked on the exact same anchor: they cannot all
        // fit without overlapping, so some must be offset and the rest culled.
        let candidates = (0..<5).map { candidate("c\($0)", x: 195, y: 422, priority: $0) }
        let placed = LabelPacker.pack(candidates, bounds: bounds, safe: safe, maxCount: 8, offsets: [])
        // With no offsets allowed, only one can occupy the slot.
        #expect(placed.count == 1)
        // No two placed rects overlap.
        assertNoOverlap(placed)
    }

    @Test func offsetsResolveModerateCollisions() {
        // Two labels near each other should both be placed via offset.
        let candidates = [
            candidate("a", x: 195, y: 400, priority: 0),
            candidate("b", x: 195, y: 430, priority: 1),
        ]
        let placed = LabelPacker.pack(candidates, bounds: bounds, safe: safe, maxCount: 8)
        #expect(placed.count == 2)
        assertNoOverlap(placed)
    }

    @Test func pinnedCandidateIsAlwaysPlacedEvenUnderCrowding() {
        // Many high-priority crowders on the same anchor plus one pinned item.
        var candidates = (0..<6).map { candidate("crowd\($0)", x: 195, y: 422, priority: 0) }
        candidates.append(candidate("selected", x: 195, y: 422, priority: 99, pinned: true))
        let placed = LabelPacker.pack(candidates, bounds: bounds, safe: safe, maxCount: 3, offsets: [])
        #expect(placed.contains { $0.id == "selected" })
    }

    @Test func placedPositionsStayWithinSafeBounds() {
        // Anchors pushed off every edge must be clamped back into safe area.
        let candidates = [
            candidate("topleft", x: -200, y: -200),
            candidate("botright", x: 5000, y: 5000),
        ]
        let placed = LabelPacker.pack(candidates, bounds: bounds, safe: safe, maxCount: 8)
        for placement in placed {
            let halfW = labelSize.width / 2
            let halfH = labelSize.height / 2
            #expect(placement.position.x - halfW >= safe.leading - 0.001)
            #expect(placement.position.x + halfW <= bounds.width - safe.trailing + 0.001)
            #expect(placement.position.y - halfH >= safe.top - 0.001)
            #expect(placement.position.y + halfH <= bounds.height - safe.bottom + 0.001)
        }
    }

    @Test func maxCountLimitsNonPinnedLabels() {
        // Spread candidates far apart so collisions don't cull them; maxCount must.
        let candidates = (0..<8).map { candidate("d\($0)", x: 195, y: 110 + CGFloat($0) * 60, priority: $0) }
        let placed = LabelPacker.pack(candidates, bounds: bounds, safe: safe, maxCount: 3)
        #expect(placed.count <= 3)
    }

    @Test func packingIsDeterministic() {
        let candidates = [
            candidate("a", x: 120, y: 300, priority: 2),
            candidate("b", x: 200, y: 420, priority: 1),
            candidate("c", x: 120, y: 305, priority: 0),
        ]
        let first = LabelPacker.pack(candidates, bounds: bounds, safe: safe, maxCount: 8)
        let second = LabelPacker.pack(candidates, bounds: bounds, safe: safe, maxCount: 8)
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.map(\.position) == second.map(\.position))
    }

    @Test func higherPriorityWinsTheContestedSlot() {
        // Lower `priority` value == more important. The important one keeps the
        // anchor; the other is offset or culled.
        let candidates = [
            candidate("low", x: 195, y: 422, priority: 9),
            candidate("high", x: 195, y: 422, priority: 0),
        ]
        let placed = LabelPacker.pack(candidates, bounds: bounds, safe: safe, maxCount: 8, offsets: [])
        #expect(placed.count == 1)
        #expect(placed.first?.id == "high")
    }

    // Reserved rect = a label from another layer (e.g. focused planet label)
    // that this layer's tool labels must not overlap (cross-layer de-overlap).
    private let reservedRect = CGRect(x: 135, y: 400, width: 120, height: 44) // center (195,422)

    @Test func reservedRectCullsBlockedLabel() {
        // A label landing on the reserved rect with no room to dodge is culled,
        // never placed overlapping the other layer.
        let placed = LabelPacker.pack(
            [candidate("tool", x: 195, y: 422)],
            bounds: bounds, safe: safe, maxCount: 8, offsets: [], reserved: [reservedRect]
        )
        #expect(placed.isEmpty)
    }

    @Test func reservedRectIsDodgedByOffset() {
        // A label near the reserved rect offsets clear of it and is placed
        // without overlapping it.
        let placed = LabelPacker.pack(
            [candidate("tool", x: 195, y: 452)],
            bounds: bounds, safe: safe, maxCount: 8, reserved: [reservedRect]
        )
        #expect(placed.count == 1)
        let rect = CGRect(
            x: placed[0].position.x - labelSize.width / 2,
            y: placed[0].position.y - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height
        )
        #expect(!rect.intersects(reservedRect))
    }

    @Test func pinnedLabelOverridesReservedRect() {
        // The selected label is pinned and must show even if it lands on a
        // reserved cross-layer rect.
        let placed = LabelPacker.pack(
            [candidate("selected", x: 195, y: 422, pinned: true)],
            bounds: bounds, safe: safe, maxCount: 8, offsets: [], reserved: [reservedRect]
        )
        #expect(placed.contains { $0.id == "selected" })
    }

    private func assertNoOverlap(_ placed: [LabelPacker.Placement]) {
        for i in 0..<placed.count {
            for j in (i + 1)..<placed.count {
                let r1 = CGRect(
                    x: placed[i].position.x - labelSize.width / 2,
                    y: placed[i].position.y - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height
                )
                let r2 = CGRect(
                    x: placed[j].position.x - labelSize.width / 2,
                    y: placed[j].position.y - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height
                )
                #expect(!r1.intersects(r2), "\(placed[i].id) overlaps \(placed[j].id)")
            }
        }
    }
}
