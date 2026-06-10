import SwiftUI

/// Liquid Glass container — Apple's iOS 26+ glass material when
/// available, with a tasteful `.ultraThinMaterial` + tinted stroke
/// fallback for older OS versions (or earlier Xcode runtimes during
/// dev). All call sites should reach for this view modifier instead
/// of calling `.glassEffect(...)` directly so the fallback stays
/// centralised.
///
/// Usage:
///
/// ```swift
/// VStack { ... }
///   .liquidGlass(in: RoundedRectangle(cornerRadius: BrandRadius.card.value))
/// ```
extension View {
    @ViewBuilder
    func liquidGlass<S: InsettableShape>(
        in shape: S,
        tint: Color? = nil,
        strokeStrength: Double = 0.18
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.modifier(LiquidGlassNativeModifier(shape: shape, tint: tint, strokeStrength: strokeStrength))
        } else {
            self.modifier(LiquidGlassFallbackModifier(shape: shape, tint: tint, strokeStrength: strokeStrength))
        }
    }

    /// Convenience for the most common case — a rounded rectangle.
    func liquidGlass(cornerRadius: CGFloat, tint: Color? = nil) -> some View {
        liquidGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint)
    }
}

@available(iOS 26.0, *)
private struct LiquidGlassNativeModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let strokeStrength: Double

    func body(content: Content) -> some View {
        content
            .background {
                shape.fill(.regularMaterial)
            }
            .background {
                if let tint {
                    shape.fill(tint.opacity(0.10))
                }
            }
            .overlay {
                shape.stroke(BrandColor.strokeStrong.opacity(strokeStrength * 5.55), lineWidth: 1)
            }
            .clipShape(shape)
    }
}

private struct LiquidGlassFallbackModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let strokeStrength: Double

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(BrandColor.glass)
                    if let tint {
                        shape.fill(tint.opacity(0.10))
                    }
                }
            }
            .overlay {
                shape.stroke(BrandColor.strokeStrong.opacity(strokeStrength * 5.55), lineWidth: 1)
            }
            .overlay {
                // Subtle inner highlight along the top edge — fakes the
                // "lit from above" quality real glass has on iOS 26.
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [BrandColor.white.opacity(0.16), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.overlay)
            }
            .clipShape(shape)
    }
}
