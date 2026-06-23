import SwiftUI

/// Canonical labeled glass button — a `Button` whose label rides on the glass
/// capsule surface with the shared `PressableButtonStyle` bounce. Composes the
/// existing `glassSurface` primitive (via `LiquidGlassPill`) and `BrandSpacing`
/// tokens; it adds no styling of its own. This is the role for a tappable
/// floating control with a text/icon label (e.g. the empty-state "Ask AI" CTA).
struct LiquidGlassButton<Label: View>: View {
    var tint: Color?
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    init(
        tint: Color? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.tint = tint
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .padding(.vertical, BrandSpacing.s.value + 1)
                .padding(.horizontal, BrandSpacing.l.value)
                .glassSurface(in: Capsule(), tint: tint, interactive: true)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.9))
    }
}
