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

/// App-level shell for the chat-first IA.
///
/// The universe renderer stays intact; this shell only changes which surface is
/// primary at launch and owns sheets needed from the chat surface.
struct RootShell: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var surfaceNamespace
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

    var body: some View {
        ZStack {
            switch surface {
            case .chat:
                ChatScreen(
                    onOpenSettings: presentAccount,
                    onAddTool: { presentAddTool(draft: nil) },
                    onAddSuggestedTool: { presentAddTool(draft: $0) },
                    onOpenToolInUniverse: openToolInUniverse,
                    onBackToMap: { showUniverse(resetSelection: true) },
                    onCardLand: flyCardToMap
                )
                .transition(diveTransition)

            case .universe:
                UniverseScreen()
                    .transition(diveTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surface == .chat ? ChatTheme.background : Color.black)
        .coordinateSpace(name: RootShellCoordinateSpace.name)
        .overlay { ghostFlightOverlay }
        .overlay { onboardingOverlay }
        .onPreferenceChange(MapPillFramePreferenceKey.self) { frame in
            mapPillFrame = frame
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
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(42)
        }
        .sheet(isPresented: $addToolPresented) {
            AddToolSheet(draft: addToolDraft)
                .environment(model)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(42)
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
                selectedToolName: explicitlySelectedTool?.name,
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

private struct RootSurfaceSwitch: View {
    let surface: RootSurface
    let toolCount: Int
    let namespace: Namespace.ID
    let selectedToolName: String?
    let onShowChat: () -> Void
    let onShowUniverse: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var badgePopped = false

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 16) {
                switchContent
            }
        } else {
            switchContent
        }
    }

    private var switchContent: some View {
        HStack(spacing: 9) {
            if surface == .universe {
                rootRouteButton(
                    title: "Ask AI",
                    systemImage: "text.bubble.fill",
                    morphID: "RootChrome.askRoute",
                    selected: false,
                    action: onShowChat
                )
                .accessibilityLabel(selectedToolName.map { "Ask about \($0)" } ?? "Ask about this")
                .accessibilityIdentifier("RootShell.ShowChat")

                if let selectedToolName {
                    rootContextChip(selectedToolName)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }

            rootRouteButton(
                title: "Map",
                systemImage: "map.fill",
                morphID: "RootChrome.mapRoute",
                selected: surface == .universe,
                action: onShowUniverse,
                accessory: {
                    Text("\(toolCount)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.white.opacity(surface == .universe ? 0.16 : 0.10), in: Capsule())
                        .contentTransition(.numericText(value: Double(toolCount)))
                        .scaleEffect(badgePopped ? 1.18 : 1)
                }
            )
            // Always enabled: an empty/low-tool map is a valid destination
            // (it shows the empty-state card), so the Map pill is never a
            // dead-end that traps a new user in chat.
            .accessibilityLabel("Open universe map, \(toolCount) tools")
            .accessibilityIdentifier("RootShell.ShowUniverse")
        }
        .foregroundStyle(.white.opacity(0.88))
        .brandAnimation(BrandMotion.pillPop, value: badgePopped)
        .brandAnimation(BrandMotion.morph, value: surface)
        .brandAnimation(BrandMotion.morph, value: selectedToolName)
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

    private func rootRouteButton<Accessory: View>(
        title: String,
        systemImage: String,
        morphID: String,
        selected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(.footnote, weight: .bold))
                    .lineLimit(1)
                accessory()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if selected {
                    Capsule().fill(.white.opacity(0.11))
                }
            }
            .glassSurface(in: Capsule(), tint: selected ? .white.opacity(0.10) : nil, interactive: true)
            .navigationGlassMorphID(morphID, in: namespace)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func rootRouteButton(
        title: String,
        systemImage: String,
        morphID: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        rootRouteButton(
            title: title,
            systemImage: systemImage,
            morphID: morphID,
            selected: selected,
            action: action
        ) {
            EmptyView()
        }
    }

    private func rootContextChip(_ title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.white.opacity(0.72))
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(.caption, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.78))
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: 150)
        .glassSurface(in: Capsule(), tint: .white.opacity(0.06), interactive: false)
        .navigationGlassMorphID("RootChrome.context", in: namespace)
        .accessibilityLabel("Selected \(title)")
    }
}

#Preview {
    RootShell()
        .environment(UniverseViewModel())
}
