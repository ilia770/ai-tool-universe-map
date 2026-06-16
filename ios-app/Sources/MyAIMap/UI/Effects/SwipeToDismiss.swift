import SwiftUI

/// Pure, testable swipe math — mirrors the web drag-dismiss contract.
enum SwipeDismissModel {
    static func offset(for translation: CGFloat) -> CGFloat {
        InteractionTokens.rubberBand(translation)
    }
    static func commits(translation: CGFloat, velocity: CGFloat) -> Bool {
        InteractionTokens.shouldDismiss(translation: translation, velocity: velocity)
    }
}

/// Downward swipe-to-dismiss for a presented card/sheet. Follows the finger
/// 1:1 down, rubber-bands an upward over-drag, and commits `onDismiss` past
/// the shared distance OR on a downward flick. Fires `.light` on commit.
/// Under reduce motion the spring-back is instantaneous.
///
/// Usage:
///
/// ```swift
/// ChatCard()
///   .swipeToDismiss { store.closeChat() }
/// ```
extension View {
    func swipeToDismiss(onDismiss: @escaping () -> Void) -> some View {
        modifier(SwipeToDismissModifier(onDismiss: onDismiss))
    }
}

private struct SwipeToDismissModifier: ViewModifier {
    let onDismiss: () -> Void
    @State private var translation: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: SwipeDismissModel.offset(for: translation))
            .gesture(
                DragGesture()
                    .onChanged { translation = $0.translation.height }
                    .onEnded { value in
                        // velocity arrives as pt/s from SwiftUI; convert to pt/ms.
                        let vPerMs = value.predictedEndTranslation.height / 1000
                        if SwipeDismissModel.commits(translation: value.translation.height, velocity: vPerMs) {
                            BrandHaptics.fire(.light)
                            onDismiss()
                        }
                        withAnimation(BrandMotion.resolved(BrandMotion.nudge, reduceMotion: reduceMotion)) {
                            translation = 0
                        }
                    }
            )
    }
}
