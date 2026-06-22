import SwiftUI

enum ChatTheme {
    static let background = Color(red: 11.0 / 255, green: 13.0 / 255, blue: 18.0 / 255)
    static let surface = Color(red: 19.0 / 255, green: 22.0 / 255, blue: 29.0 / 255)
    static let surfaceRaised = Color(red: 25.0 / 255, green: 29.0 / 255, blue: 38.0 / 255)
    static let text = Color.white.opacity(0.92)
    static let secondaryText = Color.white.opacity(0.62)
}

struct ChatScreen: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onShowUniverse: () -> Void
    let onOpenSettings: () -> Void
    let onAddTool: () -> Void
    let onAddSuggestedTool: (MissingToolSuggestion) -> Void
    let onOpenToolInUniverse: (String) -> Void

    private var toolCount: Int {
        model.visibleAllTools.count
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatTopBar(
                toolCount: toolCount,
                onShowUniverse: onShowUniverse,
                onOpenSettings: onOpenSettings
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            transcript

            composer
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChatTheme.background.ignoresSafeArea())
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if model.assistantMessages.isEmpty {
                        ChatStarterPanel(onSendPrompt: sendStarterPrompt)
                            .padding(.top, 52)
                    } else {
                        ForEach(model.assistantMessages) { message in
                            ChatMessageTurn(
                                message: message,
                                matches: tools(for: message.matchIDs),
                                onOpenTool: onOpenToolInUniverse,
                                onAddSuggestedTool: onAddSuggestedTool
                            )
                            .id(message.id)
                        }
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.assistantMessages.count) { _, _ in
                guard let last = model.assistantMessages.last else { return }
                withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        SearchDock(
            isChatOpen: false,
            onAddTool: onAddTool,
            onAddSuggestedTool: onAddSuggestedTool,
            onToolSelect: onOpenToolInUniverse,
            onOpenToolDetail: onOpenToolInUniverse,
            onChatActivityChange: nil
        )
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    private func tools(for ids: [String]) -> [Tool] {
        ids.compactMap { id in model.visibleAllTools.first { $0.id == id } }
    }

    private func sendStarterPrompt(_ prompt: String) {
        model.assistantQuery = prompt
        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
            model.askAssistant()
        }
    }
}

private struct ChatTopBar: View {
    let toolCount: Int
    let onShowUniverse: () -> Void
    let onOpenSettings: () -> Void

    private var canOpenUniverse: Bool {
        toolCount >= 3
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Universe")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(ChatTheme.text)
                Text("Ask, choose, and grow your map")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(ChatTheme.secondaryText)
            }

            Spacer()

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
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .glassSurface(in: Capsule(), tint: BrandColor.core.opacity(0.26), interactive: true)
            }
            .disabled(!canOpenUniverse)
            .opacity(canOpenUniverse ? 1 : 0.56)
            .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
            .accessibilityLabel(canOpenUniverse ? "Open universe map, \(toolCount) tools" : "Universe map locked until three tools, \(toolCount) tools")
            .accessibilityIdentifier("RootShell.ShowUniverse")

            Button(action: onOpenSettings) {
                UserAvatarImage(size: 40, tint: BrandColor.core)
            }
            .buttonStyle(BouncyIconButtonStyle())
            .accessibilityLabel("Account")
            .accessibilityIdentifier("ChatScreen.Account")
        }
    }
}

private struct ChatStarterPanel: View {
    let onSendPrompt: (String) -> Void

    private let prompts = [
        StarterPrompt(title: "Design an app", query: "What tool should I use for app design?"),
        StarterPrompt(title: "Build an MVP", query: "I need a workflow to build and launch an MVP"),
        StarterPrompt(title: "Track growth", query: "Looking for analytics tools for a new product"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(BrandColor.core.opacity(0.16))
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(BrandColor.core)
                }
                .frame(width: 62, height: 62)

                Text("What are you trying to build?")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(ChatTheme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Ask for a workflow or a tool recommendation. Your answers can become a living map of the stack.")
                    .font(.system(.body))
                    .lineSpacing(4)
                    .foregroundStyle(ChatTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                ForEach(prompts) { prompt in
                    Button {
                        onSendPrompt(prompt.query)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                            Text(prompt.title)
                                .font(.system(.subheadline, weight: .semibold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(ChatTheme.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(ChatTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(BrandColor.stroke, lineWidth: 0.5)
                        }
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: .light))
                }
            }
        }
    }
}

private struct StarterPrompt: Identifiable {
    let title: String
    let query: String

    var id: String { query }
}

private struct ChatMessageTurn: View {
    let message: AssistantMessage
    let matches: [Tool]
    let onOpenTool: (String) -> Void
    let onAddSuggestedTool: (MissingToolSuggestion) -> Void

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser {
                Spacer(minLength: 42)
                userBubble
            } else {
                assistantTurn
                Spacer(minLength: 28)
            }
        }
    }

