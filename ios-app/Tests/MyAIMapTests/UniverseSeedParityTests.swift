import Testing
@testable import MyAIMap

/// Pins the *current* shape of the bundled iOS seed so that any future drift is
/// a deliberate, reviewed change rather than an accident.
///
/// The iOS seed is an intentional fork / superset of the documented web seed
/// (see `UniverseSeed.swift`): it currently carries 9 categories and 53 tools,
/// including an `analytics` category that the web seed does not have. These
/// tests lock those numbers plus the cross-port invariants that the rest of the
/// app relies on. If you intentionally change the seed, update the pinned
/// numbers here in the same change.
@Suite("UniverseSeed — pinned iOS fork shape + invariants")
struct UniverseSeedParityTests {

    @Test func categoryCountIsPinned() {
        #expect(UniverseSeed.categories.count == 9)
    }

    @Test func analyticsCategoryIsPresent() {
        // The `analytics` category is the headline difference from the web seed.
        #expect(UniverseSeed.categories.contains { $0.id == .analytics })
    }

    @Test func toolCountIsPinned() {
        #expect(UniverseSeed.tools.count == 53)
    }

    @Test func founderOSIsTheCentralCore() {
        // Invariant 1: Founder OS is `tools[0]` and the central core node.
        let first = UniverseSeed.tools.first
        #expect(first?.id == "founder-os")
        #expect(first?.orbit == .core)
        #expect(first?.category == .core)
    }

    @Test func everyOrbitIsWithinZeroToThree() {
        // Invariant 2: orbit ∈ {0, 1, 2, 3}.
        for tool in UniverseSeed.tools {
            #expect((0...3).contains(tool.orbit.rawValue), "\(tool.id) has out-of-range orbit \(tool.orbit.rawValue)")
        }
    }

    @Test func toolIdsAreUnique() {
        let ids = UniverseSeed.tools.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate tool ids in seed")
    }

    @Test func categoryIdsAreUnique() {
        let ids = UniverseSeed.categories.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate category ids in seed")
    }
}
