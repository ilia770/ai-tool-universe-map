import SwiftUI

/// App entry point.
///
/// Phase 2: injects the single `UniverseViewModel` via environment per
/// the Phase 2 decision log.
@main
struct MyAIMapApp: App {
    @State private var model = UniverseViewModel()

    var body: some Scene {
        WindowGroup {
            RootShell()
                .environment(model)
                .preferredColorScheme(.dark)
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("-uitestSampleUniverse"), model.isUniverseEmpty {
                        _ = model.loadSampleUniverse()
                    }
                    if ProcessInfo.processInfo.arguments.contains("-uitestSeedChat") {
                        seedChatForVisualQA()
                    }
                }
        }
    }

    /// Seeds a realistic conversation so the chat can be screenshotted for
    /// visual QA. Guarded behind `-uitestSeedChat`; production is unaffected.
    private func seedChatForVisualQA() {
        // Load sample tools so the matched-tool chip (`figma`) resolves.
        if model.isUniverseEmpty {
            _ = model.loadSampleUniverse()
        }
        guard model.assistantMessages.isEmpty else { return }
        model.assistantMessages = [
            AssistantMessage(role: .user, text: "What should I use for design?"),
            AssistantMessage(
                role: .user,
                text: "I'm building a mobile app from scratch and need a full workflow — design, a backend with auth and a database, and product analytics so I can see what users actually do. Where should I start?"
            ),
            AssistantMessage(
                role: .assistant,
                text: """
                Start with **Figma** for the interface, then layer in the rest as you go. A solid first stack looks like:

                - **Design** the screens and a clickable prototype first
                - **Backend** with hosted auth and a database so you can ship fast
                - **Analytics** wired in early to learn from real usage
                """,
                matchIDs: ["figma"],
                missingToolSuggestions: [
                    MissingToolSuggestion(
                        name: "Supabase",
                        category: .infrastructure,
                        reason: "Hosted Postgres, auth, and storage — a fast backend foundation."
                    )
                ]
            )
        ]
    }
}
