import SwiftUI
import UIKit

enum ChatTheme {
    static let background = Color(red: 11.0 / 255, green: 13.0 / 255, blue: 18.0 / 255)
    static let surface = Color(red: 19.0 / 255, green: 22.0 / 255, blue: 29.0 / 255)
    static let surfaceRaised = Color(red: 25.0 / 255, green: 29.0 / 255, blue: 38.0 / 255)
    static let text = Color.white.opacity(0.92)
    static let secondaryText = Color.white.opacity(0.62)
}

/// Pure transcript-grouping logic: decides whether a day separator row should
/// precede a turn, and what it should read. Value-only so it is unit testable
/// without hosting any view.
enum ChatTranscriptGrouping {
    /// Returns the separator label to show *above* `current`, or `nil` when the
    /// previous turn falls on the same calendar day. The first turn always gets
    /// a separator (`previous == nil`) so a session opens with a dated anchor.
    static func daySeparatorLabel(
        for current: Date,
        previous: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        if let previous, calendar.isDate(previous, inSameDayAs: current) {
            return nil
        }
        return label(for: current, now: now, calendar: calendar)
    }

    /// "Today" / "Yesterday" / weekday (within the past week) / medium date.
    static func label(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current

        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: now), date >= weekAgo {
            formatter.dateFormat = "EEEE"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        return formatter.string(from: date)
    }
}