    private var userBubble: some View {
        ChatMarkdownText(text: message.text, font: .system(.body, weight: .medium), color: .white.opacity(0.92))
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .frame(maxWidth: 560, alignment: .leading)
            .background(BrandColor.core.opacity(0.24), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 0.5)
            }
    }

    private var assistantTurn: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(BrandColor.core.opacity(0.15))
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BrandColor.core)
            }
            .frame(width: 30, height: 30)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 14) {
                ChatMarkdownText(text: assistantProse(from: message.text), font: .system(.body), color: ChatTheme.text)
                    .lineSpacing(5)

                if !matches.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(matches.prefix(3)) { tool in
                            ChatToolCard(tool: tool) {
                                onOpenTool(tool.id)
                            }
                        }
                    }
                }

                if !message.missingToolSuggestions.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(message.missingToolSuggestions.prefix(3)) { suggestion in
                            ChatMissingToolCard(suggestion: suggestion) {
                                onAddSuggestedTool(suggestion)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    private func assistantProse(from text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("|") else { return true }
                return false
            }
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.hasPrefix("**Next:**") && !trimmed.hasPrefix("Next:")
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ChatToolCard: View {
    let tool: Tool
    let onOpen: () -> Void

    private var category: ToolCategory {
        UniverseSeed.category(tool.category)
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 12) {
                ToolLogoView(tool: tool, accent: category.color.swiftUIColor, size: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.name)
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(ChatTheme.text)
                        .lineLimit(1)
                    Text(tool.summary)
                        .font(.system(.subheadline))
                        .foregroundStyle(ChatTheme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "map")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(category.color.swiftUIColor)
            }
            .padding(12)
            .background(ChatTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(category.color.swiftUIColor.opacity(0.22), lineWidth: 0.8)
            }
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98, haptic: .light))
        .accessibilityLabel("Open \(tool.name) on map")
    }
}

private struct ChatMissingToolCard: View {
    let suggestion: MissingToolSuggestion
    let onAdd: () -> Void

    private var category: ToolCategory {
        UniverseSeed.category(suggestion.category)
    }

    var body: some View {
        Button(action: onAdd) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(category.color.swiftUIColor.opacity(0.62), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(category.color.swiftUIColor)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Add \(suggestion.name)")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(ChatTheme.text)
                        .lineLimit(1)
                    Text(suggestion.reason)
                        .font(.system(.subheadline))
                        .foregroundStyle(ChatTheme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(category.color.swiftUIColor)
            }
            .padding(12)
            .background(category.color.swiftUIColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(category.color.swiftUIColor.opacity(0.24), lineWidth: 0.8)
            }
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.98, haptic: .light))
        .accessibilityLabel("Add \(suggestion.name)")
    }
}

private struct ChatMarkdownText: View {
    let text: String
    let font: Font
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var lines: [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    @ViewBuilder
    private func lineView(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Color.clear.frame(height: 4)
        } else if trimmed.hasPrefix("- ") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                    .font(.system(.body, weight: .bold))
                markdownText(String(trimmed.dropFirst(2)))
                    .font(font)
            }
        } else {
            markdownText(line)
                .font(font)
        }
    }

    private func markdownText(_ markdown: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        ) {
            return Text(attributed)
        }
        return Text(markdown)
    }
}

#Preview {
    ChatScreen(
        onShowUniverse: {},
        onOpenSettings: {},
        onAddTool: {},
        onAddSuggestedTool: { _ in },
        onOpenToolInUniverse: { _ in }
    )
    .environment(UniverseViewModel())
}
