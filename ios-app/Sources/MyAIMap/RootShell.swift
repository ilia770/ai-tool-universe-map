import SwiftUI

enum RootSurface: String, Equatable {
    case chat
    case universe
}

/// Pure first-run routing rules, kept free of view state so the cold-start
/// decision (which surface to land on, whether to show the onboarding overlay)
/// is unit-testable.
enum RootFirstRun {
    /// Cold start always lands on the map surface — never the open-ended chat
    /// question state. (Returning users land here too; their last state is
    /// re-derived from persisted tools.)
    static func initialSurface(hasSeenOnboarding: Bool) -> RootSurface {
        .universe
    }

    /// The one-screen onboarding overlay shows only on a true first run,
    /// independent of whether the universe is empty.
    static func showsOnboarding(hasSeenOnboarding: Bool) -> Bool {
        !hasSeenOnboarding
    }
}

/// Pure micro-interaction rules for the root shell, kept free of view state so
/// they can be unit-tested.
enum RootShellMotion {
    /// The Map badge pops only when the tool count grows. Decrements
    /// (e.g. a removal) and the unchanged initial value settle silently.
    static func badgeShouldPop(from old: Int, to new: Int) -> Bool {
        new > old
    }

    /// Signature add-flow: a ghost of the tapped chat card flies to the Map
    /// pill only when both anchor frames are known. Under reduce-motion the
    /// caller skips the flight (cross-fade + haptic + badge tick instead), so
    /// this gate covers only the "do we have somewhere to fly to" case.
    static func shouldFlyGhost(source: CGRect?, destination: CGRect?) -> Bool {
        guard let source, let destination else { return false }
        return !source.isEmpty && !destination.isEmpty
    }

    /// Card→planet flight: a ghost of the tapped chat chip seats on the tool's
    /// planet in the universe. It only lands once the universe has published a
    /// frame for the *same* tool the flight is for (the published frame tracks
    /// the current selection, so this rejects a stale frame from a previously
    /// selected tool) and both anchors are present and non-empty.
    static func toolGhostShouldLand(
        activeToolID: String?,
        publishedToolID: String?,
        source: CGRect?,
        destination: CGRect?
    ) -> Bool {
        guard let activeToolID, activeToolID == publishedToolID else { return false }
        return shouldFlyGhost(source: source, destination: destination)
    }
}

/// Payload describing the chat tool-chip that was tapped to open a tool's
/// detail, so the shell can fly a matching ghost into that tool's planet.
struct ToolFlightRequest: Equatable {
    let id: UUID
    let toolID: String
    let title: String
    let sourceFrame: CGRect
    let tint: Color
}

/// The tool-planet anchor the universe publishes up to the shell: which tool it
/// is (so a stale frame from a previous selection is rejected) and where its
/// node sits in the shared flight coordinate space.
struct ToolFlightTarget: Equatable {
    let toolID: String
    let frame: CGRect
}

/// Payload describing the chat card that was tapped to add a tool, so the shell
/// can fly a matching ghost toward the Map pill.
struct CardLandRequest: Equatable {
    let id: UUID
    let title: String
    let sourceFrame: CGRect
    let tint: Color
}

/// Shared coordinate space the card source frame and the Map pill destination
/// frame are both resolved in, so the ghost flight maths line up.
enum RootShellCoordinateSpace {
    static let name = "RootShell.flightSpace"
}

/// Reports the Map pill's frame (in the shared coordinate space) up to the shell.
private struct MapPillFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Reports the currently-selected tool's planet anchor (in the shared flight
/// space) up to the shell, so a card→planet ghost knows where to land.
struct ToolFlightTargetPreferenceKey: PreferenceKey {
    static let defaultValue: ToolFlightTarget? = nil
    static func reduce(value: inout ToolFlightTarget?, nextValue: () -> ToolFlightTarget?) {
        if let next = nextValue() { value = next }
    }
}

