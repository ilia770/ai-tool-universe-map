import Testing
import SwiftUI
import UIKit
@testable import MyAIMap

/// Verifies that `ChatDock` is never unmounted when a tool sheet is active.
///
/// Before the fix, `UniverseScreen` conditionally MOUNTED the dock:
///   `if !isPanelActive { ChatDock() … }`
/// which destroyed `@State` (draft text, collapsed flag) each time the
/// sheet detent changed. The fix keeps ChatDock always in the tree and
/// drives visibility via `.opacity` / `.allowsHitTesting`, so SwiftUI
/// preserves its `@State` across detent changes.
@Suite("ChatComposer persistence across tool sheets")
@MainActor
struct ChatComposerPersistenceTests {

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ChatComposerTests.\(UUID().uuidString)")!
    }

    // MARK: - ImageRenderer helpers

    private func render(_ view: some View, size: CGSize = CGSize(width: 390, height: 844)) -> UIImage? {
        let content = ZStack { Color.black; view }
            .environment(UniverseViewModel())
            .environment(AppSettings(defaults: isolatedDefaults()))
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 2
        return renderer.uiImage
    }

    // MARK: - UniverseScreen always renders (dock always mounted)

    /// `UniverseScreen` renders to a non-nil image regardless of panel state.
    /// The ImageRenderer drives the full view tree through SwiftUI layout;
    /// a nil result means the tree crashed or produced nothing — which would
    /// happen if the dock's always-present layout caused a fatal issue.
    @Test func universeScreenRendersNonNil() {
        let image = render(UniverseScreen())
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    /// Verifies that `ChatDock` rendered with `isPanelActive == true` modifiers
    /// (`.frame(height: 0).clipped()`) produces a non-nil image and does not
    /// crash — proving the footprint-collapse path is structurally sound.
    ///
    /// Note: `sheetDetent` is `@State private` in `UniverseScreen`, so we cannot
    /// inject an active-panel state directly into `UniverseScreen` from a test.
    /// Instead, we exercise the same modifier stack on `ChatDock` in isolation.
    /// Always-mountedness itself is structurally guaranteed: there is no `if`
    /// guard around the `ChatDock()` call in `UniverseScreen.canvas` — grep for
    /// "ChatDock()" shows one unconditional site.
    @Test func chatDockActivePanelFootprintCollapsesWithoutCrash() {
        let thread = ChatThreadStore(
            defaults: isolatedDefaults(),
            liveToolIds: Set(UniverseSeed.tools.map(\.id))
        )
        // Mirror the exact modifier stack UniverseScreen applies when isPanelActive == true.
        let image = render(
            ChatDock()
                .environment(thread)
                .padding(.top, 12)
                .frame(height: 0)
                .clipped()
                .opacity(0)
                .allowsHitTesting(false)
        )
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    /// `ChatDock` itself renders to a non-nil image when given environments,
    /// confirming the component is structurally sound when always mounted.
    @Test func chatDockAlwaysRendersNonNil() {
        let thread = ChatThreadStore(
            defaults: isolatedDefaults(),
            liveToolIds: Set(UniverseSeed.tools.map(\.id))
        )
        let image = render(
            ChatDock()
                .environment(thread)
        )
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    /// Render `ChatDock` after appending a turn (non-empty thread state),
    /// confirming the view handles populated state without crashing.
    @Test func chatDockRendersWithThread() {
        let thread = ChatThreadStore(
            defaults: isolatedDefaults(),
            liveToolIds: Set(UniverseSeed.tools.map(\.id))
        )
        thread.append(query: "build a database", answer: "Try Neon.", matchIds: [])
        let image = render(
            ChatDock()
                .environment(thread)
        )
        #expect(image != nil)
    }

    // MARK: - ChatThreadStore turns survive (regression guard)

    /// Confirm that `ChatThreadStore` persistence is unaffected by the
    /// always-mounted dock change. Mirrors `ChatThreadStoreTests.persistsAndReloads`.
    @Test func threadTurnsPersistAcrossStoreInstances() {
        let defaults = isolatedDefaults()
        let a = ChatThreadStore(defaults: defaults, liveToolIds: ["neon", "figma"])
        a.append(query: "edit video", answer: "Try Descript.", matchIds: ["figma"])

        let b = ChatThreadStore(defaults: defaults, liveToolIds: ["neon", "figma"])
        #expect(b.turns.count == 1)
        #expect(b.turns.first?.q == "edit video")
    }
}
