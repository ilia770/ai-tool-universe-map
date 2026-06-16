import Testing
@testable import MyAIMap

@Suite("Visualization style")
struct VisualizationStyleTests {

    @Test func exactlyOneDefaultIsAvailable() {
        #expect(VisualizationStyle.galaxy.available)
        #expect(VisualizationStyle.allCases.contains(.galaxy))
    }

    @Test func everyStyleHasNonEmptyTitleInBothLanguages() {
        for style in VisualizationStyle.allCases {
            #expect(!style.title(.en).isEmpty)
            #expect(!style.title(.ru).isEmpty)
        }
    }

    @Test func rawValuesAreStableAndUnique() {
        let raws = VisualizationStyle.allCases.map(\.rawValue)
        #expect(Set(raws).count == raws.count)
    }
}
