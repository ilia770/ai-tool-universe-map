import SwiftUI

/// Canonical glass pill for the capsule control role — wraps content in the
/// `glassSurface(in: Capsule(), interactive:)` pattern used by floating HUD
/// pills and the mode switch. Composes the existing `glassSurface` primitive;
/// it adds no styling of its own. Sites that drive a `glassEffectID` /
/// `navigationGlassMorphID` keep their own modifier and do not use this wrapper.
struct LiquidGlassPill<Content: View>: View {
    var tint: Color?
    var interactive: Bool
    @ViewBuilder var content: () -> Content

    init(
        tint: Color? = nil,
        interactive: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tint = tint
        self.interactive = interactive
        self.content = content
    }

    var body: some View {
        content()
            .glassSurface(in: Capsule(), tint: tint, interactive: interactive)
    }
}
