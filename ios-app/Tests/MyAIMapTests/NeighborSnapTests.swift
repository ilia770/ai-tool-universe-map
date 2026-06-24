import Testing
import simd
@testable import MyAIMap

@Suite("NeighborSnap — drift toward neighbor sun")
struct NeighborSnapTests {
    private let suns: [NeighborSnap.Sun] = [
        .init(id: .coding, position: SIMD3<Float>(0, 0, 6)),     // bearing ~ atan2(0,6)+0.24
        .init(id: .design, position: SIMD3<Float>(6, 0, 0)),     // bearing ~ atan2(6,0)+0.24
    ]

    @Test func snapsWhenYawNearNeighborBearing() {
        let designBearing = atan2(Float(6), Float(0.001)) + 0.24
        let result = NeighborSnap.snapTarget(currentFocus: .coding, yaw: designBearing, suns: suns, thresholdRadians: 0.3)
        #expect(result == .design)
    }

    @Test func noSnapWhenFarFromAnyNeighbor() {
        let result = NeighborSnap.snapTarget(currentFocus: .coding, yaw: 3.14, suns: suns, thresholdRadians: 0.3)
        #expect(result == nil)
    }

    @Test func neverSnapsToCurrentFocus() {
        let codingBearing = atan2(Float(0), Float(6) + 0.001) + 0.24
        let result = NeighborSnap.snapTarget(currentFocus: .coding, yaw: codingBearing, suns: suns, thresholdRadians: 0.3)
        #expect(result == nil)
    }
}
