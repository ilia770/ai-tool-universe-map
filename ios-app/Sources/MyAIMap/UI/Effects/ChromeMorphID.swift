import Foundation

/// Stable identifiers for §2 zoom-transition morphs that pair a trigger control
/// (`matchedTransitionSource(id:in:)`) with the sheet it presents
/// (`navigationTransition(.zoom(sourceID:in:))`). Both sides must reference the
/// same id within the same `Namespace`, so the button appears to expand into the
/// surface instead of the sheet sliding up from nowhere.
enum ChromeMorphID {
    static let account = "chromeMorph.account"
    static let addTool = "chromeMorph.addTool"
}
