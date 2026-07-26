import SwiftUI

/// Chrome and presentations layered above the release 2D constellation.
/// Node labels and placement remain owned by `UniverseConstellationView`.
struct UniverseOverlayView: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let planets: [PlanetData]
    let mode: UniverseMode
    let selectedPlanet: PlanetData
    let selectedTool: Tool
    let onCategorySelect: (ToolCategoryId) -> Void
    let onToolSelect: (String) -> Void
    let onOpenToolDetail: (String) -> Void
    let onChatActivityChange: (Bool) -> Void
    let onDetails: () -> Void
    let onAccount: () -> Void
    let onAddTool: () -> Void
    /// §2 morph: namespace (owned by `UniverseMapView`) shared with the Account
    /// and Add Tool sheets so the trigger buttons zoom-morph into them.
    let chromeMorphNamespace: Namespace.ID
    let onAddSuggestedTool: (MissingToolSuggestion) -> Void

    @State private var isRailActive = false
    @Namespace private var chromeNamespace

    private var isFocusedOnTool: Bool {
        guard let selectedToolID = mode.selectedToolID else { return false }
        return selectedTool.id == selectedToolID && selectedTool.category == selectedPlanet.id
    }

    var body: some View {
        ZStack {
            // D1: the top chrome floats over the map with no safe-area inset, so
            // map node labels near the top (e.g. a node's "Research" label) read
            // as clipped UNDER the pills. We can't push the free-form 2D graph
            // layout down without touching 2D graph logic (Track A), so back the
            // chrome band with a subtle top scrim that fades to clear: any label
            // beneath stays legible and the overlap reads as intentional. Sits at
            // the back of the stack — over the 2D map, behind the 3D label layers
            // (which manage their own placement) and behind the chrome itself.
            if !mode.isDetailOpen && !mode.isChatOpen {
                topChromeScrim
            }

            if isRailActive {
                // RIGHT_RAIL_SPEC: the rail must not cover the map. Constrain the
                // readability treatment to a trailing strip behind the rail/list
                // that fades to clear toward the map, instead of a full-screen scrim.
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    // Frosted dim strip behind the rail text picker: a real material
                    // blur softened by a mask that fades to clear toward the map, so
                    // the readability treatment never covers the map (RIGHT_RAIL_SPEC).
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            LinearGradient(
                                colors: [.clear, Color.black.opacity(0.34)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: railContrastWidth)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            if model.isUniverseEmpty && !mode.isDetailOpen && !mode.isChatOpen {
                emptyStateCard
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            VStack(spacing: 0) {
                if !mode.isDetailOpen && !mode.isChatOpen {
                    topChrome
                        .padding(.horizontal, BrandSpacing.l.value)
                        .padding(.top, BrandSpacing.m.value)
                }

                Spacer()

                bottomControls
                    .padding(.horizontal, BrandSpacing.l.value)
                    .padding(.bottom, 10)
            }
        }
    }

    private var railContrastWidth: CGFloat { 220 }

    private var rightUniverseRail: some View {
        HStack {
            Spacer()
            UniverseRailView(
                categories: railCategories,
                activeCategory: mode.focusedCategory,
                tint: selectedPlanet.swiftUIColor,
                onActiveChange: { isActive in
                    withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                        isRailActive = isActive
                    }
                },
                onSelect: onCategorySelect
            )
        }
    }

    private var railCategories: [ToolCategory] {
        // Only categories that actually have a planet (>=1 tool). Otherwise a
        // sparse universe exposes empty chips that dead-end on tap (ES-1).
        // Sourced from `allCategories` (seed + custom) so user/AI-created
        // branches get rail chips once they hold a tool.
        let present = Set(planets.map(\.id))
        let all = model.allCategories
        let core = all.filter { $0.id == .core && present.contains(.core) }
        let branches = all.filter { $0.id != .core && present.contains($0.id) }
        return core + branches
    }

    /// D1: dark-to-clear gradient behind the floating top chrome so map node
    /// labels that fall under the pills stay readable instead of looking clipped.
    /// Pinned to the top and extended through the top safe area; never blocks map
    /// hit-testing. Tuned to cover the status bar + chrome band (≈ safe-area top +
    /// 14pt top padding + cluster height) then fade out.
    private var topChromeScrim: some View {
        LinearGradient(
            colors: [BrandColor.void.opacity(0.72), BrandColor.void.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 140)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var topChrome: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 16) {
                    topChromeContent
                }
            } else {
                topChromeContent
            }
        }
        // Gate the chrome morph to 3D: `mode` also changes on the 2D graph
        // (planet/tool taps), so an unconditional value animates the shared
        // top chrome on 2D nav too. In 2D pin the value to a constant → no
        // implicit animation (keeps the 2D path untouched, Track A). Mirrors
        // the `bottomControls` reveal gate below.
        .brandAnimation(BrandMotion.morph, value: mode)
    }

    private var topChromeContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Spacer()
            Button(action: onAccount) {
                UserAvatarImage(size: 46, tint: .white.opacity(0.88))
            }
            .buttonStyle(BouncyIconButtonStyle())
            .navigationGlassMorphID("UniverseChrome.profile", in: chromeNamespace)
            .matchedTransitionSource(id: ChromeMorphID.account, in: chromeMorphNamespace)
            .opacity(mode.isDetailOpen ? 0.58 : 1)
            .accessibilityLabel("Account")
        }
        .transition(.scale(scale: 0.94).combined(with: .opacity))
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            if SpatialReveal.showsToolCard(mode: mode) {
                SpatialRevealCard(
                    toolName: selectedTool.name,
                    categoryName: UniverseSeed.category(selectedTool.category).shortName,
                    summary: selectedTool.summary,
                    tint: selectedPlanet.swiftUIColor,
                    onOpen: onDetails
                )
                .parallaxTilt(maxOffset: 6)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if !mode.isDetailOpen {
                SearchDock(
                    isChatOpen: mode.isChatOpen,
                    onAddTool: onAddTool,
                    onAddSuggestedTool: onAddSuggestedTool,
                    onToolSelect: onToolSelect,
                    onOpenToolDetail: onOpenToolDetail,
                    onChatActivityChange: onChatActivityChange,
                    // When empty, the empty-state card's Add button owns the
                    // morph; opt the composer out so the id isn't duplicated.
                    addToolMorphNamespace: model.isUniverseEmpty ? nil : chromeMorphNamespace
                )
            }
        }
        // Gate the reveal spring to 3D: `bottomControls` is shared with the 2D
        // graph (PlanetInfoCard/SearchDock), so an unconditional value would
        // animate 2D content on tool-selection too. In 2D the value is pinned to
        // nil → constant → no implicit animation (keeps the 2D path untouched).
        .brandAnimation(
            BrandMotion.reveal,
            value: SpatialReveal.showsToolCard(mode: mode) ? mode.selectedToolID : nil
        )
    }

    /// Onboarding shown when the universe has no tools yet: the user either adds
    /// their first tool (which becomes the first planet) or loads the bundled
    /// sample universe.
    private var emptyStateCard: some View {
        LiquidGlassCard(cornerRadius: 28) {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.92))
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text("Your universe is empty")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text("Add the AI tools you use — each one becomes a planet you can fly between.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button {
                    BrandHaptics.fire(.medium)
                    onAddTool()
                } label: {
                    Label("Add your first tool", systemImage: "plus")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.9))
                .padding(.vertical, 11)
                .padding(.horizontal, BrandSpacing.l.value)
                .background(.white.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
                .foregroundStyle(.white)
                .matchedTransitionSource(id: ChromeMorphID.addTool, in: chromeMorphNamespace)

                Button {
                    BrandHaptics.fire(.light)
                    onChatActivityChange(true)
                } label: {
                    Label("Ask AI", systemImage: "sparkle")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.9))
                .padding(.vertical, 9)
                .padding(.horizontal, BrandSpacing.l.value)
                .glassSurface(in: Capsule(), interactive: true)
                .foregroundStyle(.white.opacity(0.9))

                Button {
                    BrandHaptics.fire(.light)
                    withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
                        _ = model.loadSampleUniverse()
                    }
                } label: {
                    Text("Load a sample universe")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, BrandSpacing.xxl.value)
        .frame(maxWidth: 320)
        }
    }
}
