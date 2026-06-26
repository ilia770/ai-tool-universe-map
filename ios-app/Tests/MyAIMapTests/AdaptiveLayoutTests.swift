import Testing
import SwiftUI
@testable import MyAIMap

@Suite("Adaptive layout")
struct AdaptiveLayoutTests {
    @Test @MainActor func missingHorizontalSizeClassUsesCompactFallback() {
        #expect(AdaptiveLayout.isCompact(nil))
    }

    @Test @MainActor func compactHorizontalSizeClassUsesBottomSheet() {
        #expect(AdaptiveLayout.isCompact(.compact))
    }

    @Test @MainActor func regularHorizontalSizeClassUsesInspectorPanel() {
        #expect(!AdaptiveLayout.isCompact(.regular))
    }
}