/// App-level shell for the chat-first IA.
///
/// The universe renderer stays intact; this shell only changes which surface is
/// primary at launch and owns sheets needed from the chat surface.
struct RootShell: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var surfaceNamespace
    /// §2 morph: zoom-transition source namespace shared between the chat chrome
    /// (Profile + composer Plus) and the Account / Add Tool sheets presented here.
    @Namespace private var chromeMorphNamespace
    // Cold start lands on the map (never the open-ended chat state). The
    // returning-vs-first-run distinction only governs the onboarding overlay.
    @State private var surface: RootSurface = .universe
    @State private var accountPresented = false
    @State private var addToolPresented = false
    @State private var addToolDraft: MissingToolSuggestion?
    @State private var lastHandledAddedActivityID: UUID?
    /// Map pill frame in the shared flight coordinate space (destination).
    @State private var mapPillFrame: CGRect = .zero
    /// The in-flight ghost, if any. Set on a chat add-card tap, cleared when
    /// the flight lands.
    @State private var flyingGhost: CardLandRequest?
    /// Drives the ghost from its source frame toward the Map pill once mounted.
    @State private var ghostLanded = false
    /// A card→planet flight, if any: a ghost of the tapped chat tool-chip flying
    /// into that tool's planet. Set on tap, cleared once it seats.
    @State private var toolFlight: ToolFlightRequest?
    /// The tool-planet anchor the universe last published (shared flight space).
    @State private var toolFlightTarget: ToolFlightTarget?
    /// Drives the tool ghost from its chip toward the planet once the anchor is known.
    @State private var toolGhostLanded = false

    var body: some View {
        ZStack {
            switch surface {
            case .chat:
                ChatScreen(
                    onOpenSettings: presentAccount,
                    onAddTool: { presentAddTool(draft: nil) },
                    onAddSuggestedTool: { presentAddTool(draft: $0) },
                    onOpenToolInUniverse: openToolInUniverse,
                    onOpenToolDetail: openToolDetail,
                    onOpenToolFlight: flyToolToPlanet,
                    onBackToMap: { showUniverse(resetSelection: true) },
                    onCardLand: flyCardToMap,
                    chromeMorphNamespace: chromeMorphNamespace
                )
                .transition(diveTransition)

            case .universe:
                UniverseScreen()
                    .transition(diveTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Deep-space backdrop matches the launch screen so the cold-start handoff
        // never flashes pure black before the first frame draws (C1).
        .background(surface == .chat ? ChatTheme.background : BrandColor.void)
        .coordinateSpace(name: RootShellCoordinateSpace.name)
        .overlay { ghostFlightOverlay }
        .overlay { toolFlightOverlay }
        .overlay { onboardingOverlay }
        .onPreferenceChange(MapPillFramePreferenceKey.self) { frame in
            mapPillFrame = frame
        }
        .onPreferenceChange(ToolFlightTargetPreferenceKey.self) { target in
            toolFlightTarget = target
            seatToolGhostIfReady()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            surfaceSwitchChrome
        }
        .preferredColorScheme(.dark)
        .brandAnimation(BrandMotion.morph, value: surface)
        .onAppear {
            BrandHaptics.isEnabled = model.hapticsEnabled
            BrandHaptics.prepare(.light, .medium, .heavy, .success)
            lastHandledAddedActivityID = latestAddedActivity?.id
            // Cold start lands on the map; never the open-ended chat state.
            // The overlay visibility is derived reactively from the persisted
            // flag (see `onboardingOverlay`), so UI-test seeding that marks
            // onboarding seen is always honoured regardless of onAppear order.
            surface = RootFirstRun.initialSurface(hasSeenOnboarding: model.hasSeenOnboarding)
        }
        .onChange(of: model.hapticsEnabled) { _, isEnabled in
            BrandHaptics.isEnabled = isEnabled
        }
        .onChange(of: model.activityHistory.map(\.id)) { _, _ in
            handleLatestAddedActivity()
        }
        .sheet(isPresented: $accountPresented) {
            AccountSettingsSheet()
                .environment(model)
                .liquidGlassSheet()
                .navigationTransition(.zoom(sourceID: ChromeMorphID.account, in: chromeMorphNamespace))
        }
        .sheet(isPresented: $addToolPresented) {
            AddToolSheet(draft: addToolDraft)
                .environment(model)
                .liquidGlassSheet()
                .navigationTransition(.zoom(sourceID: ChromeMorphID.addTool, in: chromeMorphNamespace))
        }
        .onChange(of: addToolPresented) { _, isPresented in
            if !isPresented {
                addToolDraft = nil
            }
        }
    }

    /// Chat⇄universe "dive": the incoming surface scales up from 0.94 + fades in
    /// while the outgoing surface recedes to 1.06 + fades + blurs out. Under
    /// reduce-motion it collapses to a plain cross-fade.
    private var diveTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(
                active: DiveTransitionModifier(scale: 0.94, opacity: 0, blur: 4),
                identity: DiveTransitionModifier(scale: 1, opacity: 1, blur: 0)
            ),
            removal: .modifier(
                active: DiveTransitionModifier(scale: 1.06, opacity: 0, blur: 4),
                identity: DiveTransitionModifier(scale: 1, opacity: 1, blur: 0)
            )
        )
    }

    private var surfaceSwitchChrome: some View {
        HStack {
            Spacer()
            RootSurfaceSwitch(
                surface: surface,
                toolCount: model.visibleAllTools.count,
                namespace: surfaceNamespace,
                onShowChat: askAboutSelection,
                onShowUniverse: { showUniverse(resetSelection: true) }
            )
            // Publish the pill frame (shared flight space) so the add-card
            // ghost knows where to land.
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: MapPillFramePreferenceKey.self,
                        value: proxy.frame(in: .named(RootShellCoordinateSpace.name))
                    )
                }
            }
            Spacer()
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .allowsHitTesting(true)
    }

    /// The signature add-flow ghost: a small capsule mimicking the tapped chat
    /// card that flies from the card's frame to the Map pill on `morph`, fading
    /// and shrinking as it seats. Honours reduce-motion via the caller (which
    /// skips the flight) — here it only renders the flight when one is queued.
    @ViewBuilder
    private var ghostFlightOverlay: some View {
        if let ghost = flyingGhost {
            let destination = CGPoint(x: mapPillFrame.midX, y: mapPillFrame.midY)
            let origin = CGPoint(x: ghost.sourceFrame.midX, y: ghost.sourceFrame.midY)
            let position = ghostLanded ? destination : origin

            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text(ghost.title)
                    .font(.system(.footnote, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(ghost.tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(ghost.tint.opacity(0.16), in: Capsule())
            .overlay { Capsule().stroke(ghost.tint.opacity(0.5), lineWidth: 1) }
            .scaleEffect(ghostLanded ? 0.18 : 1)
            .opacity(ghostLanded ? 0 : 1)
            .position(position)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.identity)
        }
    }

    /// The card→planet flight ghost: a capsule mimicking the tapped chat tool
    /// chip that flies from the chip's frame into the tool's planet on the map,
    /// shrinking + fading as it arrives so it reads as diving into the universe.
    /// Honours reduce-motion via the caller (which skips the flight).
    @ViewBuilder
    private var toolFlightOverlay: some View {
        if let flight = toolFlight, let target = toolFlightTarget?.frame {
            let destination = CGPoint(x: target.midX, y: target.midY)
            let origin = CGPoint(x: flight.sourceFrame.midX, y: flight.sourceFrame.midY)
            let position = toolGhostLanded ? destination : origin

            HStack(spacing: 6) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(flight.title)
                    .font(.system(.footnote, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(flight.tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(flight.tint.opacity(0.16), in: Capsule())
            .overlay { Capsule().stroke(flight.tint.opacity(0.5), lineWidth: 1) }
            .scaleEffect(toolGhostLanded ? 0.32 : 1)
            .opacity(toolGhostLanded ? 0 : 1)
            .position(position)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.identity)
        }
    }

    /// The one-screen first-run onboarding, layered above the map. Each action
    /// (and Skip / scrim tap) marks onboarding seen so it never returns, then
    /// routes to the matching destination.
    @ViewBuilder
    private var onboardingOverlay: some View {
        if RootFirstRun.showsOnboarding(hasSeenOnboarding: model.hasSeenOnboarding) {
            OnboardingOverlay(onAction: handleOnboardingAction)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.02)))
        }
    }

    private func handleOnboardingAction(_ action: OnboardingAction?) {
        // Marking onboarding seen flips the persisted flag, which reactively
        // removes the overlay (animated by the surrounding transaction).
        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
            model.markOnboardingSeen()
        }
        switch action {
        case .askAI:
            showChat()
        case .addTool:
            presentAddTool(draft: nil)
        case .exploreMap, .none:
            showUniverse(resetSelection: true)
        }
    }

    /// Fires the add-flow signature: the `toolLand` rich haptic (honours the
    /// haptics toggle via `fireRich`) plus, when not reduce-motion and both
    /// anchors are known, a ghost flight of the card toward the Map pill. The
    /// badge tick happens independently when the tool count actually changes.
    private func flyCardToMap(_ request: CardLandRequest) {
        BrandHaptics.fireRich(.toolLand)

        guard !reduceMotion,
              RootShellMotion.shouldFlyGhost(source: request.sourceFrame, destination: mapPillFrame)
        else { return }

        ghostLanded = false
        flyingGhost = request
        // Defer the flight one runloop so the ghost mounts at its origin first.
        DispatchQueue.main.async {
            withBrandAnimation(BrandMotion.morph, reduceMotion: reduceMotion) {
                ghostLanded = true
            }
        }
        let activeID = request.id
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            // Only clear if this is still the active flight (avoid clobbering a
            // newer one queued meanwhile).
            if flyingGhost?.id == activeID {
                flyingGhost = nil
                ghostLanded = false
            }
        }
    }

    /// Card→planet orbit motion: open a tool's detail from a chat chip AND fly a
    /// ghost of the chip into that tool's planet on the map. The detail open is
    /// the substance; the flight is the signature "dive into the universe" cue.
    /// Under reduce-motion (or with no captured source frame) it falls back to a
    /// plain detail open. In render modes that publish no planet anchor (e.g.
    /// the RealityKit 3D scene), the ghost simply never seats — a clean no-op.
    private func flyToolToPlanet(_ request: ToolFlightRequest) {
        guard !reduceMotion, !request.sourceFrame.isEmpty else {
            openToolDetail(request.toolID)
            return
        }
        // Reset any prior flight so a stale published target can't seat this one.
        toolGhostLanded = false
        toolFlightTarget = nil
        toolFlight = request
        openToolDetail(request.toolID)
        let activeID = request.id
        Task {
            try? await Task.sleep(for: .milliseconds(760))
            if toolFlight?.id == activeID {
                toolFlight = nil
                toolGhostLanded = false
            }
        }
    }

    /// Seats the in-flight tool ghost once the universe publishes a planet anchor
    /// for the *same* tool the flight is for. Re-checked whenever the universe
    /// republishes (mount, layout, selection change), so the flight rides the
    /// dive into the freshly-mounted map.
    private func seatToolGhostIfReady() {
        guard let flight = toolFlight, !toolGhostLanded,
              RootShellMotion.toolGhostShouldLand(
                  activeToolID: flight.toolID,
                  publishedToolID: toolFlightTarget?.toolID,
                  source: flight.sourceFrame,
                  destination: toolFlightTarget?.frame
              )
        else { return }
        BrandHaptics.fireRich(.toolLand)
        withBrandAnimation(BrandMotion.morph, reduceMotion: reduceMotion) {
            toolGhostLanded = true
        }
    }

    private var explicitlySelectedTool: Tool? {
        guard let toolID = model.universeMode.selectedToolID else { return nil }
        return model.visibleAllTools.first { $0.id == toolID }
    }

    private func showUniverse(resetSelection: Bool = false) {
        if resetSelection, model.universeMode != .overview {
            model.universeMode = .overview
        }
        guard surface != .universe else { return }
        BrandHaptics.fire(.medium)
        withBrandAnimation(BrandMotion.morph, reduceMotion: reduceMotion) {
            surface = .universe
        }
    }

    private func showChat() {
        guard surface != .chat else { return }
        BrandHaptics.fire(.medium)
        withBrandAnimation(BrandMotion.morph, reduceMotion: reduceMotion) {
            surface = .chat
        }
    }

    private func askAboutSelection() {
        if let tool = explicitlySelectedTool {
            model.assistantQuery = "Tell me how \(tool.name) fits into my stack."
        } else if model.universeMode.focusedCategory != .core {
            let branch = UniverseSeed.category(model.universeMode.focusedCategory).shortName
            model.assistantQuery = "Help me choose the next \(branch) tool for my stack."
        } else {
            model.assistantQuery = "Help me choose the next tool for my stack."
        }
        showChat()
    }

    private func presentAccount() {
        BrandHaptics.fire(.medium)
        accountPresented = true
    }

    private func presentAddTool(draft: MissingToolSuggestion?) {
        BrandHaptics.fire(.medium)
        addToolDraft = draft
        addToolPresented = true
    }

    private func openToolInUniverse(_ id: String) {
        _ = model.focusTool(id)
        showUniverse()
    }

    /// §6.3: open a tool's full detail from a chat chip. Requests the detail on
    /// the model, then dives to the map — `UniverseMapView` presents the sheet
    /// once it mounts (chat and map are mutually-exclusive surfaces).
    private func openToolDetail(_ id: String) {
        guard model.requestToolDetail(id) else { return }
        showUniverse()
    }

    private var latestAddedActivity: UniverseActivity? {
        model.activityHistory.first { $0.kind == .added && $0.toolID != nil }
    }

    private func handleLatestAddedActivity() {
        guard let activity = latestAddedActivity,
              activity.id != lastHandledAddedActivityID,
              let toolID = activity.toolID,
              let tool = model.visibleAllTools.first(where: { $0.id == toolID }) else { return }
        lastHandledAddedActivityID = activity.id

        model.assistantMessages.append(
            AssistantMessage(
                role: .assistant,
                text: "Added \(tool.name) to your universe. Open the map to see where it landed, then keep adding tools to grow the branches.",
                matchIDs: [tool.id]
            )
        )

        _ = model.focusTool(tool.id)
        showUniverse()
    }
}

