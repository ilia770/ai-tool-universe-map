import Testing
import SwiftUI
import UIKit
@testable import MyAIMap

/// R4 — chrome render/snapshot safety net (review:
/// docs/reviews/2026-06-21-liquid-glass-redesign-multi-agent-sweep.md).
///
/// Phase 0 rewrites the glass helper and brand tokens; that is exactly the kind
/// of change a chrome render harness should catch. There is **no baseline-image
/// infrastructure** in this repo, so these are *smoke renders*: each key chrome
/// view is hosted in `ImageRenderer` and we assert it produces a non-empty image
/// at a sane size. We deliberately do **not** pixel-diff.
///
/// Every view is rendered twice — once with the default environment and once
/// with `\.accessibilityReduceTransparency == true` — so the reduce-transparency
/// fallback path of the glass surfaces is exercised on every chrome view.
@MainActor
@Suite("Chrome render smoke")
struct ChromeSnapshotTests {

    // MARK: - Harness

    /// A render canvas large enough to host the docks/sheets without collapsing
    /// to a zero-size proposal. Matches a regular-width iPhone portrait.
    private static let canvas = CGSize(width: 393, height: 852)

    /// Renders `view` to a `UIImage` and asserts it is non-empty at a sane size.
    /// `reduceTransparency` flips `\.accessibilityReduceTransparency` so the
    /// opaque glass fallback path is taken.
    ///
    /// Returns the rendered image so individual tests can add extra assertions.
    @discardableResult
    private func assertRenders(
        _ label: String,
        reduceTransparency: Bool,
        dynamicTypeSize: DynamicTypeSize = .large,
        size: CGSize = ChromeSnapshotTests.canvas,
        @ViewBuilder _ content: () -> some View
    ) throws -> UIImage {
        let hosted = content()
            .frame(width: size.width, height: size.height)
            // `\.accessibilityReduceTransparency` is get-only in the iOS 26.5 SDK
            // (its public KeyPath is not Writable), so the documented
            // `.environment(\.accessibilityReduceTransparency, true)` form does
            // not compile. `_accessibilityReduceTransparency` is the SDK's
            // writable backing key and is the same value the system and our
            // `GlassSurfaceModifier` (LiquidGlass.swift:62) read — so this drives
            // the real reduce-transparency / opaque `glassSolid` fallback path.
            .environment(\._accessibilityReduceTransparency, reduceTransparency)
            // The app is locked to dark; render in the real appearance.
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, dynamicTypeSize)

        let renderer = ImageRenderer(content: hosted)
        renderer.scale = 2

        let image = renderer.uiImage
        #expect(
            image != nil,
            "\(label) [reduceTransparency=\(reduceTransparency)] produced no image"
        )
        let rendered = try #require(image)

        // Sane-size smoke check: a real render, not a 0×0 / 1×1 degenerate.
        #expect(
            rendered.size.width >= 50 && rendered.size.height >= 50,
            "\(label) [reduceTransparency=\(reduceTransparency)] rendered too small: \(String(describing: rendered.size))"
        )
        return rendered
    }

    /// A fresh, isolated view model. `sample: true` loads the seed universe so
    /// tool-dependent chrome (detail) has content to show.
    private func makeModel(sample: Bool = false) -> UniverseViewModel {
        let defaults = UserDefaults(suiteName: "chrome-snapshot-\(UUID().uuidString)")!
        let model = UniverseViewModel(store: UniverseStore(defaults: defaults))
        if sample { model.loadSampleUniverse() }
        return model
    }

    // MARK: - SearchDock (composer / assistant dock)

    @Test func chatScreenRenders() throws {
        for reduce in [false, true] {
            let model = makeModel(sample: true)
            try assertRenders("ChatScreen", reduceTransparency: reduce) {
                ChatScreen(
                    onOpenSettings: {},
                    onAddTool: {},
                    onAddSuggestedTool: { _ in },
                    onOpenToolInUniverse: { _ in }
                )
                .environment(model)
            }
        }
    }

    @Test func rootShellRendersChatFirst() throws {
        for reduce in [false, true] {
            let model = makeModel(sample: true)
            try assertRenders("RootShell", reduceTransparency: reduce) {
                RootShell()
                    .environment(model)
            }
        }
    }

    @Test func chatFirstChromeRendersWithAccessibilitySettings() throws {
        let model = makeModel(sample: true)
        try assertRenders(
            "ChatScreen-AX",
            reduceTransparency: true,
            dynamicTypeSize: .accessibility3
        ) {
            ChatScreen(
                onOpenSettings: {},
                onAddTool: {},
                onAddSuggestedTool: { _ in },
                onOpenToolInUniverse: { _ in }
            )
            .environment(model)
        }

        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: model.visibleAllTools)
        let planet = try #require(planets.first { $0.id == .analytics })
        let tool = try #require(planet.tools.first)
        try assertRenders(
            "PlanetInfoCard-AX",
            reduceTransparency: true,
            dynamicTypeSize: .accessibility3,
            size: CGSize(width: 393, height: 160)
        ) {
            PlanetInfoCard(
                planet: planet,
                selectedTool: tool,
                isFocusedOnTool: true,
                mode: .toolSelected(tool.category, tool.id),
                onOpenDetails: {}
            )
            .padding(16)
            .background(Color.black)
        }
    }

    @Test func searchDockRenders() throws {
        for reduce in [false, true] {
            let model = makeModel(sample: true)
            try assertRenders("SearchDock", reduceTransparency: reduce) {
                SearchDock()
                    .environment(model)
            }
        }
    }

    // MARK: - CategoryRail

    @Test func categoryRailRenders() throws {
        for reduce in [false, true] {
            // Sample-loaded: the rail only lists categories that have visible
            // tools, so an empty universe would render an empty rail.
            let model = makeModel(sample: true)
            try assertRenders("CategoryRail", reduceTransparency: reduce) {
                CategoryRail(onSelect: { _ in })
                    .environment(model)
            }
        }
    }

    // MARK: - ToolDetailSection

    @Test func toolDetailSectionRenders() throws {
        for reduce in [false, true] {
            let model = makeModel(sample: true)
            // Pin a concrete selection so the detail body has a real tool.
            let firstID = UniverseSeed.tools[0].id
            model.selectTool(firstID)
            #expect(model.selectedTool != nil)

            try assertRenders("ToolDetailSection", reduceTransparency: reduce) {
                ToolDetailSection(onOpenRelatedTool: nil)
                    .environment(model)
            }
        }
    }

    // MARK: - AddToolSheet

    @Test func addToolSheetRenders() throws {
        for reduce in [false, true] {
            let model = makeModel()
            try assertRenders("AddToolSheet", reduceTransparency: reduce) {
                AddToolSheet(draft: nil)
                    .environment(model)
            }
        }
    }

    // MARK: - AccountSettingsSheet

    @Test func accountSettingsSheetRenders() throws {
        for reduce in [false, true] {
            let model = makeModel(sample: true)
            try assertRenders("AccountSettingsSheet", reduceTransparency: reduce) {
                AccountSettingsSheet()
                    .environment(model)
            }
        }
    }
}