struct ChatScreen: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dismissComposerChromeToken = UUID()
    /// True once the bottom of the transcript is scrolled out of view; gates
    /// the jump-to-latest pill.
    @State private var showsJumpToLatest = false
    /// Drives the copy-confirmation toast when the user copies an answer.
    @State private var copyToastKind: CopyToastKind?

    /// Stable scroll target so the jump pill and send-autoscroll land at the
    /// very bottom even while the last turn is still revealing.
    private static let transcriptBottomID = "ChatScreen.TranscriptBottom"

    let onOpenSettings: () -> Void
    let onAddTool: () -> Void
    let onAddSuggestedTool: (MissingToolSuggestion) -> Void
    let onOpenToolInUniverse: (String) -> Void
    /// §6.3: an existing-tool chip in the transcript opens that tool's full
    /// detail (not just a map focus). Defaults to the in-universe focus so older
    /// call sites keep working.
    var onOpenToolDetail: (String) -> Void = { _ in }
    /// §orbit: an existing-tool chip also flies a ghost of itself into that
    /// tool's planet on the map as it opens detail (the detail open is the
    /// substance). Defaults to a no-op so older call sites keep working.
    var onOpenToolFlight: (ToolFlightRequest) -> Void = { _ in }
    /// Always-enabled "back to map" control (§3.3 navigation spec): lets the
    /// user leave the chat surface for the map at any time, regardless of tool
    /// count. No half-state — it lands cleanly on the map surface.
    var onBackToMap: () -> Void = {}
    /// Reports the tapped add-card's frame so the shell can fly a ghost of it
    /// toward the Map pill (signature "tool lands in your universe" moment).
    var onCardLand: (CardLandRequest) -> Void = { _ in }
    /// §2 morph: namespace (owned by `RootShell`) shared with the Account + Add
    /// Tool sheets so the chat chrome zoom-morphs into them.
    var chromeMorphNamespace: Namespace.ID? = nil

    private var toolCount: Int {
        model.visibleAllTools.count
    }

    var body: some View {
        VStack(spacing: 0) {
            ChatTopBar(
                onBackToMap: onBackToMap,
                onOpenSettings: onOpenSettings,
                chromeMorphNamespace: chromeMorphNamespace
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            transcript
                .zIndex(0)

            composer
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                // The starter prompt can extend to the bottom edge of the
                // transcript's AX frame while the keyboard squeezes the layout.
                // Keep composer controls and their floating attachment menu
                // above that scroll content for both rendering and hit testing.
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChatTheme.background.ignoresSafeArea())
        .copyToast($copyToastKind)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if model.assistantMessages.isEmpty {
                        ChatStarterPanel(onSendPrompt: sendStarterPrompt)
                            .padding(.top, 52)
                    } else {
                        let messages = model.assistantMessages
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            if let label = ChatTranscriptGrouping.daySeparatorLabel(
                                for: message.createdAt,
                                previous: index > 0 ? messages[index - 1].createdAt : nil
                            ) {
                                ChatDaySeparator(label: label)
                            }

                            ChatMessageTurn(
                                message: message,
                                matches: tools(for: message.matchIDs),
                                isLatest: index == messages.count - 1,
                                onOpenTool: onOpenToolDetail,
                                onOpenToolFlight: onOpenToolFlight,
                                onAddSuggestedTool: onAddSuggestedTool,
                                onCardLand: onCardLand,
                                onCopyAnswer: { copyToastKind = .answer }
                            )
                            .id(message.id)
                        }
                    }

                    // Zero-height bottom sentinel: when it leaves the viewport
                    // the user has scrolled up, so we offer the jump pill.
                    Color.clear
                        .frame(height: 1)
                        .id(Self.transcriptBottomID)
                        .onScrollVisibilityChange(threshold: 0.1) { visible in
                            withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                                showsJumpToLatest = !visible && !model.assistantMessages.isEmpty
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
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissComposerChromeToken = UUID()
                }
            )
            .overlay(alignment: .bottomTrailing) {
                if showsJumpToLatest {
                    JumpToLatestPill {
                        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
                            proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
                        }
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 14)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .onChange(of: model.assistantMessages.count) { _, _ in
                guard !model.assistantMessages.isEmpty else { return }
                withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
                    proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        SearchDock(
            isChatOpen: false,
            dismissAttachmentMenuToken: dismissComposerChromeToken,
            onAddTool: onAddTool,
            onAddSuggestedTool: onAddSuggestedTool,
            onToolSelect: onOpenToolInUniverse,
            onOpenToolDetail: onOpenToolInUniverse,
            onChatActivityChange: nil,
            addToolMorphNamespace: chromeMorphNamespace
        )
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    private func tools(for ids: [String]) -> [Tool] {
        ids.compactMap { id in model.visibleAllTools.first { $0.id == id } }
    }

    private func sendStarterPrompt(_ prompt: StarterPrompt) {
        if model.isUniverseEmpty {
            let suggestion = prompt.suggestion
            model.assistantMessages.append(AssistantMessage(role: .user, text: prompt.query))
            model.assistantMessages.append(
                AssistantMessage(
                    role: .assistant,
                    text: "Start by adding \(suggestion.name). It gives this workflow a concrete first node on the map, then you can keep growing the branch.",
                    missingToolSuggestions: [suggestion]
                )
            )
            return
        }

        model.assistantQuery = prompt.query
        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
            model.askAssistant()
        }
    }
}

private struct ChatTopBar: View {
    let onBackToMap: () -> Void
    let onOpenSettings: () -> Void
    var chromeMorphNamespace: Namespace.ID? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Always-visible, always-enabled return to the map (§3.3): chat is
            // never a dead-end, regardless of tool count.
            Button(action: onBackToMap) {
                Image(systemName: "map.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ChatTheme.text)
                    .frame(width: 40, height: 40)
                    .glassSurface(in: Circle(), tint: BrandColor.core.opacity(0.16))
            }
            .buttonStyle(BouncyIconButtonStyle())
            .accessibilityLabel("Back to map")
            .accessibilityIdentifier("ChatScreen.BackToMap")

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Universe")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(ChatTheme.text)
                Text("Ask, choose, and grow your map")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(ChatTheme.secondaryText)
            }

            Spacer()

            Button(action: onOpenSettings) {
                UserAvatarImage(size: 40, tint: BrandColor.core)
            }
            .buttonStyle(BouncyIconButtonStyle())
            .accessibilityLabel("Account")
            .accessibilityIdentifier("ChatScreen.Account")
            .morphSource(ChromeMorphID.account, in: chromeMorphNamespace)
        }
    }
}

