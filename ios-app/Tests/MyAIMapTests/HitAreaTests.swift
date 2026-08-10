import Testing
import CoreGraphics
@testable import MyAIMap

@Suite("HitArea floor")
struct HitAreaTests {
    @Test func minimumIsFortyFourPoints() {
        #expect(HitArea.minimum == 44)
    }

    @Test func expandsBothDimensionsToMinimum() {
        #expect(HitArea.floored(CGSize(width: 10, height: 10)) == CGSize(width: 44, height: 44))
    }

    @Test func keepsDimensionsAlreadyAboveMinimum() {
        #expect(HitArea.floored(CGSize(width: 60, height: 30)) == CGSize(width: 60, height: 44))
    }

    @Test func respectsCustomMinimum() {
        #expect(HitArea.floored(CGSize(width: 5, height: 5), min: 30) == CGSize(width: 30, height: 30))
    }
}
