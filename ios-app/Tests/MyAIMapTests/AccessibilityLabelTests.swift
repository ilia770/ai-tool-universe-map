import Testing
@testable import MyAIMap

/// Covers the pure VoiceOver copy builders (backlog 30/31). The strings are
/// what assistive tech reads for each tappable 3D entity, so they are pinned
/// here; applying them onto RealityKit entities is not headless-testable.
@Suite("AccessibilityCopy — VoiceOver strings for tappable entities")
struct AccessibilityLabelTests {
    private var figma: Tool {
        UniverseSeed.tools.first { $0.id == "figma" }!
    }

    private var design: ToolCategory {
        UniverseSeed.category(.design)
    }

    @Test func toolLabelIsTheToolName() {
        #expect(AccessibilityCopy.toolLabel(figma) == figma.name)
    }

    @Test func toolValueIsTheToolSummary() {
        #expect(AccessibilityCopy.toolValue(figma) == figma.summary)
        #expect(!AccessibilityCopy.toolValue(figma).isEmpty)
    }

    @Test func toolHintNamesTheSelectAction() {
        #expect(AccessibilityCopy.toolHint(figma) == "Selects \(figma.name)")
    }

    @Test func categoryLabelIsTheCategoryName() {
        #expect(AccessibilityCopy.categoryLabel(design) == design.name)
    }

    @Test func categoryHintNamesThePocketOpenAction() {
        #expect(AccessibilityCopy.categoryHint(design) == "Opens the \(design.shortName) pocket")
    }
}
