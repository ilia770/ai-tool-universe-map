import SwiftUI

enum RootSurface: String, Equatable {
    case chat
    case universe
}

/// App-level shell for the chat-first IA.
///
/// The universe renderer stays intact; this shell only changes which surface is
/// primary at launch and owns sheets needed from the chat surface.
struct RootShell: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var surfaceNamespace
    @State private var surface: RootSurface = .chat
    @State private var accountPresented = false
    @State private var addToolPresented = false
    @State private var addToolDraft: MissingToolSuggestion?
    @State private var lastHandledAddedActivityID: UUID?

    var body: some View {
        ZStack {
            switch surface {
            case .chat:
                ChatScreen(
                    onOpenSettings: presentAccount,
                    onAddTool: { presentAddTool(draft: nil) },
                    onAddSuggestedTool: { presentAddTool(draft: $0) },
                    onOpenToolInUniverse: openToolInUniverse
                )
                .transition(.opacity)

            case .universe:
                UniverseScreen()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surface == .chat ? ChatTheme.background : Color.black)
        .safeAreaInset(edge: .top, spacing: 0) {
            surfaceSwitchChrome
        }
        .preferredColorScheme(.dark)
        .brandAnimation(BrandMotion.morph, value: surface)
        .onAppear {
            BrandHaptics.isEnabled = model.hapticsEnabled
            BrandHaptics.prepare(.light, .medium, .heavy, .success)
            lastHandledAddedActivityID = latestAddedActivity?.id
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

    private var surfaceSwitchChrome: some View {
        HStack {
            Spacer()
            RootSurfaceSwitch(
                surface: surface,
                toolCount: model.visibleAllTools.count,
                namespace: surfaceNamespace,
                selectedToolName: explicitlySelectedTool?.name,
                onShowChat: askAboutSelection,
                onShowUniverse: showUniverse
            )
            Spacer()
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .allowsHitTesting(true)
    }

    private var explicitlySelectedTool: Tool? {
        guard let toolID = model.universeMode.selectedToolID else { return nil }
        return model.visibleAllTools.first { $0.id == toolID }
    }

    private func showUniverse() {
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
        guard model.visibleAllTools.count >= 3 else { return }
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

        let toolsUntilMap = max(0, 3 - model.visibleAllTools.count)
        let text = if toolsUntilMap == 0 {
            "Added \(tool.name) to your universe. Use the map card below to see where it landed."
        } else {
            "Added \(tool.name) to your universe. Add \(toolsUntilMap) more \(toolsUntilMap == 1 ? "tool" : "tools") to unlock the map."
        }

        model.assistantMessages.append(
            AssistantMessage(
                role: .assistant,
                text: text,
                matchIDs: toolsUntilMap == 0 ? [tool.id] : []
            )
        )

        if toolsUntilMap == 0 {
            _ = model.focusTool(tool.id)
            showUniverse()
        }
    }
}

private struct RootSurfaceSwitch: View {
    let surface: RootSurface
    let toolCount: Int
    let namespace: Namespace.ID
    let selectedToolName: String?
    let onShowChat: () -> Void
    let onShowUniverse: () -> Void

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                switchContent
                    .glassEffectID("root-surface-switch", in: namespace)
            }
        } else {
            switchContent
        }
    }

    private var switchContent: some View {
        HStack(spacing: 8) {
            if surface == .universe {
                Button(action: onShowChat) {
                    Label("Ask about this", systemImage: "text.bubble.fill")
                        .font(.system(.footnote, weight: .bold))
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
                .accessibilityLabel(selectedToolName.map { "Ask about \($0)" } ?? "Ask about this")
                .accessibilityIdentifier("RootShell.ShowChat")
            }

            Button(action: onShowUniverse) {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Map")
                        .font(.system(.footnote, weight: .bold))
                    Text("\(toolCount)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black.opacity(0.82))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(BrandColor.core, in: Capsule())
                        .contentTransition(.numericText(value: Double(toolCount)))
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
            }
            .disabled(toolCount < 3)
            .opacity(toolCount >= 3 ? 1 : 0.56)
            .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
            .accessibilityLabel(toolCount >= 3 ? "Open universe map, \(toolCount) tools" : "Universe map locked until three tools, \(toolCount) tools")
            .accessibilityIdentifier("RootShell.ShowUniverse")
        }
        .foregroundStyle(.white.opacity(0.88))
        .glassSurface(in: Capsule(), tint: BrandColor.core.opacity(0.26), interactive: true)
        .brandAnimation(BrandMotion.pillPop, value: toolCount)
    }
}

#Preview {
    RootShell()
        .environment(UniverseViewModel())
}