private struct ChatStarterPanel: View {
    let onSendPrompt: (StarterPrompt) -> Void

    private let prompts = [
        StarterPrompt(
            id: "design-app",
            title: "Design an app",
            query: "What tool should I use for app design?",
            suggestion: MissingToolSuggestion(
                name: "Figma",
                category: .design,
                reason: "Best first node for app UI, prototypes, and design handoff."
            )
        ),
        StarterPrompt(
            id: "build-mvp",
            title: "Build an MVP",
            query: "I need a workflow to build and launch an MVP",
            suggestion: MissingToolSuggestion(
                name: "Supabase",
                category: .infrastructure,
                reason: "Fast backend/auth/database foundation for a first MVP."
            )
        ),
        StarterPrompt(
            id: "track-growth",
            title: "Track growth",
            query: "Looking for analytics tools for a new product",
            suggestion: MissingToolSuggestion(
                name: "PostHog",
                category: .analytics,
                reason: "Product analytics and funnels should land early in the stack."
            )
        ),
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

                Text("Ask AI about your stack")
                    .font(.system(size: 28, weight: .semibold))
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
                        onSendPrompt(prompt)
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
                    .accessibilityIdentifier("ChatScreen.StarterPrompt.\(prompt.id)")
                }
            }
        }
    }
}

private struct StarterPrompt: Identifiable {
    let id: String
    let title: String
    let query: String
    let suggestion: MissingToolSuggestion
}

