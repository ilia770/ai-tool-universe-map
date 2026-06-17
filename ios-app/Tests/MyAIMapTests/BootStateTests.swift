import Testing
import SwiftUI
import UIKit
@testable import MyAIMap

/// Covers the branded cold-launch boot state: the ProgressOrb overlay
/// shown from app launch until the RealityKit scene signals readiness.
@Suite("Boot state")
@MainActor
struct BootStateTests {

    private func render(_ view: some View, size: CGSize) -> UIImage? {
        let content = ZStack { Color.black; view }
            .environment(UniverseViewModel())
            .environment(AppSettings(defaults: UserDefaults(suiteName: "BootStateTests.\(UUID().uuidString)")!))
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 2
        return renderer.uiImage
    }

    /// ProgressOrb renders to a non-nil image with a non-zero size.
    @Test func progressOrbRendersNonNil() {
        let image = render(ProgressOrb(), size: CGSize(width: 80, height: 80))
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
        #expect((image?.size.height ?? 0) > 0)
    }

    /// ProgressOrb carries the correct VoiceOver accessibility label.
    /// The label is pinned as a string literal in ShimmerLoader.swift: "Loading universe".
    /// SwiftUI accessibility labels flow through the accessibility system rather than
    /// UIKit's `accessibilityLabel` property, so we verify via the hosting controller's
    /// accessibility element count and the known string value from the source.
    @Test func progressOrbAccessibilityLabel() {
        let orb = ProgressOrb()
        let host = UIHostingController(rootView: orb)
        host.view.frame = CGRect(origin: .zero, size: CGSize(width: 80, height: 80))
        host.view.layoutIfNeeded()
        // Collect labels from the accessibility tree (SwiftUI exposes them
        // via `accessibilityElements` on the hosting view).
        let label = accessibilityLabel(from: host.view)
        #expect(label == "Loading universe", "ProgressOrb accessibility label must be 'Loading universe', got '\(label ?? "nil")'")
    }

    /// Recursively collects the first non-nil, non-empty accessibilityLabel from
    /// the UIKit element tree. SwiftUI flattens the hierarchy such that the
    /// hosting view's first child element carries the label of the top-level
    /// accessible view modifier.
    private func accessibilityLabel(from view: UIView) -> String? {
        // Check accessibilityElements array first (SwiftUI's primary path).
        if let elements = view.accessibilityElements {
            for element in elements {
                if let el = element as? NSObject,
                   let lbl = el.accessibilityLabel, !lbl.isEmpty {
                    return lbl
                }
            }
        }
        if view.isAccessibilityElement,
           let lbl = view.accessibilityLabel, !lbl.isEmpty {
            return lbl
        }
        for sub in view.subviews {
            if let found = accessibilityLabel(from: sub) { return found }
        }
        return nil
    }
}
