import Foundation

/// Pure builders for the VoiceOver strings attached to the tappable 3D
/// entities (backlog 30/31). RealityKit entities are invisible to VoiceOver
/// unless they carry accessibility metadata, so each tool node and category
/// anchor gets a label / value / hint sourced from the seed.
///
/// Factored out as plain static functions so the copy is unit-testable
/// without standing up a RealityKit scene — the `UniverseView` factory
/// methods read these and push them onto the entities.
enum AccessibilityCopy {
    // MARK: Tool nodes

    /// Spoken name of a tool node — the tool's display name.
    static func toolLabel(_ tool: Tool) -> String {
        tool.name
    }

    /// Spoken value of a tool node — the tool's one-line summary, so a
    /// VoiceOver user hears what the tool is without opening it.
    static func toolValue(_ tool: Tool) -> String {
        tool.summary
    }

    /// Spoken hint of a tool node — what activating it does (selects the tool).
    static func toolHint(_ tool: Tool) -> String {
        "Selects \(tool.name)"
    }

    // MARK: Category anchors

    /// Spoken name of a category anchor — the category's full name.
    static func categoryLabel(_ category: ToolCategory) -> String {
        category.name
    }

    /// Spoken hint of a category anchor — activating it opens that pocket.
    static func categoryHint(_ category: ToolCategory) -> String {
        "Opens the \(category.shortName) pocket"
    }
}
