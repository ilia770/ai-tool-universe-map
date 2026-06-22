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
    @State private var surface: RootSurface = .chat
    @State private var accountPresented = false
    @State private var addToolPresented = false
    @State private var addToolDraft: MissingToolSuggestion?

    var body: some View {
        ZStack {
            switch surface {
            case .chat:
                ChatScreen(
                    onShowUniverse: showUniverse,
                    onOpenSettings: presentAccount,
                    onAddTool: { presentAddTool(draft: nil) },
                    onAddSuggestedTool: { presentAddTool(draft: $0) },
                    onOpenToolInUniverse: openToolInUniverse
                )
                .transition(.opacity.combined(with: .scale(scale: 0.985)))

            case .universe:
                UniverseScreen()
                    .transition(.opacity.combined(with: .scale(scale: 1.015)))

                universeReturnChrome
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surface == .chat ? ChatTheme.background : Color.black)
        .preferredColorScheme(.dark)
        .brandAnimation(BrandMotion.morph, value: surface)
        .onAppear {
            BrandHaptics.isEnabled = model.hapticsEnabled
            BrandHaptics.prepare(.light, .medium, .heavy, .success)
        }
        .onChange(of: model.hapticsEnabled) { _, isEnabled in
            BrandHaptics.isEnabled = isEnabled
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

    private var universeReturnChrome: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: showChat) {
                    Label("Chat", systemImage: "text.bubble.fill")
                        .font(.system(.footnote, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassSurface(
                            in: Capsule(),
                            tint: BrandColor.core.opacity(0.32),
                            interactive: true
                        )
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
                .accessibilityLabel("Show chat")
                .accessibilityIdentifier("RootShell.ShowChat")
                Spacer()
            }
            .padding(.top, 14)

            Spacer()
        }
        .allowsHitTesting(surface == .universe)
    }

    private func showUniverse() {
        BrandHaptics.fire(.medium)
        withBrandAnimation(BrandMotion.morph, reduceMotion: reduceMotion) {
            surface = .universe
        }
    }

    private func showChat() {
        BrandHaptics.fire(.medium)
        withBrandAnimation(BrandMotion.morph, reduceMotion: reduceMotion) {
            surface = .chat
        }
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
}

#Preview {
    RootShell()
        .environment(UniverseViewModel())
}
