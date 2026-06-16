import Testing
@testable import MyAIMap

@Suite("ToolDetail — section gating")
struct ToolDetailKnowledgeGatingTests {

    private func k(
        killer: [String] = [], adv: [String] = [],
        weak: [String] = [], who: String = "", model: PricingModel = .unknown
    ) -> Knowledge {
        Knowledge(
            killerFeatures: killer, whatFor: "x", advantages: adv, weaknesses: weak,
            whoUses: who, pricing: .init(model: model, summary: "s")
        )
    }

    @Test func nilKnowledgeHidesEveryEnrichedSection() {
        let g = ToolDetailModel.gating(for: nil)
        #expect(g.showsKillerFeatures == false)
        #expect(g.showsStrengthsWatchouts == false)
        #expect(g.showsWhoUses == false)
        #expect(g.showsPricing == false)
    }

    @Test func enrichedShowsSectionsWithContent() {
        let g = ToolDetailModel.gating(for: k(
            killer: ["f"], adv: ["+"], who: "devs", model: .freemium
        ))
        #expect(g.showsKillerFeatures)
        #expect(g.showsStrengthsWatchouts)   // advantages non-empty
        #expect(g.showsWhoUses)
        #expect(g.showsPricing)              // model != .unknown
    }

    @Test func pricingHiddenWhenModelUnknown() {
        let g = ToolDetailModel.gating(for: k(killer: ["f"], model: .unknown))
        #expect(g.showsPricing == false)
    }

    @Test func emptyContentSectionsStayHidden() {
        let g = ToolDetailModel.gating(for: k(model: .freemium))
        #expect(g.showsKillerFeatures == false)
        #expect(g.showsStrengthsWatchouts == false)
        #expect(g.showsWhoUses == false)
        #expect(g.showsPricing)  // model present
    }
}
