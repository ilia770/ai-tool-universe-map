import Testing
import SwiftUI
import UIKit
@testable import MyAIMap

@Suite("NodeBadge")
@MainActor
struct NodeBadgeTests {

    // MARK: - Metrics: absolute values

    @Test func toolHeight() {
        #expect(NodeBadgeMetrics.height(for: .tool) == 22)
    }

    @Test func categoryHeight() {
        #expect(NodeBadgeMetrics.height(for: .category) == 26)
    }

    @Test func focusedHeight() {
        #expect(NodeBadgeMetrics.height(for: .focused) == 30)
    }

    @Test func toolMaxWidth() {
        #expect(NodeBadgeMetrics.maxWidth(for: .tool) == 116)
    }

    @Test func categoryMaxWidth() {
        #expect(NodeBadgeMetrics.maxWidth(for: .category) == 160)
    }

    @Test func focusedMaxWidth() {
        #expect(NodeBadgeMetrics.maxWidth(for: .focused) == 232)
    }

    // MARK: - Metrics: ordering invariants

    /// Tool is smaller than category in both height and max-width.
    @Test func heightOrderingToolLessThanCategory() {
        #expect(NodeBadgeMetrics.height(for: .tool) < NodeBadgeMetrics.height(for: .category))
    }

    @Test func heightOrderingCategoryLessThanFocused() {
        #expect(NodeBadgeMetrics.height(for: .category) < NodeBadgeMetrics.height(for: .focused))
    }

    @Test func widthOrderingToolLessThanCategory() {
        #expect(NodeBadgeMetrics.maxWidth(for: .tool) < NodeBadgeMetrics.maxWidth(for: .category))
    }

    @Test func widthOrderingCategoryLessThanFocused() {
        #expect(NodeBadgeMetrics.maxWidth(for: .category) < NodeBadgeMetrics.maxWidth(for: .focused))
    }

    // MARK: - Smoke renders

    private func render(_ view: some View, size: CGSize = CGSize(width: 300, height: 100)) -> UIImage? {
        let content = ZStack {
            Color.black
            view
        }
        .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 2
        return renderer.uiImage
    }

    @Test func rendersToolBadgeNonNil() {
        let badge = NodeBadge(
            title: "Cursor",
            role: .tool,
            categoryColor: .cyan,
            icon: nil,
            opacity: 1,
            onTap: {}
        )
        let image = render(badge)
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    @Test func rendersCategoryBadgeNonNil() {
        let badge = NodeBadge(
            title: "Coding",
            role: .category,
            categoryColor: .purple,
            icon: nil,
            opacity: 1,
            onTap: {}
        )
        let image = render(badge)
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    @Test func rendersFocusedBadgeNonNil() {
        let badge = NodeBadge(
            title: "Cursor — AI Code Editor",
            role: .focused,
            categoryColor: .cyan,
            icon: nil,
            opacity: 1,
            onTap: {}
        )
        let image = render(badge)
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    @Test func rendersWithIconNonNil() {
        let badge = NodeBadge(
            title: "With Icon",
            role: .tool,
            categoryColor: .orange,
            icon: Image(systemName: "star.fill"),
            opacity: 1,
            onTap: {}
        )
        let image = render(badge)
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    // MARK: - Opacity threads through

    @Test func zeroOpacityBadgeStillRenders() {
        // A badge with opacity 0 should still render a non-nil image
        // (it just has no visible pixels — but the renderer shouldn't crash).
        let badge = NodeBadge(
            title: "Hidden",
            role: .tool,
            categoryColor: .gray,
            icon: nil,
            opacity: 0,
            onTap: {}
        )
        let image = render(badge)
        #expect(image != nil)
    }
}
