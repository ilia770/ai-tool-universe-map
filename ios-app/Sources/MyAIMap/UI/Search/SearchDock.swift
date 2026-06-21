import SwiftUI
import UIKit

/// Bottom assistant dock. Collapsed it is a ChatGPT-like input plus a
/// right-side action button; once the user asks something, it grows a compact
/// glass transcript. Results are clickable and missing tools never get
/// fabricated: the assistant asks for a URL or attachment instead.
/// Command-K focuses the field on iPad / hardware keyboards.
struct SearchDock: View {
    @Environment(UniverseViewModel.self) private var model
    @FocusState private var fieldFocused: Bool
    @State private var selectedAttachment: AssistantAttachmentKind?
    @State private var attachmentMenuOpen = false
    @State private var conversationCollapsed = false

    let onAddTool: () -> Void
    let onAddSuggestedTool: ((MissingToolSuggestion) -> Void)?
    let onToolSelect: ((String) -> Void)?
    let onOpenToolDetail: ((String) -> Void)?
    let onChatActivityChange: ((Bool) -> Void)?

    init(
        onAddTool: @escaping () -> Void = {},
        onAddSuggestedTool: ((MissingToolSuggestion) -> Void)? = nil,
        onToolSelect: ((String) -> Void)? = nil,
        onOpenToolDetail: ((String) -> Void)? = nil,
        onChatActivityChange: ((Bool) -> Void)? = nil
    ) {
        self.onAddTool = onAddTool
        self.onAddSuggestedTool = onAddSuggestedTool
        self.onToolSelect = onToolSelect
        self.onOpenToolDetail = onOpenToolDetail
        self.onChatActivityChange = onChatActivityChange
    }

    private var previewResults: [Tool] {
        model.assistantPreviewResults
    }

