import SwiftUI

/// XCUITest-only harness proving the GlassMorphCluster morph + hit area. Gated
/// behind `-uitestGlassDemo`; never reachable in production.
struct GlassDemoScreen: View {
    private struct Opt: Identifiable { let id: Int; let title: String }
    private let options = [Opt(id: 0, title: "Map"), Opt(id: 1, title: "Friends"), Opt(id: 2, title: "Passport")]
    @State private var selection = 0

    var body: some View {
        VStack(spacing: BrandSpacing.section.value) {
            Text("\(selection)")
                .accessibilityIdentifier("GlassDemo.selectedIndex")
                .accessibilityValue("\(selection)")
            GlassMorphCluster(options: options, selection: $selection, base: "GlassDemo.cluster") { opt, selected in
                Text(opt.title).foregroundStyle(selected ? .white : .white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColor.void)
        .preferredColorScheme(.dark)
    }
}