private struct ChatMessageTurn: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let message: AssistantMessage
    let matches: [Tool]
    var isLatest: Bool = false
    let onOpenTool: (String) -> Void
    var onOpenToolFlight: (ToolFlightRequest) -> Void = { _ in }
    let onAddSuggestedTool: (MissingToolSuggestion) -> Void
    var onCardLand: (CardLandRequest) -> Void = { _ in }
    /// Fired after the assistant answer is written to the pasteboard so the host
    /// screen can show the "Answer copied" toast.
    var onCopyAnswer: () -> Void = {}

    /// Drives the assistant turn's fade+rise on arrival. Starts `false` only
    /// for the newest assistant turn so older turns render statically when the
    /// transcript scrolls; reduce-motion skips the transient entirely.
    @State private var appeared = false
    /// Drives the matched/missing chip group, which reveals a beat after the
    /// prose (see `assistantTurn`).
    @State private var chipsRevealed = false

    private var isUser: Bool { message.role == .user }

    /// New assistant turns animate in; user bubbles, older turns, and
    /// reduce-motion render immediately so text legibility is never gated.
    private var shouldReveal: Bool {
        !isUser && isLatest && !reduceMotion
    }

    var body: some View {
        if isUser {
            // User bubble hugs its content, right-aligned, capped at ~78% width.
            HStack(spacing: 0) {
                Spacer(minLength: 42)
                userBubble
            }
        } else {
            assistantTurn
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(shouldReveal ? (appeared ? 1 : 0) : 1)
                .offset(y: shouldReveal ? (appeared ? 0 : 8) : 0)
                .onAppear {
                    guard shouldReveal else { return }
                    withBrandAnimation(BrandMotion.stream, reduceMotion: reduceMotion) {
                        appeared = true
                    }
                }
        }
    }

    private var userBubble: some View {
        // Hug-content text (NOT stretched to full width); the outer HStack's
        // Spacer caps the bubble at ~78% of the row width and right-aligns it.
        Text(message.text)
            .font(.system(.body, weight: .medium))
            .foregroundStyle(.white.opacity(0.92))
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            // Neutral content surface (LIQUID_GLASS_VISUAL_SPEC C2): no accent
            // fill on the bubble. Speaker conveyed by right alignment + tone.
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: BrandRadius.bubble.value, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BrandRadius.bubble.value, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 0.5)
            }
    }

    private var assistantTurn: some View {
        // No leading avatar: assistant content spans the column, left-aligned.
        VStack(alignment: .leading, spacing: 12) {
            let prose = assistantProse(from: message.text)
            if !prose.isEmpty {
                ChatMarkdownText(text: prose, font: .system(.body), color: ChatTheme.text)
                    .lineSpacing(5)
            }

            if !matches.isEmpty || !message.missingToolSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if !matches.isEmpty {
                        chipSectionLabel("Already in your universe")
                        ChatChipRow {
                            ForEach(matches.prefix(4)) { tool in
                                ChatExistingToolChip(
                                    tool: tool,
                                    onOpenFlight: onOpenToolFlight,
                                    onOpen: { onOpenTool(tool.id) }
                                )
                            }
                        }
                    }

                    if !message.missingToolSuggestions.isEmpty {
                        chipSectionLabel("Suggested to add")
                        ChatChipRow {
                            ForEach(message.missingToolSuggestions.prefix(4)) { suggestion in
                                ChatMissingToolChip(
                                    suggestion: suggestion,
                                    onCardLand: onCardLand,
                                    onAdd: { onAddSuggestedTool(suggestion) }
                                )
                            }
                        }
                    }
                }
                // The chip group reveals a beat after the prose so the tools
                // read as a consequence of the answer, not part of it.
                .opacity(shouldReveal ? (chipsRevealed ? 1 : 0) : 1)
                .offset(y: shouldReveal ? (chipsRevealed ? 0 : 8) : 0)
                .onAppear {
                    guard shouldReveal else { return }
                    withBrandAnimation(BrandMotion.reveal.delay(0.18), reduceMotion: reduceMotion) {
                        chipsRevealed = true
                    }
                }
            }

            assistantActionRow
        }
    }

    private func chipSectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption2, weight: .bold))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(ChatTheme.secondaryText)
            .padding(.top, 2)
    }

    private var assistantActionRow: some View {
        HStack(spacing: 18) {
            Button {
                UIPasteboard.general.string = AssistantClipboardFormatter.text(from: message.text)
                BrandHaptics.fire(.success)
                onCopyAnswer()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.9, haptic: nil))
            .hitArea()
            .accessibilityLabel("Copy message")
            .accessibilityIdentifier("ChatScreen.Action.Copy.\(message.id)")
        }
        .foregroundStyle(ChatTheme.secondaryText)
        .padding(.top, 2)
    }

    private func assistantProse(from text: String) -> String {
        AssistantResponsePresentation.prose(from: text)
    }
}

/// Subtle centered separator between turns from different calendar days.
private struct ChatDaySeparator: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            line
            Text(label)
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(ChatTheme.secondaryText)
                .fixedSize()
            line
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityIdentifier("ChatScreen.DaySeparator")
    }

    private var line: some View {
        Rectangle()
            .fill(BrandColor.stroke)
            .frame(height: 0.5)
    }
}

/// Small glass capsule, bottom-trailing, that scrolls the transcript to the
/// latest turn. Appears only while the bottom sentinel is off-screen.
private struct JumpToLatestPill: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            BrandHaptics.fire(.light)
            onTap()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ChatTheme.text)
                .frame(width: 38, height: 38)
                .glassSurface(in: Circle())
        }
        .accessibilityLabel("Jump to latest message")
        .accessibilityIdentifier("ChatScreen.JumpToLatest")
    }
}

/// Wrapping horizontal flow: lays chips out in a line, wrapping to the next
/// row when they no longer fit (ChatGPT-style inline source pills).
private struct ChatChipRow: Layout {
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 8

