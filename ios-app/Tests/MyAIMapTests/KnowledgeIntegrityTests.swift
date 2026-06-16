import Foundation
import Testing
@testable import MyAIMap

/// Guards the bundled `knowledge.json` against drift from the canonical web
/// emit. Like `UniverseSeed`, `KnowledgeStore` decodes lazily on first access,
/// so a decode failure surfaces here with a clear message.
struct KnowledgeIntegrityTests {
    @Test func decodesOneRecordPerSeedTool() {
        let knowledgeIDs = Set(KnowledgeStore.all.keys)
        let seedIDs = Set(UniverseSeed.tools.map(\.id))
        #expect(knowledgeIDs.count == 49)
        #expect(knowledgeIDs == seedIDs, "knowledge ids must match the 49 seed tool ids exactly")
    }

    @Test func everyRecordIsStructurallyComplete() {
        for (id, k) in KnowledgeStore.all {
            #expect(!k.whatFor.isEmpty, "\(id) has empty whatFor")
            #expect(!k.pricing.summary.isEmpty, "\(id) has empty pricing summary")
        }
    }

    @Test func knowledgeForResolvesAndMissesGracefully() {
        #expect(KnowledgeStore.knowledge(for: "founder-os") != nil)
        #expect(KnowledgeStore.knowledge(for: "does-not-exist") == nil)
    }

    @Test func pricingModelDecodesForEveryRecord() {
        // Decoding already happened in `all`; this asserts no record fell back
        // to an unknown raw value (the enum is non-optional, so a bad value
        // would have thrown during decode and crashed the lazy initializer).
        #expect(KnowledgeStore.all.values.allSatisfy { PricingModel.allCases.contains($0.pricing.model) })
    }
}
