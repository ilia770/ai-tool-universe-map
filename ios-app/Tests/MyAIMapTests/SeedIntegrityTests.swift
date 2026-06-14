import Testing
@testable import MyAIMap

/// Guards the bundled canonical seed (`ai-tool-universe.seed.json`) against
/// drift and corruption. `UniverseSeed` decodes lazily on first access, so any
/// decode failure surfaces here as a crash with a clear message.
struct SeedIntegrityTests {
    @Test func decodesExpectedCounts() {
        #expect(UniverseSeed.tools.count == 49)
        #expect(UniverseSeed.categories.count == 8)
    }

    @Test func founderOSIsTheCoreNode() {
        // Invariant 1: Founder OS stays the central core node (tools[0]).
        let first = UniverseSeed.tools[0]
        #expect(first.id == "founder-os")
        #expect(first.category == .core)
        #expect(first.orbit == .core)
    }

    @Test func everyOrbitIsWithinRange() {
        for tool in UniverseSeed.tools {
            #expect((0...3).contains(tool.orbit.rawValue), "tool \(tool.id) orbit out of range")
        }
    }

    @Test func everyRelationResolvesToAKnownTool() {
        let ids = Set(UniverseSeed.tools.map(\.id))
        var dangling: [String] = []
        for tool in UniverseSeed.tools {
            for relation in tool.relationIds where !ids.contains(relation) {
                dangling.append("\(tool.id) -> \(relation)")
            }
        }
        // The canonical web seed has no dangling relations; assert zero.
        #expect(dangling.isEmpty, "dangling relationIds: \(dangling)")
    }

    @Test func everyToolCategoryIsKnown() {
        let categoryIds = Set(UniverseSeed.categories.map(\.id))
        for tool in UniverseSeed.tools {
            #expect(categoryIds.contains(tool.category), "tool \(tool.id) has unknown category \(tool.category)")
        }
    }

    @Test func workflowLinkEndpointsResolve() {
        let ids = Set(UniverseSeed.tools.map(\.id))
        for link in UniverseSeed.workflowLinks {
            #expect(ids.contains(link.source), "link source \(link.source) missing")
            #expect(ids.contains(link.target), "link target \(link.target) missing")
        }
    }

    @Test func parityToolsArePresent() {
        let byID = Dictionary(uniqueKeysWithValues: UniverseSeed.tools.map { ($0.id, $0) })
        for id in ["figma", "cursor", "claude-code"] {
            let tool = byID[id]
            #expect(tool != nil, "expected tool \(id) to exist")
            #expect(!(tool?.summary.isEmpty ?? true), "tool \(id) has empty summary")
        }
    }
}
