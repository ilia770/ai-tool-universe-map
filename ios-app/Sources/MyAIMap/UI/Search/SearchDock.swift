import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Bottom assistant dock. Collapsed it is a ChatGPT-like input plus a
/// right-side action button; once the user asks something, it grows a compact
/// glass transcript. Results are clickable and missing tools never get
/// fabricated: the assistant asks for a URL or attachment instead.
/// Command-K focuses the field on iPad / hardware keyboards.
struct SearchDock: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var fieldFocused: Bool
    @State private var selectedAttachment: AssistantAttachmentPayload?
    @State private var photoPickerPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var fileImporterPresented = false
    @State private var attachmentMenuOpen = false
    @State private var conversationCollapsed = false
    // Measured height of the transcript's content; drives the panel's size so it
    // fits its content and only scrolls once it exceeds the cap (C1).
    @State private var transcriptContentHeight: CGFloat = 0
    // Neutral seed; the real width arrives via the width preference key once
    // layout runs. UIScreen.main is the physical screen (wrong under iPad
    // Split View / Stage Manager) and is deprecated on iOS 26.
    @State private var dockWidth: CGFloat = 320
    @Namespace private var chatChromeNamespace

    let isChatOpen: Bool
    let dismissAttachmentMenuToken: UUID?
    let onAddTool: () -> Void
    let onAddSuggestedTool: ((MissingToolSuggestion) -> Void)?
    let onToolSelect: ((String) -> Void)?
    let onOpenToolDetail: ((String) -> Void)?
    let onChatActivityChange: ((Bool) -> Void)?
    /// §2 morph: when set, the composer Plus is the zoom source for the Add Tool
    /// sheet (the primary, persistent add trigger). Optional so the chat-surface
    /// instance — whose sheet is presented from a different context — can opt out.
    let addToolMorphNamespace: Namespace.ID?

    init(
        isChatOpen: Bool = false,
        dismissAttachmentMenuToken: UUID? = nil,
        onAddTool: @escaping () -> Void = {},
        onAddSuggestedTool: ((MissingToolSuggestion) -> Void)? = nil,
        onToolSelect: ((String) -> Void)? = nil,
        onOpenToolDetail: ((String) -> Void)? = nil,
        onChatActivityChange: ((Bool) -> Void)? = nil,
        addToolMorphNamespace: Namespace.ID? = nil
    ) {
        self.isChatOpen = isChatOpen
        self.dismissAttachmentMenuToken = dismissAttachmentMenuToken
        self.onAddTool = onAddTool
        self.onAddSuggestedTool = onAddSuggestedTool
        self.onToolSelect = onToolSelect
        self.onOpenToolDetail = onOpenToolDetail
        self.onChatActivityChange = onChatActivityChange
        self.addToolMorphNamespace = addToolMorphNamespace
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
        guard isChatOpen, !conversationCollapsed else { return false }
        // Phase 1 (chat open/show reliability): reveal the chat surface as soon
        // as chat opens — i.e. the moment the field is focused — even before the
        // first message. Previously this also required a non-empty query, so
        // tapping "Ask AI" flipped into chat mode (top chrome/cards hide, map
        // dims) yet showed no panel, reading on-device as "nothing happened".
        return fieldFocused || !model.assistantMessages.isEmpty
    }

    /// True when chat is open and focused but the user has not typed or sent
    /// anything yet — drives a short prompt so the panel is never blank.
    private var showsEmptyChatPrompt: Bool {
        model.assistantMessages.isEmpty && !(fieldFocused && hasQuery)
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
        ComposerLogic.userBubbleMaxWidth(availableWidth: measuredMessageWidth)
    }

    private var assistantMessageMaxWidth: CGFloat {
        min(420, measuredMessageWidth * ComposerLogic.assistantMessageMaxWidthRatio)
    }

    private var measuredMessageWidth: CGFloat {
        max(240, dockWidth - 20)
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    dockContent
                }
            } else {
                dockContent
            }
        }
        .photosPicker(
            isPresented: $photoPickerPresented,
            selection: $selectedPhotoItem,
            matching: .images,
            preferredItemEncoding: .automatic
        )
        .fileImporter(
            isPresented: $fileImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImporterResult(result)
        } onCancellation: {
            fieldFocused = true
        }
        .onChange(of: selectedPhotoItem) { _, item in
            handlePhotoPickerSelection(item)
        }
    }

    private var dockContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsConversation {
                conversationPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showsCollapsedConversationPill {
                collapsedConversationPill
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            composerWithAttachmentOverlay
        }
        .frame(maxWidth: .infinity)
        .brandAnimation(BrandMotion.nudge, value: showsConversation)
        .brandAnimation(BrandMotion.nudge, value: showsCollapsedConversationPill)
        .brandAnimation(BrandMotion.nudge, value: attachmentMenuOpen)
        .brandAnimation(BrandMotion.nudge, value: previewResults.map(\.id))
        .brandAnimation(BrandMotion.nudge, value: fieldFocused)
        .brandAnimation(BrandMotion.nudge, value: selectedAttachment)
        .onAppear {
            // If the dock mounts already in chat mode (e.g. chat opened before
            // this dock instance appeared), reveal + focus so the panel shows;
            // `onChange(of:isChatOpen)` only fires on later transitions, not the
            // initial already-open state.
            if isChatOpen {
                conversationCollapsed = false
                // Focus (raise keyboard) ONLY for a fresh, empty chat — the user
                // needs to type. With prior messages this is a remount (e.g.
                // returning from a tool-detail sheet) or a post-send reveal, where
                // forcing the keyboard back up is unwanted.
                if model.assistantMessages.isEmpty {
                    fieldFocused = true
                }
            }
            onChatActivityChange?(chatIsActive)
        }
        .onChange(of: chatIsActive) { _, isActive in
            onChatActivityChange?(isActive)
        }
        .background {
            ZStack {
                GeometryReader { proxy in
                    Color.clear.preference(key: SearchDockWidthPreferenceKey.self, value: proxy.size.width)
                }

                Button("Focus search") { fieldFocused = true }
                    .keyboardShortcut("k", modifiers: .command)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onPreferenceChange(SearchDockWidthPreferenceKey.self) { width in
            guard width > 0 else { return }
            dockWidth = width
        }
        .onChange(of: isChatOpen) { _, isOpen in
            guard isOpen else {
                fieldFocused = false
                attachmentMenuOpen = false
                conversationCollapsed = true
                return
            }
            // Chat was opened from outside the dock (the map "Ask AI" buttons flip
            // `isChatOpen` without touching the field). `showsConversation` needs
            // the field focused (or a prior message) to reveal the panel, so an
            // externally-opened chat with an empty transcript showed nothing —
            // "Ask AI did nothing". Reveal the panel; focus (raise keyboard) ONLY
            // for an empty chat (fresh open → user types). After a send the reply
            // flips `isChatOpen` true with messages present — reveal it WITHOUT
            // re-raising the keyboard that `submit()` just dismissed.
            conversationCollapsed = false
            if model.assistantMessages.isEmpty {
                fieldFocused = true
            }
        }
        .onChange(of: dismissAttachmentMenuToken) { _, _ in
            attachmentMenuOpen = false
        }
    }

    private var showsAttachmentMenu: Bool {
        ComposerLogic.showsAttachmentMenu(menuOpen: attachmentMenuOpen)
    }

    private var showsAttachmentPreview: Bool {
        ComposerLogic.showsAttachmentPreview(
            menuOpen: attachmentMenuOpen,
            hasAttachment: selectedAttachment != nil
        )
    }

    private var composerWithAttachmentOverlay: some View {
        // The float lane above the composer hosts the menu OR the staged-
        // attachment preview — mutually exclusive (CHAT_INPUT_SPEC §4). Both
        // float as an overlay with no layout footprint, so the composer stays
        // put and the panel floats over the transcript above it (review finding
        // R16). Inline stacking pushed the composer down / clipped the keyboard.
        composerRow
            .overlay(alignment: .topLeading) {
                Group {
                    if showsAttachmentMenu {
                        attachmentMenuPopover
                    } else if let selectedAttachment, showsAttachmentPreview {
                        attachmentPreview(selectedAttachment)
                    }
                }
                // Float the panel ABOVE the composer with an 8pt gap so it clears
                // the keyboard (C2). Anchored to the composer's top edge, the
                // panel's bottom (+8) sits at that edge, lifting it fully above —
                // the previous `.bottomLeading` guide pushed it *below* the row,
                // hiding it behind the keyboard.
                .alignmentGuide(.top) { dimensions in
                    dimensions[.bottom] + 8
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(2)
            }
    }

    private var composerRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            composer
            trailingActionButton
        }
        .frame(maxWidth: .infinity)
    }

    private var composer: some View {
        @Bindable var model = model
        return HStack(alignment: .bottom, spacing: 8) {
            attachmentMenu

            TextField("Ask AI Universe", text: $model.assistantQuery, axis: .vertical)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(.white)
                .tint(model.selectedCategoryModel.color.swiftUIColor)
                .focused($fieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .lineLimit(1...ComposerLogic.composerMaxLines)
                .fixedSize(horizontal: false, vertical: true)
                .onSubmit(submit)
                .onChange(of: fieldFocused) { _, focused in
                    if focused {
                        BrandHaptics.fire(.light)
                        conversationCollapsed = false
                    } else {
                        attachmentMenuOpen = false
                    }
                }
                .accessibilityIdentifier("chat-composer-field")
        }
        .frame(maxWidth: .infinity, minHeight: ComposerLogic.composerMinHeight, alignment: .bottom)
        .padding(5)
        // Clean dark-translucent glass capsule (CHAT_INPUT_SPEC §1): no accent
        // tint, no black backing plate, no glowing outline. Accent shows only
        // as the field's caret/selection tint above. One soft float shadow.
        .liquidGlassInput()
        // Pin a STABLE, UNIQUE glass identity (C4). The composer pill is the only
        // un-id'd glass element sharing the dock's `GlassEffectContainer` with the
        // morphing chat-collapse↔restore-pill pair (both `SearchDock.chatCollapse`).
        // Without its own id, the container reconciled the pill's glass into that
        // travelling morph mid-collapse/reveal, snapshotting the embedded attach
        // glyph as a tiny rotated sliver pinned to a corner. A distinct id excludes
        // the composer (and its attach button) from any morph, keeping it static.
        .navigationGlassMorphID("SearchDock.composer", in: chatChromeNamespace)
    }

    private var attachmentMenu: some View {
        Button {
            BrandHaptics.fire(.light)
            fieldFocused = true
            withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                attachmentMenuOpen.toggle()
            }
        } label: {
            Image(systemName: ComposerLogic.attachmentTriggerIcon(hasAttachment: selectedAttachment != nil))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selectedAttachment == nil ? .white.opacity(0.74) : model.selectedCategoryModel.color.swiftUIColor)
                .frame(width: 36, height: 36)
                // Lives inside the composer pill (already glass); a nested glass
                // here would double-lens. Solid fill keeps the tappable affordance.
                .background(.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.92, haptic: nil, pressedOpacity: 1))
        // NOTE: no `.hitArea()` here — this button is embedded in the composer
        // pill (liquidGlassInput), which already provides a large tap region;
        // force-growing it to 44pt overflows the pill and shifts the menu anchor.
        .accessibilityLabel("Attach photo or file")
        .accessibilityIdentifier("chat-attach-button")
    }

    private var attachmentMenuPopover: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                // Two items only (CHAT_INPUT_SPEC §2). The remove path lives on
                // the floating preview's remove button (§3), not in this menu.
                ForEach(AssistantAttachmentKind.allCases) { kind in
                    attachmentMenuItem(kind)
                }
            }
            .padding(7)
            .frame(width: 164)
            // Floating-panel style (LIQUID_GLASS_VISUAL_SPEC §4): single glass
            // panel, no black backing plate, no heavy accent tint. One shadow.
            .glassSurface(
                in: RoundedRectangle(cornerRadius: BrandRadius.bubble.value, style: .continuous),
                interactive: true
            )
            .shadow(color: .black.opacity(0.34), radius: 16, x: 0, y: 8)

            Spacer(minLength: 0)
        }
        .padding(.leading, 2)
        .allowsHitTesting(attachmentMenuOpen)
    }

    private func attachmentMenuItem(_ kind: AssistantAttachmentKind) -> some View {
        Button {
            BrandHaptics.fire(.light)
            attachmentMenuOpen = false
            presentAttachmentPicker(kind)
        } label: {
            Label(kind.title, systemImage: kind.icon)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(.white.opacity(selectedAttachment?.kind == kind ? 0.12 : 0.055), in: Capsule())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil, pressedOpacity: 0.9))
        .accessibilityLabel(kind.title)
        .accessibilityIdentifier(kind.accessibilityIdentifier)
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
                .buttonStyle(PressableButtonStyle(pressedScale: 0.92, haptic: nil, pressedOpacity: 1))
                .disabled(!canSend)
                .accessibilityLabel(canSend ? "Send" : "Send unavailable")
                .accessibilityIdentifier("chat-send-button")
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
                .buttonStyle(PressableButtonStyle(pressedScale: 0.92, haptic: nil, pressedOpacity: 1))
                .accessibilityLabel("Add tool")
                .accessibilityIdentifier("chat-add-tool-button")
                // Zoom-morph source for the Add Tool sheet (callers pass nil to
                // opt out — e.g. the universe surface when the empty-state card
                // already owns the morph, so the id is never duplicated).
                .morphSource(ChromeMorphID.addTool, in: addToolMorphNamespace)
            }
        }
        .frame(width: 44, height: 44)
    }

    /// Floating Liquid Glass attachment preview above the input (CHAT_INPUT_SPEC
    /// §3): thumbnail / type glyph, name + type, and a trailing remove button.
    /// Same float lane as the menu and mutually exclusive with it. It floats with
    /// no layout footprint, so it never crowds the text field or covers the chat.
    private func attachmentPreview(_ attachment: AssistantAttachmentPayload) -> some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 10) {
                Image(systemName: attachment.kind.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(model.selectedCategoryModel.color.swiftUIColor)
                    .frame(width: 36, height: 36)
                    .background(
                        .white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: BrandRadius.tight.value, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.previewName)
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(BrandColor.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(attachment.previewDetail)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(BrandColor.textMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    BrandHaptics.fire(.light)
                    withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                        selectedAttachment = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.74))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.9, haptic: nil, pressedOpacity: 1))
                .accessibilityLabel("Remove attachment")
                .accessibilityIdentifier("chat-attachment-remove")
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            // Floating-panel style (LIQUID_GLASS_VISUAL_SPEC §4): single glass
            // card, no accent backing, one soft shadow.
            .glassSurface(
                in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous),
                interactive: true
            )
            .shadow(color: .black.opacity(0.34), radius: 16, x: 0, y: 8)
        }
        .padding(.leading, 2)
        // Width follows the dock, not full-bleed past the composer.
        .frame(maxWidth: dockWidth)
    }

    private var conversationPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    conversationHeader

                    if showsEmptyChatPrompt {
                        emptyChatPrompt
                    }

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
                // Measure the content so the panel can size to it (C1): an empty
                // Ask-AI state shows only the short prompt instead of reserving
                // the full cap of dead space.
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    transcriptContentHeight = height
                }
            }
            .frame(maxWidth: .infinity)
            // Grow with content, cap (and start scrolling) at transcriptMaxHeight.
            .frame(height: ComposerLogic.transcriptHeight(contentHeight: transcriptContentHeight))
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("chat-transcript")
            .onChange(of: model.assistantMessages.count) { _, _ in
                guard let last = model.assistantMessages.last else { return }
                withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        // Translucent reading surface: ultraThinMaterial frosts the universe
        // behind the transcript (light back-blur) instead of a flat opaque fill.
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
                .stroke(BrandColor.stroke, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.32), radius: 16, x: 0, y: 8)
        .simultaneousGesture(TapGesture().onEnded {
            attachmentMenuOpen = false
        })
    }

    private var collapsedConversationPill: some View {
        Button {
            BrandHaptics.fire(.light)
            attachmentMenuOpen = false
            withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                conversationCollapsed = false
            }
            onChatActivityChange?(true)
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
            // Floating chrome — neutral glass, no accent fill (visual spec §2/§4).
            .glassSurface(in: Capsule(), interactive: true)
            .navigationGlassMorphID("SearchDock.chatCollapse", in: chatChromeNamespace)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil, pressedOpacity: 0.9))
        .brandAnimation(BrandMotion.morph, value: conversationCollapsed)
    }

    private var conversationHeader: some View {
        HStack(spacing: 8) {
            Label("AI Chat", systemImage: "sparkles")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white.opacity(0.76))

            Spacer()

            Button {
                BrandHaptics.fire(.light)
                withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                    conversationCollapsed = true
                    fieldFocused = false
                    attachmentMenuOpen = false
                }
            } label: {
                // `xmark`, not `chevron.down`: this dismisses the chat panel
                // (collapses it to the "Show chat" pill). A down-chevron at the
                // top of a scrollable transcript read as "scroll to bottom" and
                // confused users (C5); a close glyph is unambiguous and keeps the
                // collapse affordance the restore pill depends on.
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 30, height: 30)
                    // Floating chrome — neutral glass icon button (visual spec §2).
                    .glassSurface(in: Circle(), interactive: true)
                    .navigationGlassMorphID("SearchDock.chatCollapse", in: chatChromeNamespace)
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.9, haptic: nil, pressedOpacity: 1))
            .accessibilityLabel("Collapse chat")
        }
        .padding(.leading, 2)
    }

    private var emptyChatPrompt: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ask AI Universe")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text("Ask what tool to use, how to combine them, or compare by price and stage. I pull from the tools in your map.")
                .font(.system(.footnote))
                .foregroundStyle(BrandColor.textMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, BrandSpacing.s.value)
        .padding(.vertical, BrandSpacing.s.value)
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
                Spacer(minLength: max(20, measuredMessageWidth * 0.16))
                userBubble(message.text)
            } else {
                assistantResponse(message, matches: matches)
                Spacer(minLength: max(18, measuredMessageWidth * 0.12))
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
            // Chat bubble is content — neutral solid surface, never accent fill
            // (LIQUID_GLASS_VISUAL_SPEC C2). Speaker conveyed by alignment + tone.
            .background(
                .white.opacity(0.07),
                in: RoundedRectangle(cornerRadius: BrandRadius.bubble.value, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BrandRadius.bubble.value, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 0.5)
            }
    }

    private func assistantResponse(_ message: AssistantMessage, matches: [Tool]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let prose = assistantProse(from: message.text)
            if !prose.isEmpty {
                MarkdownMessageText(text: prose, fontSize: 15, weight: .regular, color: .white.opacity(0.88))
            }

            if !matches.isEmpty || !message.missingToolSuggestions.isEmpty {
                assistantChipSections(matches: matches, missingSuggestions: message.missingToolSuggestions)
                if !message.missingToolSuggestions.isEmpty {
                    nextHint("Suggested tools are not verified in your universe yet; pricing unknown, verify website.")
                }
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

    private func assistantChipSections(matches: [Tool], missingSuggestions: [MissingToolSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !matches.isEmpty {
                assistantChipLabel("Already in your universe")
                actionStrip(for: matches, missingSuggestions: [])
            }
            if !missingSuggestions.isEmpty {
                assistantChipLabel("Suggested to add")
                actionStrip(for: [], missingSuggestions: missingSuggestions)
            }
        }
    }

    private func assistantChipLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption2, weight: .bold))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.54))
            .padding(.top, 2)
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
                    // Accent on the icon only (tiny highlight), not the fill.
                    .foregroundStyle(category.color.swiftUIColor)
                Text(tool.name)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
            }
            // Chip style (LIQUID_GLASS_VISUAL_SPEC §3/C6): neutral capsule + hairline.
            .actionChipBackground()
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil))
    }

    private func missingToolButton(_ suggestion: MissingToolSuggestion) -> some View {
        let category = UniverseSeed.category(suggestion.category)
        return Button {
            BrandHaptics.fire(.light)
            withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
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
                    // Accent on the icon only (tiny highlight), not the fill.
                    .foregroundStyle(category.color.swiftUIColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Add \(suggestion.name)")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                    Text(category.shortName)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }
            }
            // Chip style (LIQUID_GLASS_VISUAL_SPEC §3/C6): neutral capsule + hairline.
            .actionChipBackground()
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
        AssistantResponsePresentation.prose(from: text)
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
        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
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
        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
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
        // The assistant can't read attachments, so flag an attachment-only send
        // (no real text) and let it answer honestly instead of matching tools
        // against the "attached photo/file" placeholder (U1).
        let attachmentOnly = model.assistantQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedAttachment != nil
        BrandHaptics.fire(.light)
        conversationCollapsed = false
        attachmentMenuOpen = false
        // F4 (send broken in 3D): the conversation panel only reveals while
        // `isChatOpen` is true, which is driven up by the focus→activity chain.
        // `submit()` blurs the field at the end, so if the field-focus that
        // opened chat hadn't yet round-tripped back as `isChatOpen` (notably in
        // the 3D map where the RealityKit surface can swallow the focus event),
        // the reply appended below stayed hidden — the user "sends" and sees
        // nothing. Notify the parent to open chat *now*, synchronously with the
        // send, so the reply is always visible regardless of the focus timing.
        onChatActivityChange?(true)
        model.assistantQuery = outgoingText
        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) { model.askAssistant(attachmentOnly: attachmentOnly) }
        selectedAttachment = nil
        fieldFocused = false
    }

    private func clearComposer() {
        model.assistantQuery = ""
        selectedAttachment = nil
        fieldFocused = false
    }
}

