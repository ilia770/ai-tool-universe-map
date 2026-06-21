import Testing
@testable import MyAIMap

@Suite("ToolPricingPresenter — structured pricing without hallucinated prices")
struct ToolPricingPresenterTests {
    @Test func unknownPricingShowsVerifyWebsiteRow() {
        let rows = ToolPricingPresenter.rows(for: "Unknown pricing model. Verify the live website before purchase.")

        #expect(rows.map(\.plan) == ["Unknown"])
        #expect(rows.first?.value == "Verify website")
    }

    @Test func freemiumPricingShowsFreeAndPaidRowsWithoutExactAmounts() {
        let rows = ToolPricingPresenter.rows(for: "Freemium/team subscription model. Enterprise features usually require paid tiers.")

        #expect(rows.contains { $0.plan == "Free" && $0.value.contains("$0") })
        #expect(rows.contains { $0.plan == "Pro" && $0.value == "Paid tier" })
        #expect(rows.contains { $0.plan == "Team" })
        #expect(rows.contains { $0.plan == "Enterprise" })
        #expect(!rows.contains { $0.value.contains("$19") || $0.value.contains("$29") })
    }

    @Test func openSourcePricingShowsFreeCoreAndVerifyExactHostedPricing() {
        let rows = ToolPricingPresenter.rows(for: "Open-source core with paid/cloud options depending on render workflow.")

        #expect(rows.contains { $0.plan == "Free" && $0.value == "$0 core" })
        #expect(rows.contains { $0.plan == "Pro" && $0.value == "Paid/cloud options" })
        #expect(rows.contains { $0.plan == "Unknown" && $0.value == "Verify website" })
    }
}
