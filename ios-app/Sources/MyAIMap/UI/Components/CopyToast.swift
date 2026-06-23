import SwiftUI

/// Lightweight, native-feel copy-confirmation toast (CHAT_AI_SPEC §"Copy-action
/// feedback"). A brief auto-dismissing glass banner shown *locally* above the
/// content where a copy happened — assistant answers (`ChatScreen`) and tool
/// info (`ToolDetailSection`). It is NOT a global host; each surface owns its
/// own toast state and applies `.copyToast(...)` to its root.
///
/// Accessibility: the banner is VoiceOver-announced as a live region and never
/// steals focus; reduce-motion swaps the rise/fade transition for a plain
/// opacity fade.

/// The two copy outcomes the app can confirm. Value-only so the message
/// selection is unit-testable without hosting a view.
enum CopyToastKind: Equatable {
    /// User copied an assistant chat reply.
    case answer
    /// User copied a tool's info card (name + summary + url).
    case toolInfo

    /// The banner label. Matches the spec acceptance strings exactly.
    var message: String {
        switch self {
        case .answer: return "Answer copied"
        case .toolInfo: return "Tool info copied"
        }
    }
}

/// Pure builder for the clipboard text of a tool's info card (name + summary +
/// optional url). Kept value-only so the formatting is unit-testable. The url
/// line is omitted when no website has been added.
enum ToolInfoClipboard {
    static func text(name: String, summary: String, url: String?) -> String {
        var lines = [name, summary]
        if let url, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(url)
        }
        return lines.joined(separator: "\n")
    }
}

/// The glass banner itself. Hosted by `CopyToastModifier`; not used directly.
/// Thin wrapper over the shared `LiquidGlassToast` so the copy confirmation and
/// any future toast share one canonical glass capsule.
private struct CopyToastBanner: View {
    let message: String

    var body: some View {
        LiquidGlassToast(message: message)
            .accessibilityIdentifier("CopyToast")
    }
}

private struct CopyToastModifier: ViewModifier {
    @Binding var kind: CopyToastKind?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Visible lifetime before auto-dismiss (spec: ≈1.5s).
    private static let lifetime: Duration = .milliseconds(1_600)
    /// Bumped on each copy so a second copy while one is showing restarts the
    /// timer instead of dismissing early on the first timer's expiry.
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let kind {
                    CopyToastBanner(message: kind.message)
                        .padding(.top, BrandSpacing.s.value)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .top).combined(with: .opacity)
                        )
                        // Live region: announced without grabbing focus.
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isStaticText)
                        .accessibilityLabel(kind.message)
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : BrandMotion.pillPop, value: kind)
            .onChange(of: kind) { _, newValue in
                guard newValue != nil else { return }
                let current = UUID()
                token = current
                Task {
                    try? await Task.sleep(for: Self.lifetime)
                    // Only the most recent copy clears the toast.
                    guard token == current else { return }
                    kind = nil
                }
            }
    }
}

extension View {
    /// Overlays an auto-dismissing copy-confirmation toast at the top of the
    /// view. Set `kind` to a non-nil value (e.g. on a Copy button tap) to show
    /// it; it clears itself after ≈1.6s. Apply to the root of the surface that
    /// owns the copy action.
    func copyToast(_ kind: Binding<CopyToastKind?>) -> some View {
        modifier(CopyToastModifier(kind: kind))
    }
}