    init(hSpacing: CGFloat = 8, vSpacing: CGFloat = 8) {
        self.hSpacing = hSpacing
        self.vSpacing = vSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + hSpacing + size.width > maxWidth {
                totalHeight += rowHeight + vSpacing
                maxRowWidth = max(maxRowWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? hSpacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth)
        return CGSize(width: min(maxRowWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + vSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Compact "add suggested tool" pill. On tap it reports its own frame to the
/// shell (which flies a ghost of it to the Map pill — the "tool lands in your
/// universe" signature moment), cross-fades itself out, then runs the add. The
/// `PressableButtonStyle(haptic: nil)` lets the shell own the richer `toolLand`
/// cue instead of stacking a plain press haptic on top of it.
private struct ChatMissingToolChip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let suggestion: MissingToolSuggestion
    var onCardLand: (CardLandRequest) -> Void = { _ in }
    let onAdd: () -> Void

    /// Captured frame of this chip in the shared flight coordinate space.
    @State private var frame: CGRect = .zero
    /// Drives the local cross-fade as the card "leaves" toward the map.
    @State private var sent = false

    private var category: ToolCategory {
        UniverseSeed.category(suggestion.category)
    }

    var body: some View {
        Button(action: tapped) {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text(suggestion.name)
                    .font(.system(.footnote, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(category.color.swiftUIColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(category.color.swiftUIColor.opacity(0.10), in: Capsule())
            .overlay {
                Capsule().stroke(category.color.swiftUIColor.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
        // The real chip fades as its ghost departs (or just cross-fades under
        // reduce-motion, where no ghost flies).
        .opacity(sent ? 0 : 1)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ChipFramePreferenceKey.self,
                    value: proxy.frame(in: .named(RootShellCoordinateSpace.name))
                )
            }
        }
        .onPreferenceChange(ChipFramePreferenceKey.self) { frame = $0 }
        .accessibilityLabel("Add \(suggestion.name) to my map")
        .accessibilityIdentifier("ChatScreen.MissingTool.\(suggestion.id)")
    }

    private func tapped() {
        onCardLand(
            CardLandRequest(
                id: UUID(),
                title: suggestion.name,
                sourceFrame: frame,
                tint: category.color.swiftUIColor
            )
        )
        withBrandAnimation(BrandMotion.morph, reduceMotion: reduceMotion) {
            sent = true
        }
        onAdd()
        // Restore the chip after the flight settles so a cancelled add (or a
        // re-tap) leaves the suggestion tappable again, not stuck invisible.
        Task {
            try? await Task.sleep(for: .milliseconds(520))
            withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                sent = false
            }
        }
    }
}

/// Existing-tool chip in the chat transcript. Reuses the canonical `ToolChip`
/// look, but captures its own frame so a tap both opens the tool's detail and
/// flies a ghost of the chip into that tool's planet on the map (§orbit). Falls
/// back to a plain detail open if the frame isn't known yet.
private struct ChatExistingToolChip: View {
    let tool: Tool
    var onOpenFlight: (ToolFlightRequest) -> Void = { _ in }
    let onOpen: () -> Void

    /// Captured frame of this chip in the shared flight coordinate space.
    @State private var frame: CGRect = .zero

    private var tint: Color { UniverseSeed.category(tool.category).color.swiftUIColor }

    var body: some View {
        ToolChip(tool: tool) { tapped() }
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ChipFramePreferenceKey.self,
                        value: proxy.frame(in: .named(RootShellCoordinateSpace.name))
                    )
                }
            }
            .onPreferenceChange(ChipFramePreferenceKey.self) { frame = $0 }
    }

    private func tapped() {
        guard !frame.isEmpty else { onOpen(); return }
        onOpenFlight(
            ToolFlightRequest(
                id: UUID(),
                toolID: tool.id,
                title: tool.name,
                sourceFrame: frame,
                tint: tint
            )
        )
    }
}

/// Reports a chip's frame (in the shared flight space) so the shell can fly a
/// ghost from it to the Map pill.
private struct ChipFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
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
        onOpenSettings: {},
        onAddTool: {},
        onAddSuggestedTool: { _ in },
        onOpenToolInUniverse: { _ in }
    )
    .environment(UniverseViewModel())
}
