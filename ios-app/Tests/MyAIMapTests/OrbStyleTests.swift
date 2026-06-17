import Testing
import CoreGraphics
@testable import MyAIMap

// MARK: - OrbStyleTests

@Suite("OrbStyle — radius ladder, emissive ramp, halo scale")
struct OrbStyleTests {

    // MARK: Size ladder

    @Test("core > category > tool at equal depth")
    func sizeLadder() {
        let depth: CGFloat = 1.0
        let orbit = 1  // mid orbit — representative
        let core     = OrbStyle.screenRadius(role: .core,     orbit: orbit, depthScale: depth)
        let category = OrbStyle.screenRadius(role: .category, orbit: orbit, depthScale: depth)
        let tool     = OrbStyle.screenRadius(role: .tool,     orbit: orbit, depthScale: depth)

        #expect(core > category, "core must be larger than category")
        #expect(category > tool, "category must be larger than tool")
        #expect(tool > 0,        "tool radius must be positive")
    }

    @Test("radius scales proportionally with depthScale")
    func depthScaleProportionality() {
        let depthA: CGFloat = 0.8
        let depthB: CGFloat = 1.2

        for role in [OrbRole.core, .category, .tool] {
            let rA = OrbStyle.screenRadius(role: role, orbit: 1, depthScale: depthA)
            let rB = OrbStyle.screenRadius(role: role, orbit: 1, depthScale: depthB)
            // rB / rA should equal depthB / depthA within floating-point rounding.
            let ratio = rB / rA
            #expect(abs(ratio - depthB / depthA) < 1e-6,
                    "screenRadius must scale linearly with depthScale for role \(role)")
        }
    }

    @Test("tool radius at orbit 1 derives from PocketTransition.baseToolRadius(orbit:1)")
    func toolRadiusTracesToPocketTransition() {
        // Derivation: screenRadius = worldRadius × ptPerWorldUnit × depthScale
        // worldRadius for .tool comes from PocketTransition.baseToolRadius(orbit:1)
        let expected = CGFloat(PocketTransition.baseToolRadius(orbit: 1))
            * OrbStyle.ptPerWorldUnit
            * 1.0   // depthScale == 1
        let actual = OrbStyle.screenRadius(role: .tool, orbit: 1, depthScale: 1.0)
        #expect(abs(actual - expected) < 1e-4,
                "tool radius must derive from PocketTransition.baseToolRadius, got \(actual) expected \(expected)")
    }

    @Test("category radius traces to PocketTransition.baseAnchorRadius")
    func categoryRadiusTracesToPocketTransition() {
        let expected = CGFloat(PocketTransition.baseAnchorRadius)
            * OrbStyle.ptPerWorldUnit
            * 1.0
        let actual = OrbStyle.screenRadius(role: .category, orbit: 1, depthScale: 1.0)
        #expect(abs(actual - expected) < 1e-4,
                "category radius must derive from PocketTransition.baseAnchorRadius")
    }

    @Test("core radius traces to PocketTransition.selectedAnchorRadius")
    func coreRadiusTracesToPocketTransition() {
        let expected = CGFloat(PocketTransition.selectedAnchorRadius)
            * OrbStyle.ptPerWorldUnit
            * 1.0
        let actual = OrbStyle.screenRadius(role: .core, orbit: 0, depthScale: 1.0)
        #expect(abs(actual - expected) < 1e-4,
                "core radius must derive from PocketTransition.selectedAnchorRadius")
    }

    // MARK: Emissive ramp

    @Test("emissive ordering: selected > pocket > overview > dimmed, all ≥ 0")
    func emissiveOrdering() {
        let sel  = OrbStyle.emissive(.selected)
        let pkt  = OrbStyle.emissive(.pocket)
        let ov   = OrbStyle.emissive(.overview)
        let dim  = OrbStyle.emissive(.dimmed)

        #expect(sel  > pkt,  "selected emissive must exceed pocket")
        #expect(pkt  > ov,   "pocket emissive must exceed overview")
        #expect(ov   > dim,  "overview emissive must exceed dimmed")
        #expect(dim  >= 0,   "dimmed emissive must be non-negative")
        #expect(sel  <= 1.0, "emissive must not exceed 1.0")
    }

    // MARK: Halo scale

    @Test("haloScale ≥ 1 for all states")
    func haloScaleAtLeastOne() {
        for state in [OrbState.selected, .pocket, .overview, .dimmed] {
            #expect(OrbStyle.haloScale(state) >= 1.0,
                    "haloScale must be ≥ 1 for state \(state)")
        }
    }

    @Test("haloScale: selected is larger than overview")
    func haloScaleSelectedExceedsOverview() {
        #expect(OrbStyle.haloScale(.selected) > OrbStyle.haloScale(.overview),
                "selected halo must be larger than overview halo")
    }
}
