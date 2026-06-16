import SwiftUI

/// ChatGPT-style "ask the map" composer pinned to the bottom in thumb
/// reach. Type a need ("найди сервис чтобы быстро построить базу данных")
/// and the on-device `QueryEngine` answers in a thread, with the matched
/// tools as cards you tap to open their brand window
/// (`UniverseViewModel.focusTool` → `RootSheet`).
///
/// iOS port of the web `FindBar.tsx`:
/// - thread height capped to ≤ 1/3 of the screen (`maxThreadFraction`),
/// - swipe-down dismiss is non-destructive (collapses the thread, keeps it),
/// - long-press on a match card peeks its summary,
/// - haptics via `BrandHaptics`, press feedback via `PressableButtonStyle`
///   (scale 0.96), all motion gated on Reduce Motion via `.brandAnimation`.
struct ChatDock: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(ChatThreadStore.self) private var thread
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var text = ""
    @State private var collapsed = false
    @State private var peekId: String?
    @State private var dragOffset: CGFloat = 0
    @FocusState private var fieldFocused: Bool

    /// Web parity: thread is capped to a third of the screen.
    private let maxThreadFraction: CGFloat = 1.0 / 3.0
    private let exampleQueries = ["build a database fast", "edit video", "research tool"]

    private var accent: Color { model.selectedCategoryModel.color.swiftUIColor }
    private var showThread: Bool { !collapsed && !thread.turns.isEmpty }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: BrandSpacing.s.value) {
                Spacer(minLength: 0)
                if showThread {
                    threadScroll
                        .frame(maxHeight: proxy.size.height * maxThreadFraction)
                        .offset(y: dragOffset)
                        .gesture(dismissDrag)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                composer
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .brandAnimation(BrandMotion.entry, value: showThread)
        .brandAnimation(BrandMotion.nudge, value: thread.turns.map(\.id))
        .onAppear { BrandHaptics.prepare(.light, .medium) }
    }

    // MARK: - Thread

    private var threadScroll: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(alignment: .leading, spacing: BrandSpacing.m.value) {
                    if thread.turns.isEmpty {
                        emptyState
                    } else {
                        ForEach(thread.turns) { turn in
                            turnRow(turn).id(turn.id)
                        }
                    }
                }
                .padding(BrandSpacing.m.value)
            }
            .scrollIndicators(.hidden)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous),
                tint: accent,
                strokeStrength: 0.12
            )
            .shadow(color: .black.opacity(0.42), radius: 18, x: 0, y: 10)
            .onChange(of: thread.turns.map(\.id)) { _, ids in
                guard let last = ids.last else { return }
                withAnimation(BrandMotion.resolved(BrandMotion.flow, reduceMotion: reduceMotion)) {
                    scroller.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }

    private func turnRow(_ turn: ChatTurn) -> some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            // The ask, right-aligned bubble.
            Text(turn.q)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, BrandSpacing.m.value)
                .padding(.vertical, BrandSpacing.s.value)
                .liquidGlass(in: Capsule(), tint: accent.opacity(0.5), strokeStrength: 0.08)
                .frame(maxWidth: .infinity, alignment: .trailing)

            // The answer.
            Text(turn.answer)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.86))

            // Tappable match cards.
            ForEach(turn.matchIds, id: \.self) { id in
                if let tool = UniverseSeed.tools.first(where: { $0.id == id }) {
                    matchCard(tool)
                }
            }
        }
    }

    private func matchCard(_ tool: Tool) -> some View {
        let category = UniverseSeed.category(tool.category)
        let isPeeking = peekId == tool.id
        return Button {
            open(tool)
        } label: {
            VStack(alignment: .leading, spacing: BrandSpacing.hair.value) {
                HStack(spacing: BrandSpacing.s.value) {
                    Circle()
                        .fill(category.color.swiftUIColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: category.color.swiftUIColor.opacity(0.6), radius: 3)
                    Text(tool.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: BrandSpacing.s.value)
                    Text(category.shortName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                if isPeeking {
                    Text(tool.summary)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .transition(.opacity)
                }
            }
            .padding(BrandSpacing.s.value)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous),
                tint: category.color.swiftUIColor,
                strokeStrength: 0.1
            )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil, pressedOpacity: 0.9))
        .onLongPressGesture(minimumDuration: 0.35) {
            BrandHaptics.fire(.medium)
            withAnimation(BrandMotion.resolved(BrandMotion.nudge, reduceMotion: reduceMotion)) {
                peekId = isPeeking ? nil : tool.id
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            Text("Ask the map")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            ForEach(exampleQueries, id: \.self) { example in
                Button {
                    text = example
                    fieldFocused = true
                    BrandHaptics.fire(.light)
                } label: {
                    Text(example)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, BrandSpacing.s.value)
                        .padding(.vertical, BrandSpacing.hair.value)
                        .liquidGlass(in: Capsule(), tint: accent.opacity(0.4), strokeStrength: 0.08)
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: BrandSpacing.s.value) {
            TextField("Ask the map…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(.subheadline)
                .foregroundStyle(.white)
                .tint(accent)
                .focused($fieldFocused)
                .submitLabel(.send)
                .onSubmit(submit)

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(canSubmit ? accent : .white.opacity(0.2)))
            }
            .buttonStyle(BouncyIconButtonStyle())
            .disabled(!canSubmit)
        }
        .padding(.horizontal, BrandSpacing.m.value)
        .padding(.vertical, BrandSpacing.s.value + BrandSpacing.hair.value)
        .liquidGlass(in: Capsule(), tint: accent.opacity(0.5), strokeStrength: 0.08)
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func submit() {
        let ask = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ask.isEmpty else { return }
        BrandHaptics.fire(.light)
        let result = QueryEngine.run(ask, in: UniverseSeed.tools)
        thread.append(query: ask, answer: result.answer, matchIds: result.matches.map(\.id))
        text = ""
        collapsed = false
    }

    private func open(_ tool: Tool) {
        BrandHaptics.fire(.medium)
        withAnimation(BrandMotion.resolved(BrandMotion.flow, reduceMotion: reduceMotion)) {
            _ = model.focusTool(tool.id)
        }
        fieldFocused = false
    }

    // MARK: - Swipe-to-dismiss (non-destructive: collapse only)

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 80 {
                    BrandHaptics.fire(.light)
                    withAnimation(BrandMotion.resolved(BrandMotion.entry, reduceMotion: reduceMotion)) {
                        collapsed = true
                        dragOffset = 0
                    }
                } else {
                    withAnimation(BrandMotion.resolved(BrandMotion.nudge, reduceMotion: reduceMotion)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ChatDock()
            .padding(16)
    }
    .environment(UniverseViewModel())
    .environment(ChatThreadStore(liveToolIds: Set(UniverseSeed.tools.map(\.id))))
    .preferredColorScheme(.dark)
}