    private var hasQuery: Bool {
        !model.assistantQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Send is enabled when there is text OR an attachment.
    private var canSend: Bool {
        ComposerLogic.canSend(hasText: hasQuery, hasAttachment: selectedAttachment != nil)
    }

    private var showsSendButton: Bool {
        ComposerLogic.showsSendButton(
            isFocused: fieldFocused,
            hasText: hasQuery,
            hasAttachment: selectedAttachment != nil
        )
    }

    private var hasConversationContent: Bool {
        !model.assistantMessages.isEmpty || hasQuery || selectedAttachment != nil
    }

    private var showsConversation: Bool {
        !conversationCollapsed && (!model.assistantMessages.isEmpty || (fieldFocused && hasQuery))
    }

    private var showsCollapsedConversationPill: Bool {
        conversationCollapsed && hasConversationContent
    }

    private var chatIsActive: Bool {
        ComposerLogic.keepsChatActive(
            isFocused: fieldFocused,
            showsConversation: showsConversation,
            isCollapsedWithContent: showsCollapsedConversationPill,
            attachmentMenuOpen: attachmentMenuOpen,
            hasAttachment: selectedAttachment != nil
        )
    }

    private var userMessageMaxWidth: CGFloat {
        ComposerLogic.userBubbleMaxWidth(availableWidth: UIScreen.main.bounds.width - 44)
    }

    private var assistantMessageMaxWidth: CGFloat {
        min(420, (UIScreen.main.bounds.width - 44) * ComposerLogic.assistantMessageMaxWidthRatio)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsConversation {
                conversationPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showsCollapsedConversationPill {
                collapsedConversationPill
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if attachmentMenuOpen {
                attachmentMenuPopover
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            composerRow
        }
        .frame(maxWidth: .infinity)
        .brandAnimation(BrandMotion.nudge, value: showsConversation)
        .brandAnimation(BrandMotion.nudge, value: showsCollapsedConversationPill)
        .brandAnimation(BrandMotion.nudge, value: attachmentMenuOpen)
        .brandAnimation(BrandMotion.nudge, value: previewResults.map(\.id))
        .brandAnimation(BrandMotion.nudge, value: fieldFocused)
        .brandAnimation(BrandMotion.nudge, value: selectedAttachment)
        .onAppear {
            onChatActivityChange?(chatIsActive)
        }
        .onChange(of: chatIsActive) { _, isActive in
            onChatActivityChange?(isActive)
        }
        .background {
            Button("Focus search") { fieldFocused = true }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var composerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            composer
            trailingActionButton
        }
        .frame(maxWidth: .infinity)
    }

    private var composer: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            attachmentMenu

            TextField("Ask AI Universe", text: $model.assistantQuery)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(.white)
                .tint(model.selectedCategoryModel.color.swiftUIColor)
                .focused($fieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(submit)
                .onChange(of: fieldFocused) { _, focused in
                    if focused {
                        BrandHaptics.fire(.light)
                        conversationCollapsed = false
                    } else {
                        attachmentMenuOpen = false
                    }
                }

            if let selectedAttachment {
                attachmentPill(selectedAttachment)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(5)
        .background(.black.opacity(0.12), in: Capsule())
        .liquidGlass(
            in: Capsule(),
            tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.5),
            strokeStrength: 0.08
        )
        .shadow(color: .black.opacity(0.26), radius: 14, x: 0, y: 8)
    }

    private var attachmentMenu: some View {
        Button {
            BrandHaptics.fire(.light)
            fieldFocused = true
            withAnimation(BrandMotion.nudge) {
                attachmentMenuOpen.toggle()
            }
        } label: {
            Image(systemName: ComposerLogic.attachmentTriggerIcon(hasAttachment: selectedAttachment != nil))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selectedAttachment == nil ? .white.opacity(0.74) : model.selectedCategoryModel.color.swiftUIColor)
                .frame(width: 36, height: 36)
                .liquidGlass(
                    in: Circle(),
                    tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.35),
                    strokeStrength: 0.07
                )
        }
        .buttonStyle(BouncyIconButtonStyle())
        .accessibilityLabel("Attach photo or file")
    }

    private var attachmentMenuPopover: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(AssistantAttachmentKind.allCases) { kind in
                    attachmentMenuItem(kind)
                }

                if ComposerLogic.showsRemoveAttachment(hasAttachment: selectedAttachment != nil) {
                    Divider()
                        .overlay(.white.opacity(0.12))
                    Button {
                        BrandHaptics.fire(.light)
                        selectedAttachment = nil
                        attachmentMenuOpen = false
                    } label: {
                        Label("Remove attachment", systemImage: "xmark.circle")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil, pressedOpacity: 0.9))
                    .accessibilityLabel("Remove attachment")
                }
            }
            .padding(7)
            .frame(width: 164)
            .background(
                .black.opacity(0.30),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 20, style: .continuous),
                tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.34),
                strokeStrength: 0.08
            )
            .shadow(color: .black.opacity(0.34), radius: 16, x: 0, y: 8)

            Spacer(minLength: 0)
        }
        .padding(.leading, 2)
        .padding(.bottom, -2)
    }

    private func attachmentMenuItem(_ kind: AssistantAttachmentKind) -> some View {
        Button {
            BrandHaptics.fire(.light)
            selectedAttachment = kind
            attachmentMenuOpen = false
            fieldFocused = true
        } label: {
            Label(kind.title, systemImage: kind.icon)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(.white.opacity(selectedAttachment == kind ? 0.12 : 0.055), in: Capsule())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil, pressedOpacity: 0.9))
        .accessibilityLabel(kind.title)
    }

    private var trailingActionButton: some View {
        Group {
            if showsSendButton {
                Button {
                    submit()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(canSend ? .black.opacity(0.86) : .white.opacity(0.34))
                        .frame(width: 44, height: 44)
                        .background(canSend ? model.selectedCategoryModel.color.swiftUIColor : .white.opacity(0.08), in: Circle())
                        .overlay {
                            Circle().stroke(.white.opacity(canSend ? 0.18 : 0.10), lineWidth: 1)
                        }
                }
                .buttonStyle(BouncyIconButtonStyle())
                .disabled(!canSend)
                .accessibilityLabel(canSend ? "Send" : "Send unavailable")
            } else {
                Button {
                    onAddTool()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black.opacity(0.82))
                        .frame(width: 44, height: 44)
                        .background(model.selectedCategoryModel.color.swiftUIColor, in: Circle())
                        .shadow(color: model.selectedCategoryModel.color.swiftUIColor.opacity(0.32), radius: 12, x: 0, y: 7)
                }
                .buttonStyle(BouncyIconButtonStyle())
                .accessibilityLabel("Add tool")
            }
        }
        .frame(width: 44, height: 44)
    }

    private func attachmentPill(_ kind: AssistantAttachmentKind) -> some View {
        Button {
            BrandHaptics.fire(.light)
            selectedAttachment = nil
            attachmentMenuOpen = false
        } label: {
            HStack(spacing: 5) {
                Image(systemName: kind.icon)
                    .font(.system(size: 11, weight: .bold))
                Text(kind.shortTitle)
                    .font(.system(.caption2, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .liquidGlass(
                in: Capsule(),
                tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.45),
                strokeStrength: 0.06
            )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil))
        .accessibilityLabel("Remove \(kind.title)")
    }

    private var conversationPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    conversationHeader

                    if fieldFocused && hasQuery {
                        previewBlock
                    }

                    ForEach(model.assistantMessages) { message in
                        messageRow(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: 284)
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.assistantMessages.count) { _, _ in
                guard let last = model.assistantMessages.last else { return }
                withAnimation(BrandMotion.nudge) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .background(
            .black.opacity(0.18),
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
        )
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous),
            tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.38),
            strokeStrength: 0.08
        )
        .shadow(color: .black.opacity(0.32), radius: 16, x: 0, y: 8)
    }

    private var collapsedConversationPill: some View {
        Button {
            BrandHaptics.fire(.light)
            withAnimation(BrandMotion.nudge) {
                conversationCollapsed = false
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Show chat")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.78))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: 152)
            .liquidGlass(
                in: Capsule(),
                tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.32),
                strokeStrength: 0.06
            )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil, pressedOpacity: 0.9))
    }

    private var conversationHeader: some View {
        HStack(spacing: 8) {
            Label("AI Chat", systemImage: "sparkles")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.76))

            Spacer()

            Button {
                BrandHaptics.fire(.light)
                withAnimation(BrandMotion.nudge) {
                    conversationCollapsed = true
                    fieldFocused = false
                    attachmentMenuOpen = false
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 30, height: 30)
                    .liquidGlass(
                        in: Circle(),
                        tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.32),
                        strokeStrength: 0.06
                    )
            }
            .buttonStyle(BouncyIconButtonStyle(pressedScale: 0.9))
            .accessibilityLabel("Collapse chat")
        }
        .padding(.leading, 2)
    }

    private var previewBlock: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            Text(previewResults.isEmpty ? "No exact match yet" : "Matches")
                .font(.system(.caption, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(BrandColor.textMuted)

            if previewResults.isEmpty {
                Text("Send the question. If the service is missing, I will ask for its website instead of guessing.")
                    .font(.system(.footnote))
                    .foregroundStyle(BrandColor.textMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, BrandSpacing.s.value)
                    .padding(.vertical, BrandSpacing.s.value)
            } else {
                ForEach(previewResults.prefix(4)) { tool in
                    resultRow(tool)
                }
            }
        }
    }

    private func messageRow(_ message: AssistantMessage) -> some View {
        let isUser = message.role == .user
        let matches = message.matchIDs.compactMap { id in
            model.visibleAllTools.first { $0.id == id }
        }
        return HStack(alignment: .top, spacing: 0) {
            if isUser {
                Spacer(minLength: max(24, UIScreen.main.bounds.width * 0.16))
                userBubble(message.text)
            } else {
                assistantResponse(message, matches: matches)
                Spacer(minLength: max(20, UIScreen.main.bounds.width * 0.12))
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func userBubble(_ text: String) -> some View {
        ViewThatFits(in: .horizontal) {
            userBubbleContent(text)
                .fixedSize(horizontal: true, vertical: false)
            userBubbleContent(text)
                .frame(maxWidth: userMessageMaxWidth, alignment: .trailing)
        }
        .frame(maxWidth: userMessageMaxWidth, alignment: .trailing)
    }

    private func userBubbleContent(_ text: String) -> some View {
        MarkdownMessageText(text: text, fontSize: 15, weight: .medium, color: .white.opacity(0.92))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 19, style: .continuous),
                tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.62),
                strokeStrength: 0.08
            )
    }

    private func assistantResponse(_ message: AssistantMessage, matches: [Tool]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let prose = assistantProse(from: message.text)
            if !prose.isEmpty {
                MarkdownMessageText(text: prose, fontSize: 15, weight: .regular, color: .white.opacity(0.88))
            }

            if !matches.isEmpty {
                toolSummaryTable(matches)
            }

            if !matches.isEmpty || !message.missingToolSuggestions.isEmpty {
                actionStrip(for: matches, missingSuggestions: message.missingToolSuggestions)
                nextHint("Next: open one, or ask me to compare them by price, stage, and daily use.")
            } else if needsAccessActions(message) {
                // Single home for Attach / Add-tool is the composer below. The
                // message only guides the user there — rendering duplicate
                // buttons here would show the same action twice. (Spec §4.)
                nextHint("Next: paste the URL, attach files (paperclip), or add it manually (+).")
            }
        }
        .frame(maxWidth: assistantMessageMaxWidth, alignment: .leading)
        .padding(.vertical, 2)
        .shadow(color: .black.opacity(0.58), radius: 8, x: 0, y: 2)
    }

    private func toolSummaryTable(_ tools: [Tool]) -> some View {
        VStack(spacing: 0) {
            tableHeader
            ForEach(tools) { tool in
                tableRow(tool)
            }
        }
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 8) {
            Text("Tool")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Branch")
                .frame(width: 58, alignment: .leading)
            Text("Price")
                .frame(width: 82, alignment: .leading)
        }
        .font(.system(.caption2, weight: .bold))
        .foregroundStyle(.white.opacity(0.58))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.045))
    }

    private func tableRow(_ tool: Tool) -> some View {
        let category = UniverseSeed.category(tool.category)
        let info = ToolKnowledgeBook.knowledge(for: tool)
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Text(info.useCase)
                    .font(.system(.caption2))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(category.shortName)
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(category.color.swiftUIColor.opacity(0.95))
                .frame(width: 58, alignment: .leading)

            Text(info.pricing)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(2)
                .frame(width: 82, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.045))
    }

    private func actionStrip(for tools: [Tool], missingSuggestions: [MissingToolSuggestion]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: BrandSpacing.s.value) {
                ForEach(tools) { tool in
                    toolAccessButton(tool)
                        .id(tool.id)
                }
                ForEach(missingSuggestions) { suggestion in
                    missingToolButton(suggestion)
                        .id("missing-\(suggestion.id)")
                }
            }
            .scrollTargetLayout()
        }
        .scrollClipDisabled()
        .scrollTargetBehavior(.viewAligned)
        .scrollBounceBehavior(.basedOnSize)
        .contentMargins(.horizontal, 2, for: .scrollContent)
    }

    private func nextHint(_ text: String) -> some View {
        Text(text)
            .font(.system(.footnote, weight: .medium))
            .foregroundStyle(.white.opacity(0.58))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func toolAccessButton(_ tool: Tool) -> some View {
        let category = UniverseSeed.category(tool.category)
        return Button {
            openDetail(tool)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(tool.name)
                    .font(.system(.footnote, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .liquidGlass(
                in: Capsule(),
                tint: category.color.swiftUIColor.opacity(0.55),
                strokeStrength: 0.08
            )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil))
    }

    private func missingToolButton(_ suggestion: MissingToolSuggestion) -> some View {
        let category = UniverseSeed.category(suggestion.category)
        return Button {
            BrandHaptics.fire(.light)
            withAnimation(BrandMotion.flow) {
                if let onAddSuggestedTool {
                    onAddSuggestedTool(suggestion)
                } else {
                    onAddTool()
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Add \(suggestion.name)")
                        .font(.system(.footnote, weight: .semibold))
                        .lineLimit(1)
                    Text(category.shortName)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .liquidGlass(
                in: Capsule(),
                tint: category.color.swiftUIColor.opacity(0.42),
                strokeStrength: 0.08
            )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil))
        .accessibilityLabel("Add \(suggestion.name)")
        .accessibilityHint(suggestion.reason)
    }

    private func needsAccessActions(_ message: AssistantMessage) -> Bool {
        let text = message.text.lowercased()
        return text.contains("website") || text.contains("product page") || text.contains("service")
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

    private func resultRow(_ tool: Tool) -> some View {
        let category = UniverseSeed.category(tool.category)
        return Button {
            select(tool)
        } label: {
            HStack(spacing: BrandSpacing.s.value) {
                Circle()
                    .fill(category.color.swiftUIColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: category.color.swiftUIColor.opacity(0.6), radius: 3)
                Text(tool.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: BrandSpacing.s.value)
                Text(category.shortName)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .contentShape(RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.9))
    }

    // MARK: - Actions

    private func select(_ tool: Tool) {
        BrandHaptics.fire(.light)
        withAnimation(BrandMotion.flow) {
            if let onToolSelect {
                onToolSelect(tool.id)
            } else {
                _ = model.focusTool(tool.id)
            }
        }
        clearComposer()
    }

    private func openDetail(_ tool: Tool) {
        BrandHaptics.fire(.light)
        withAnimation(BrandMotion.flow) {
            if let onOpenToolDetail {
                onOpenToolDetail(tool.id)
            } else if let onToolSelect {
                onToolSelect(tool.id)
            } else {
                _ = model.focusTool(tool.id)
            }
        }
        clearComposer()
    }

    private func submit() {
        guard let outgoingText = ComposerLogic.outgoingMessageText(
            query: model.assistantQuery,
            attachmentTitle: selectedAttachment?.messageTitle
        ) else { return }
        BrandHaptics.fire(.light)
        conversationCollapsed = false
        attachmentMenuOpen = false
        model.assistantQuery = outgoingText
        withAnimation(BrandMotion.flow) { model.askAssistant() }
        selectedAttachment = nil
        fieldFocused = false
    }

    private func clearComposer() {
        model.assistantQuery = ""
        selectedAttachment = nil
        fieldFocused = false
    }
}

private enum AssistantAttachmentKind: CaseIterable, Identifiable, Equatable {
    case photo
    case files

    var id: String { title }

    var title: String {
        switch self {
        case .photo: return "Photo"
        case .files: return "Files"
        }
    }

    var shortTitle: String {
        switch self {
        case .photo: return "Photo"
        case .files: return "File"
        }
    }

    var messageTitle: String {
        switch self {
        case .photo: return "photo"
        case .files: return "file"
        }
    }

    var icon: String {
        switch self {
        case .photo: return "photo"
        case .files: return "doc"
        }
    }
}

private struct MarkdownMessageText: View {
    let text: String
    let fontSize: CGFloat
    let weight: Font.Weight
    let color: Color

    /// Scales the fixed message sizes with the user's Dynamic Type setting
    /// (1.0 at the default content size, growing relative to `.body`).
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(markdownLines.enumerated()), id: \.offset) { _, line in
                markdownLine(line)
            }
        }
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var markdownLines: [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    @ViewBuilder
    private func markdownLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Color.clear.frame(height: 3)
        } else if trimmed.hasPrefix("- ") {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("•")
                    .font(.system(size: fontSize * typeScale, weight: .bold))
                renderedText(String(trimmed.dropFirst(2)))
                    .font(.system(size: fontSize * typeScale, weight: weight))
            }
        } else if trimmed.hasPrefix("### ") {
            renderedText(String(trimmed.dropFirst(4)))
                .font(.system(size: (fontSize + 1) * typeScale, weight: .semibold))
        } else if trimmed.hasPrefix("## ") {
            renderedText(String(trimmed.dropFirst(3)))
                .font(.system(size: (fontSize + 2) * typeScale, weight: .semibold))
        } else if trimmed.hasPrefix("# ") {
            renderedText(String(trimmed.dropFirst(2)))
                .font(.system(size: (fontSize + 3) * typeScale, weight: .bold))
        } else {
            renderedText(line)
                .font(.system(size: fontSize * typeScale, weight: weight))
        }
    }

    private func renderedText(_ markdown: String) -> Text {
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
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            SearchDock()
            Spacer()
        }
        .padding(16)
    }
    .environment(UniverseViewModel())
    .preferredColorScheme(.dark)
}
