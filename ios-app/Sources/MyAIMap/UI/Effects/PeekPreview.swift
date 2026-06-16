import SwiftUI

/// Long-press "quick peek" — the iOS twin of the web FindBar peek bubble.
/// Hold a chip past `InteractionTokens.longPressSeconds` to reveal a glass
/// preview card; release (or tap elsewhere) to dismiss. Fires `.medium`
/// on present. Honors reduce motion by skipping the scale/blur spring.
///
/// Usage:
///
/// ```swift
/// ChipView(tool)
///   .peekPreview { PeekCard(tool: tool) }
/// ```
extension View {
    func peekPreview<Peek: View>(@ViewBuilder _ content: @escaping () -> Peek) -> some View {
        modifier(PeekPreviewModifier(peek: content))
    }
}

private struct PeekPreviewModifier<Peek: View>: ViewModifier {
    @ViewBuilder let peek: () -> Peek
    @State private var showing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(
                minimumDuration: InteractionTokens.longPressSeconds,
                maximumDistance: 10
            ) {
                BrandHaptics.fire(.medium)
                showing = true
            }
            .overlay(alignment: .top) {
                if showing {
                    peek()
                        .padding(12)
                        .liquidGlass(in: RoundedRectangle(cornerRadius: BrandRadius.card.value))
                        .scaleEffect(reduceMotion ? 1 : 0.98)
                        .offset(y: -64)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
                        .onTapGesture { showing = false }
                        .accessibilityAddTraits(.isModal)
                }
            }
            .brandAnimation(BrandMotion.entry, value: showing)
    }
}
