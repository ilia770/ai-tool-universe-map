import Testing
import SwiftUI
import UIKit
@testable import MyAIMap

@Suite("ChatDock — scroll behaviour")
@MainActor
struct ChatDockScrollTests {

    // MARK: - Helpers

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ChatDockScrollTests.\(UUID().uuidString)")!
    }

    private let liveIds: Set<String> = ["neon", "figma", "notion", "linear", "vercel"]

    /// Render a SwiftUI view hierarchy to a UIImage via ImageRenderer.
    private func render(_ view: some View, size: CGSize = CGSize(width: 390, height: 844)) -> UIImage? {
        let content = view
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1
        return renderer.uiImage
    }

    // MARK: - Static contract

    @Test func bottomAnchorIDIsStable() {
        #expect(ChatDock.bottomAnchorID == "chatdock.bottom")
    }

    // MARK: - Render smoke

    @Test func rendersNonNilWithEmptyThread() {
        let store = ChatThreadStore(defaults: makeDefaults(), liveToolIds: liveIds)
        let view = ZStack {
            Color.black
            ChatDock()
        }
        .environment(UniverseViewModel())
        .environment(store)
        let image = render(view)
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    @Test func rendersNonNilWithMultiTurnThread() {
        let defaults = makeDefaults()
        let store = ChatThreadStore(defaults: defaults, liveToolIds: liveIds)
        store.append(query: "build a database fast", answer: "Try Neon — serverless Postgres.", matchIds: ["neon"])
        store.append(query: "design tool", answer: "Figma is the standard.", matchIds: ["figma"])
        store.append(query: "project management", answer: "Linear or Notion.", matchIds: ["linear", "notion"])
        store.append(query: "deploy frontend", answer: "Vercel is instant.", matchIds: ["vercel"])

        let view = ZStack {
            Color.black
            ChatDock()
        }
        .environment(UniverseViewModel())
        .environment(store)

        let image = render(view)
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    // MARK: - Data invariant

    @Test func turnsLastIsNewest() {
        let store = ChatThreadStore(defaults: makeDefaults(), liveToolIds: liveIds)
        store.append(query: "q1", answer: "a1", matchIds: [])
        store.append(query: "q2", answer: "a2", matchIds: [])
        store.append(query: "q3", answer: "a3", matchIds: [])
        #expect(store.turns.last?.q == "q3")
    }

    @Test func turnsIdsMonotonicallyIncreasing() {
        let store = ChatThreadStore(defaults: makeDefaults(), liveToolIds: liveIds)
        for i in 1...5 {
            store.append(query: "q\(i)", answer: "a\(i)", matchIds: [])
        }
        let ids = store.turns.map(\.id)
        for i in 1..<ids.count {
            #expect(ids[i] > ids[i - 1])
        }
    }
}