private extension SearchDock {
    var usesDeterministicAttachmentPicker: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitestStatic")
    }

    func presentAttachmentPicker(_ kind: AssistantAttachmentKind) {
        if usesDeterministicAttachmentPicker {
            selectedAttachment = .deterministic(kind)
            fieldFocused = true
            return
        }

        fieldFocused = false
        switch kind {
        case .photo:
            photoPickerPresented = true
        case .files:
            fileImporterPresented = true
        }
    }

    func handlePhotoPickerSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }
        selectedAttachment = AssistantAttachmentPayload(
            kind: .photo,
            previewName: "Selected photo",
            previewDetail: "Loading image",
            messageTitle: "photo"
        )
        Task {
            let size = try? await item.loadTransferable(type: Data.self)?.count
            await MainActor.run {
                selectedAttachment = AssistantAttachmentPayload(
                    kind: .photo,
                    previewName: "Selected photo",
                    previewDetail: size.map(byteCountString) ?? "Image",
                    messageTitle: "photo"
                )
                fieldFocused = true
            }
        }
    }

    func handleFileImporterResult(_ result: Result<[URL], any Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            fieldFocused = true
            return
        }
        selectedAttachment = payload(for: url)
        fieldFocused = true
    }

    func payload(for url: URL) -> AssistantAttachmentPayload {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        let type = resourceValues?.contentType?.localizedDescription
            ?? (url.pathExtension.isEmpty ? "Document" : url.pathExtension.uppercased())
        let size = resourceValues?.fileSize.map(byteCountString)
        return AssistantAttachmentPayload(
            kind: .files,
            previewName: url.lastPathComponent.isEmpty ? "Selected file" : url.lastPathComponent,
            previewDetail: [type, size].compactMap { $0 }.joined(separator: " - "),
            messageTitle: url.lastPathComponent.isEmpty ? "file" : "file \(url.lastPathComponent)"
        )
    }

    func byteCountString(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

private struct AssistantAttachmentPayload: Equatable {
    let kind: AssistantAttachmentKind
    let previewName: String
    let previewDetail: String
    let messageTitle: String

    static func deterministic(_ kind: AssistantAttachmentKind) -> AssistantAttachmentPayload {
        switch kind {
        case .photo:
            return AssistantAttachmentPayload(
                kind: .photo,
                previewName: "Selected photo",
                previewDetail: "Image",
                messageTitle: "photo"
            )
        case .files:
            return AssistantAttachmentPayload(
                kind: .files,
                previewName: "Selected file",
                previewDetail: "Document",
                messageTitle: "file"
            )
        }
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

    var accessibilityIdentifier: String {
        switch self {
        case .photo: return "chat-attachment-photo"
        case .files: return "chat-attachment-files"
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

private struct SearchDockWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}
