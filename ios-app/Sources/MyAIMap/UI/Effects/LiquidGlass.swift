import SwiftUI

/// Liquid Glass — the single, centralised entry point for Apple's iOS 26 glass
/// material. Call `glassSurface(...)` instead of `.glassEffect(...)` directly so
/// the OS fallback and the accessibility path stay in one place.
///
/// HIG contract: glass belongs to the *floating navigation/control layer* —
/// composer, mode switch, toolbar buttons, HUD pills. NOT content: chat bubbles,
/// cards, sheet bodies, and backgrounds stay solid/material. Group neighbouring
/// controls in a `GlassEffectContainer` rather than nesting `glassSurface`.
///
/// Three-tier resolution (accessibility wins first):
/// 1. Reduce Transparency → opaque `glassSolid` surface (no blur/translucency).
/// 2. iOS 26+ → native `.glassEffect(_:in:)`, no manual stroke/clip (the system
///    owns its edge; decorating it fights the lensing).
/// 3. iOS 18–25 → `.ultraThinMaterial` + one hairline.
extension View {
    /// Capsule is the default control shape; pass `in:` for others.
    func glassSurface(tint: Color? = nil, interactive: Bool = false) -> some View {
        glassSurface(in: Capsule(), tint: tint, interactive: interactive)
    }

    func glassSurface<S: InsettableShape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassSurfaceModifier(shape: shape, tint: tint, interactive: interactive))
    }

    /// Rounded-rect convenience.
    func glassSurface(cornerRadius: CGFloat, tint: Color? = nil, interactive: Bool = false) -> some View {
        glassSurface(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            tint: tint,
            interactive: interactive
        )
    }

    /// Deprecated shim → `glassSurface`. Retained so existing call sites compile
    /// during the Phase 0→1 migration; new code must call `glassSurface`.
    /// `strokeStrength` is intentionally ignored — system glass owns its edge.
    /// Defaults to non-interactive; controls opt back into `.interactive()`
    /// during the allowlist migration.
    func liquidGlass<S: InsettableShape>(
        in shape: S,
        tint: Color? = nil,
        strokeStrength: Double = 0.18
    ) -> some View {
        glassSurface(in: shape, tint: tint, interactive: false)
    }

    func liquidGlass(cornerRadius: CGFloat, tint: Color? = nil) -> some View {
        glassSurface(cornerRadius: cornerRadius, tint: tint, interactive: false)
    }

    /// Shared morph identity for floating navigation glass. Native Liquid Glass
    /// uses `glassEffectID`; older OS paths keep the same role moving with
    /// matched geometry instead of popping through opacity-only transitions.
    @ViewBuilder
    func navigationGlassMorphID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self.matchedGeometryEffect(id: id, in: namespace, properties: .frame, anchor: .center)
        }
    }
}

private struct GlassSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            // Opaque, legible — no blur, no translucency, on every OS version.
            content.background {
                ZStack {
                    shape.fill(BrandColor.glassSolid)
                    if let tint {
                        shape.fill(tint.opacity(0.22))
                    }
                }
            }
        } else if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay { shape.stroke(BrandColor.stroke, lineWidth: 0.5) }
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var g = Glass.regular
        if let tint {
            g = g.tint(tint)
        }
        if interactive {
            g = g.interactive()
        }
        return g
    }
}
