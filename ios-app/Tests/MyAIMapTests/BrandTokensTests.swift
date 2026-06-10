import Testing
import SwiftUI
@testable import MyAIMap

@Suite("Brand tokens")
struct BrandTokensTests {

    @Test func radiiAreOrdered() {
        #expect(BrandRadius.tight.value < BrandRadius.node.value)
        #expect(BrandRadius.node.value < BrandRadius.nested.value)
        #expect(BrandRadius.nested.value < BrandRadius.card.value)
        #expect(BrandRadius.card.value < BrandRadius.pill.value)
    }

    @Test func spacingFollowsFourPointGrid() {
        let values: [CGFloat] = [
            BrandSpacing.hair.value,
            BrandSpacing.xs.value,
            BrandSpacing.s.value,
            BrandSpacing.m.value,
            BrandSpacing.l.value,
            BrandSpacing.xl.value,
            BrandSpacing.xxl.value,
            BrandSpacing.section.value,
        ]
        for v in values where v != BrandSpacing.hair.value {
            #expect(v.truncatingRemainder(dividingBy: 4) == 0, "spacing \(v) is off the 4 px grid")
        }
    }

    @Test func brandColoursAreDistinct() {
        let palette: [Color] = [
            BrandColor.violet, BrandColor.pink, BrandColor.teal,
            BrandColor.orange, BrandColor.cyan, BrandColor.lime,
            BrandColor.amber, BrandColor.core,
        ]
        let descriptions = palette.map { String(describing: $0) }
        #expect(Set(descriptions).count == palette.count, "two brand colours collide")
    }

    @Test func reducedMotionReplacesAnimation() {
        let resolved = BrandMotion.resolved(BrandMotion.entry, reduceMotion: true)
        #expect(String(describing: resolved).contains("linear"))
    }

    @Test @MainActor func hapticsDisabledIsNoOp() {
        BrandHaptics.isEnabled = false
        defer { BrandHaptics.isEnabled = true }
        // Just an API smoke — fire must not crash with disabled flag.
        BrandHaptics.fire(.medium)
        BrandHaptics.fire(.success)
    }
}