/// View modifier backing the chat⇄universe dive transition: scales, fades, and
/// applies an animatable blur so a receding surface softens as it leaves.
private struct DiveTransitionModifier: ViewModifier {
    let scale: CGFloat
    let opacity: Double
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: blur)
    }
}

struct RootSurfaceSwitch: View {
    let surface: RootSurface
    let toolCount: Int
    let namespace: Namespace.ID
    let onShowChat: () -> Void
    let onShowUniverse: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var badgePopped = false

    private struct SurfaceOption: Identifiable {
        let id: Int
        let title: String
        let icon: String
    }

    private let options = [
        SurfaceOption(id: 0, title: "Ask AI", icon: "text.bubble.fill"),
        SurfaceOption(id: 1, title: "Map", icon: "map.fill"),
    ]

    /// Selection derives from the surface (the source of truth); tapping a slot
    /// fires the matching route callback, which flips the surface, which morphs
    /// the single glass selection to the new slot.
    private var selectionBinding: Binding<Int> {
        Binding(
            get: { surface == .chat ? 0 : 1 },
            set: { index in index == 0 ? onShowChat() : onShowUniverse() }
        )
    }

    var body: some View {
        GlassMorphCluster(
            options: options,
            selection: selectionBinding,
            base: "RootShell.Surface",
            spacing: BrandSpacing.xs.value,
            identifier: { $0 == 0 ? "RootShell.ShowChat" : "RootShell.ShowUniverse" }
        ) { option, _ in
            HStack(spacing: BrandSpacing.s.value) {
                Image(systemName: option.icon).font(.system(size: 13, weight: .bold))
                Text(option.title).lineLimit(1)
            }
        }
        .foregroundStyle(.white.opacity(0.88))
        .scaleEffect(badgePopped ? 1.04 : 1)
        .brandAnimation(BrandMotion.pillPop, value: badgePopped)
        .brandSensoryFeedback(.increase, trigger: toolCount)
        .onChange(of: toolCount) { oldValue, newValue in
            guard !reduceMotion, RootShellMotion.badgeShouldPop(from: oldValue, to: newValue) else { return }
            badgePopped = true
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                badgePopped = false
            }
        }
    }
}

#Preview {
    RootShell()
        .environment(UniverseViewModel())
}
