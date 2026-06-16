import Testing
import SwiftUI
import UIKit
@testable import MyAIMap

/// Lightweight, deterministic snapshot harness for the SwiftUI chrome
/// (NOT the RealityKit 3D scene — that can't render deterministically
/// headless). Each chrome view is rasterised with `ImageRenderer` and
/// asserted on stable, OS-/font-independent facts:
///
/// 1. It renders to a non-nil `UIImage` with a non-zero size at a
///    representative frame. A nil or zero-size image means the view
///    failed to build or lay out → regression caught.
/// 2. It produces visible pixels (not a fully transparent/blank canvas),
///    sampled on a cheap grid rather than pixel-by-pixel.
///
/// This is deliberately NOT pixel-diffing against committed reference
/// PNGs: those are brittle across OS/font versions and bloat the repo.
/// The goal is a regression net for "this view renders something",
/// plus a couple of state-driven layout assertions.
///
/// The test bundle is hosted (`TEST_HOST` / `BUNDLE_LOADER` in
/// project.yml), so a UIKit/SwiftUI runtime is available and
/// `@MainActor ImageRenderer` works in the test process.
@Suite("Chrome snapshot harness")
@MainActor
struct ChromeSnapshotTests {

    // MARK: - Render helper

    /// Wraps `view` with a deterministic `UniverseViewModel` from `model`
    /// (defaults to a fresh seed-backed model in the .core overview),
    /// frames it at `size` against a black backdrop (the app's locked
    /// dark surface), and rasterises at scale 2 via `ImageRenderer`.
    /// Returns nil only when the renderer itself yields no image.
    private func render(
        _ view: some View,
        size: CGSize,
        model: UniverseViewModel = UniverseViewModel()
    ) -> UIImage? {
        let content = ZStack {
            Color.black
            view
        }
        .environment(model)
        .environment(AppSettings(defaults: UserDefaults(suiteName: "ChromeSnapshotTests.\(UUID().uuidString)")!))
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 2
        return renderer.uiImage
    }

    /// "Is anything drawn" check: redraws the image into an RGBA context
    /// and scans every pixel, returning true as soon as one is
    /// non-transparent AND not the pure-black backdrop. Chrome snapshots
    /// are tiny (≤360×400 @2x), so a full scan is cheap and — unlike a
    /// coarse grid — never misses small accents like the rail's category
    /// dots on dark glass.
    private func hasVisibleContent(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let width = cg.width
        let height = cg.height
        guard width > 0, height > 0 else { return false }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var offset = 0
        let count = pixels.count
        while offset + 3 < count {
            let r = pixels[offset]
            let g = pixels[offset + 1]
            let b = pixels[offset + 2]
            let a = pixels[offset + 3]
            // Visible = some opacity AND not the black backdrop.
            if a > 0 && (r > 8 || g > 8 || b > 8) {
                return true
            }
            offset += bytesPerPixel
        }
        return false
    }

    /// Asserts a chrome view renders to a non-nil image with non-zero
    /// size and at least some visible (non-backdrop) pixels.
    private func expectRenders(
        _ view: some View,
        size: CGSize,
        model: UniverseViewModel = UniverseViewModel(),
        requireVisibleContent: Bool = true,
        _ label: Comment
    ) {
        guard let image = render(view, size: size, model: model) else {
            Issue.record("\(label): ImageRenderer returned nil")
            return
        }
        #expect(image.size.width > 0, label)
        #expect(image.size.height > 0, label)
        // ImageRenderer does not lay out the content of a bare ScrollView
        // (no real scroll container), so a view that is ONLY a ScrollView
        // rasterizes blank even though it renders fine on screen. Such
        // views are checked for a successful non-zero render only.
        if requireVisibleContent {
            #expect(hasVisibleContent(image), "\(label.rawValue) rendered blank/transparent")
        }
    }

    // MARK: - Per-view render coverage

    @Test func searchDockRenders() {
        expectRenders(SearchDock(), size: CGSize(width: 360, height: 60), "SearchDock")
    }

    @Test func categoryRailRenders() {
        // CategoryRail is a bare horizontal ScrollView — ImageRenderer
        // can't lay out its chips, so verify a successful render only.
        expectRenders(
            CategoryRail { _ in },
            size: CGSize(width: 360, height: 60),
            requireVisibleContent: false,
            "CategoryRail"
        )
    }

    @Test func clarityMenuRenders() {
        expectRenders(ClarityMenu(), size: CGSize(width: 240, height: 44), "ClarityMenu")
    }

    @Test func toolDetailSectionRenders() {
        expectRenders(
            ToolDetailSection(),
            size: CGSize(width: 360, height: 400),
            "ToolDetailSection"
        )
    }

    @Test func accountButtonRenders() {
        expectRenders(
            AccountButton(action: {}),
            size: CGSize(width: 56, height: 56),
            "AccountButton"
        )
    }

    // MARK: - State-driven layout

    /// `figma` has relationIds in the seed, so the "CONNECTED TO" branch
    /// of `ToolDetailSection` lays out. Both this and the default
    /// (founder-os / .core) state must render non-nil — a layout crash or
    /// empty body in either branch is a regression.
    @Test func toolDetailSectionRendersFocusedToolWithRelations() {
        let model = UniverseViewModel()
        let focused = model.focusTool("figma")
        #expect(focused, "seed must contain `figma`")
        #expect(!model.selectedTool.relationIds.isEmpty, "`figma` must have relations for the CONNECTED TO branch")
        expectRenders(
            ToolDetailSection(),
            size: CGSize(width: 360, height: 400),
            model: model,
            "ToolDetailSection (focused tool with relations)"
        )
    }

    /// Default model selects founder-os in the .core overview — exercises
    /// the same view with a different selection/category and the core
    /// rail fallback. Renders non-nil.
    @Test func toolDetailSectionRendersDefaultCoreSelection() {
        let model = UniverseViewModel()
        #expect(model.selection.activeCategory == .core)
        #expect(model.selectedTool.id == "founder-os")
        expectRenders(
            ToolDetailSection(),
            size: CGSize(width: 360, height: 400),
            model: model,
            "ToolDetailSection (default core selection)"
        )
    }

    /// `PocketReadout` renders its glass card only when the active
    /// category is NOT .core; in .core it intentionally returns an empty
    /// body. Assert the populated (non-core) case renders visible content.
    @Test func pocketReadoutRendersForNonCoreCategory() {
        let model = UniverseViewModel()
        model.selectCategory(.coding)
        #expect(model.selection.activeCategory != .core)
        expectRenders(
            PocketReadout(),
            size: CGSize(width: 240, height: 80),
            model: model,
            "PocketReadout (non-core category)"
        )
    }

    /// At .core, `PocketReadout` is an empty body — a near-empty render is
    /// the expected, correct behavior. Assert only that rendering it does
    /// NOT crash and yields an image (which is the black backdrop alone),
    /// so we don't falsely flag the intended empty state as a failure.
    @Test func pocketReadoutIsEmptyAtCore() {
        let model = UniverseViewModel()
        #expect(model.selection.activeCategory == .core)
        let image = render(
            PocketReadout(),
            size: CGSize(width: 240, height: 80),
            model: model
        )
        #expect(image != nil, "render of empty PocketReadout should still produce a backdrop image")
        if let image {
            #expect(image.size.width > 0 && image.size.height > 0)
        }
    }
}
