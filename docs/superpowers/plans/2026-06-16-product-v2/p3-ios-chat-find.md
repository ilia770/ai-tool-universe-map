# P3 iOS Chat/Find Implementation Plan

> Part of the 2026-06-16 product-v2 set.

## Goal

Bring the web playground's natural-language "ask the map" experience to the iOS app. Today iOS has only `SearchDock` (substring ranking, capped at 6) — no NL query engine and no conversational chat. This part ports the web `runQuery` ranker (`src/playground/query.ts`) to a pure Swift `QueryEngine`, and adds a ChatGPT-style bottom liquid-glass composer (`ChatDock`) that:

- shows **only when no panel is active** (`sheetPresented == false` / no `selectedToolID` focus open),
- is **capped to ≤ 1/3 of the screen height**,
- accepts an NL ask (e.g. `найди сервис чтобы быстро построить базу данных` / "find me something to build a database fast"),
- answers in a **persisted conversation thread** with a short ranked answer + tappable tool-match cards,
- **opens the brand window** for a tapped match (reuses `UniverseViewModel.focusTool` → `RootSheet` → `InAppBrowserSheet`),
- supports **swipe-to-dismiss (non-destructive)**, **long-press peek** on match chips, **haptics**, **press-feedback (scale 0.96)**, and honors **Reduce Motion**.

## Architecture

```
QueryEngine.swift          pure Foundation ranker  (mirrors web query.ts; unit-tested like SearchCore)
ChatThreadStore.swift      @Observable thread state + UserDefaults persistence (mirrors loadTurns/persistTurns)
ChatTurn.swift             Codable turn model (mirrors web `Turn`)
ChatDock.swift             SwiftUI bottom composer + thread, ≤1/3 screen, liquid glass
UniverseScreen.swift       host ChatDock in the canvas overlay, gated on "no active panel"
```

- **QueryEngine** is Foundation-only and lives beside `SearchCore` (`UI/Search/`) so it is testable from `MyAIMapTests` without SwiftUI, exactly matching the `SearchCore` pure-core pattern. It ranks `[Tool]` and returns matches + a one-line answer string.
- **ChatThreadStore** is a `@MainActor @Observable` class (same pattern as `UniverseViewModel`) injected via `.environment`. It owns `turns: [ChatTurn]`, persists to `UserDefaults` (web parity for `localStorage`), caps stored turns, and drops stale match ids not in the seed.
- **ChatDock** reads `ChatThreadStore` + `UniverseViewModel`, renders the composer + scrollable thread inside `.liquidGlass`, and calls `model.focusTool(id)` to open a tool's brand window (web parity: `onOpenTool`). It is mounted in `UniverseScreen.canvas` and hidden whenever the bottom sheet is up.
- iOS has **no enriched knowledge layer yet** (P0/P1 ship that as seed JSON). For P3 the "brain" = the structured `Tool` fields (`name`, `category`, `stage`, `summary`) — the same fields `searchableText` already falls back to on web. A `knowledge:` closure param is left on `QueryEngine.run` so P1 can inject richer text later without touching call sites.

## Tech Stack

- Swift 6 (strict concurrency `complete`), SwiftUI, iOS 18 deployment target (project.yml).
- `swift-testing` (`import Testing`, `@Suite`, `@Test`, `#expect`) — matches `SearchCoreTests`.
- Reuse: `LiquidGlass` (`.liquidGlass(in:tint:strokeStrength:)`), `BrandHaptics.fire/.prepare`, `PressableButtonStyle` / `BouncyIconButtonStyle`, `BrandMotion` + `.brandAnimation`, `BrandSpacing`/`BrandRadius`/`BrandColor`, `UniverseViewModel.focusTool`.
- Build/test: `xcodegen generate` then `xcodebuild test -scheme MyAIMap -destination 'platform=iOS Simulator,name=iPhone 16'`. New source files must be added under `Sources/MyAIMap` / `Tests/MyAIMapTests` (XcodeGen picks them up via the folder globs; re-run `xcodegen generate` after creating files).

---

## Task 1 — QueryEngine (pure NL ranker)

Port `src/playground/query.ts` to Swift. Same stopwords, same `CATEGORY_HINTS`, same scoring (name match +5, haystack +2, wanted-category +3), top-5 cap, same answer-string shape.

**Files**
- Create: `ios-app/Sources/MyAIMap/UI/Search/QueryEngine.swift`
- Create: `ios-app/Tests/MyAIMapTests/QueryEngineTests.swift`

### Steps

1. Write the failing test `QueryEngineTests.swift`:

```swift
import Testing
@testable import MyAIMap

@Suite("QueryEngine — NL query ranking")
struct QueryEngineTests {

    private func makeTool(
        id: String,
        name: String,
        summary: String = "—",
        category: ToolCategoryId = .coding
    ) -> Tool {
        Tool(
            id: id, name: name, category: category, summary: summary,
            stage: .execution, orbit: .inner, angle: 0, url: nil,
            logoDomain: nil, relationIds: [], classification: nil
        )
    }

    private func run(_ q: String, _ tools: [Tool]) -> QueryEngine.Result {
        QueryEngine.run(q, in: tools)
    }

    @Test func emptyQueryReturnsNothing() {
        let tools = [makeTool(id: "a", name: "Figma")]
        #expect(run("", tools).matches.isEmpty)
        // Stopwords-only collapses to zero tokens.
        #expect(run("the to a for me", tools).matches.isEmpty)
    }

    @Test func nameMatchRanksToTop() {
        let tools = [
            makeTool(id: "linear", name: "Linear", summary: "planning"),
            makeTool(id: "figma", name: "Figma", summary: "design canvas"),
        ]
        #expect(run("figma", tools).matches.first?.id == "figma")
    }

    @Test func categoryHintBiasesResults() {
        // "database" hints the .infrastructure category (web CATEGORY_HINTS).
        let tools = [
            makeTool(id: "neon", name: "Neon", summary: "serverless postgres", category: .infrastructure),
            makeTool(id: "canva", name: "Canva", summary: "graphics", category: .design),
        ]
        let res = run("найди сервис чтобы быстро построить базу данных database", tools)
        #expect(res.matches.first?.id == "neon")
    }

    @Test func capsAtFiveMatches() {
        let tools = (0..<9).map { makeTool(id: "code-\($0)", name: "CodeAgent \($0)", category: .coding) }
        #expect(run("code agent dev build", tools).matches.count <= 5)
    }

    @Test func answerIsNonEmptyWhenMatched() {
        let tools = [makeTool(id: "neon", name: "Neon", summary: "serverless postgres database")]
        let res = run("database", tools)
        #expect(!res.matches.isEmpty)
        #expect(!res.answer.isEmpty)
        #expect(res.answer.contains("Neon"))
    }

    @Test func noMatchAnswerSuggestsAdding() {
        let tools = [makeTool(id: "neon", name: "Neon")]
        let res = run("zzzqqq xyzzy", tools)
        #expect(res.matches.isEmpty)
        #expect(res.answer.contains("+"))
    }
}
```

2. Run the suite, confirm it fails to compile (no `QueryEngine`):
   `xcodegen generate && xcodebuild test -scheme MyAIMap -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MyAIMapTests/QueryEngineTests`

3. Minimal implementation `QueryEngine.swift`:

```swift
import Foundation

/// Pure natural-language query engine for the ChatDock. Foundation-only
/// (no SwiftUI / RealityKit) so it stays independently testable from
/// `MyAIMapTests`, matching the `SearchCore` and `UniverseLayout`
/// pure-core pattern.
///
/// Direct port of the web playground's `src/playground/query.ts`: tokenise
/// the ask, drop stopwords, map intent words to category hints, score
/// every tool, and build a one-line answer from the top match. The "brain"
/// is the structured seed data + this ranker — no backend, instant.
enum QueryEngine {

    /// Web parity: `matches = scored.slice(0, 5)`.
    static let maxResults = 5

    struct Result: Sendable {
        let matches: [Tool]
        let answer: String
    }

    /// Tokens dropped before scoring (web parity: `STOPWORDS`). English +
    /// the few Russian fillers the demo asks use, so a Cyrillic ask like
    /// "найди сервис чтобы быстро построить базу данных" reduces to the
    /// load-bearing nouns.
    private static let stopwords: Set<String> = [
        "a", "an", "the", "to", "for", "me", "my", "i", "we", "find", "show",
        "get", "need", "want", "which", "what", "that", "can", "with", "and",
        "or", "of", "is", "are", "how", "do", "use", "using", "best", "good",
        "service", "services", "tool", "tools", "app", "apps", "some", "any",
        "quickly", "fast",
        // Russian fillers (parity with the demo asks).
        "найди", "найти", "сервис", "сервисы", "чтобы", "быстро", "мне", "что",
        "как", "для",
    ]

    /// Word → category hint, so intent words steer ranking
    /// (web parity: `CATEGORY_HINTS`). `.infrastructure` covers the
    /// database/backend/deploy asks.
    private static let categoryHints: [String: ToolCategoryId] = [
        "code": .coding, "coding": .coding, "dev": .coding, "developer": .coding,
        "agent": .coding, "app": .coding, "build": .coding, "programming": .coding,
        "ide": .coding,
        "design": .design, "ui": .design, "ux": .design, "figma": .design,
        "logo": .design, "brand": .design,
        "research": .research, "search": .research, "data": .research,
        "knowledge": .research, "answer": .research,
        "image": .media, "video": .media, "audio": .media, "music": .media,
        "media": .media, "art": .media,
        "social": .distribution, "marketing": .distribution,
        "content": .distribution, "post": .distribution,
        "database": .infrastructure, "db": .infrastructure, "backend": .infrastructure,
        "deploy": .infrastructure, "host": .infrastructure, "infra": .infrastructure,
        "server": .infrastructure, "api": .infrastructure,
        // Cyrillic intent words used by the demo asks.
        "базу": .infrastructure, "данных": .infrastructure, "базаданных": .infrastructure,
    ]

    /// Rank tools for a natural-language ask and build a short answer.
    /// `knowledge` returns extra searchable text for a tool id (P1 enriched
    /// layer); P3 passes a no-op, matching the web `searchableText` fallback
    /// to seed fields only.
    static func run(
        _ text: String,
        in tools: [Tool],
        knowledge: (String) -> String = { _ in "" }
    ) -> Result {
        let qTokens = tokens(text)
        guard !qTokens.isEmpty else { return Result(matches: [], answer: "") }

        let wantedCategories = Set(qTokens.compactMap { categoryHints[$0] })

        let scored: [(tool: Tool, score: Int)] = tools.map { tool in
            let hay = searchable(tool, knowledge: knowledge)
            let name = fold(tool.name)
            var score = 0
            for t in qTokens {
                if name.contains(t) { score += 5 }
                else if hay.contains(t) { score += 2 }
            }
            if wantedCategories.contains(tool.category) { score += 3 }
            return (tool, score)
        }
        .filter { $0.score > 0 }
        .sorted { $0.score > $1.score }

        let matches = scored.prefix(maxResults).map(\.tool)
        guard let top = matches.first else {
            return Result(
                matches: [],
                answer: "No tool in the map matches that yet. Try the + button to add one — the classifier will place it."
            )
        }

        let why = top.summary.isEmpty ? "" : " — \(top.summary)"
        let others = matches.dropFirst().prefix(2).map(\.name)
        let tail = others.isEmpty ? "" : " Also worth a look: \(others.joined(separator: ", "))."
        return Result(matches: matches, answer: "\(top.name)\(why).\(tail)")
    }

    // MARK: - Internals

    private static func tokens(_ text: String) -> [String] {
        fold(text)
            .map { ($0.isLetter || $0.isNumber) ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 1 && !stopwords.contains($0) }
    }

    private static func searchable(_ tool: Tool, knowledge: (String) -> String) -> String {
        var parts = [tool.name, String(describing: tool.category),
                     tool.stage.rawValue, tool.summary]
        let extra = knowledge(tool.id)
        if !extra.isEmpty { parts.append(extra) }
        return fold(parts.joined(separator: " "))
    }

    private static func fold(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
```

4. Re-run the suite — all `QueryEngineTests` pass.
5. Commit: `feat(ios): port web NL query engine to Swift QueryEngine`

---

## Task 2 — ChatTurn model + ChatThreadStore (persisted thread)

Port `Turn` + `loadTurns`/`persistTurns` (web `FindBar.tsx`). Persist via `UserDefaults` (web parity: `localStorage`, key `playground.findbar.turns.v1`). Cap stored turns, clamp string lengths, drop match ids not in the live seed.

**Files**
- Create: `ios-app/Sources/MyAIMap/State/ChatTurn.swift`
- Create: `ios-app/Sources/MyAIMap/State/ChatThreadStore.swift`
- Create: `ios-app/Tests/MyAIMapTests/ChatThreadStoreTests.swift`

### Steps

1. Write the failing test `ChatThreadStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import MyAIMap

@Suite("ChatThreadStore — persisted conversation thread")
@MainActor
struct ChatThreadStoreTests {

    /// Isolated defaults per test so persistence assertions don't leak.
    private func makeDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "chat.test.\(UUID().uuidString)")!
        return d
    }

    private let liveIds: Set<String> = ["neon", "figma"]

    @Test func startsEmpty() {
        let store = ChatThreadStore(defaults: makeDefaults(), liveToolIds: liveIds)
        #expect(store.turns.isEmpty)
    }

    @Test func appendAssignsIncreasingIds() {
        let store = ChatThreadStore(defaults: makeDefaults(), liveToolIds: liveIds)
        store.append(query: "a", answer: "x", matchIds: ["neon"])
        store.append(query: "b", answer: "y", matchIds: ["figma"])
        #expect(store.turns.map(\.id) == [1, 2])
    }

    @Test func appendDropsStaleMatchIds() {
        let store = ChatThreadStore(defaults: makeDefaults(), liveToolIds: liveIds)
        store.append(query: "q", answer: "a", matchIds: ["neon", "ghost"])
        #expect(store.turns.first?.matchIds == ["neon"])
    }

    @Test func persistsAndReloads() {
        let defaults = makeDefaults()
        let a = ChatThreadStore(defaults: defaults, liveToolIds: liveIds)
        a.append(query: "build a database", answer: "Neon.", matchIds: ["neon"])
        let b = ChatThreadStore(defaults: defaults, liveToolIds: liveIds)
        #expect(b.turns.count == 1)
        #expect(b.turns.first?.q == "build a database")
        #expect(b.turns.first?.matchIds == ["neon"])
    }

    @Test func clearIsNonDestructiveUntilCommitted() {
        // Web parity: dismiss collapses; clear() empties + persists empty.
        let defaults = makeDefaults()
        let store = ChatThreadStore(defaults: defaults, liveToolIds: liveIds)
        store.append(query: "q", answer: "a", matchIds: [])
        store.clear()
        #expect(store.turns.isEmpty)
        let reloaded = ChatThreadStore(defaults: defaults, liveToolIds: liveIds)
        #expect(reloaded.turns.isEmpty)
    }

    @Test func capsStoredTurns() {
        let store = ChatThreadStore(defaults: makeDefaults(), liveToolIds: liveIds)
        for i in 0..<(ChatThreadStore.maxStoredTurns + 5) {
            store.append(query: "q\(i)", answer: "a", matchIds: [])
        }
        #expect(store.turns.count == ChatThreadStore.maxStoredTurns)
    }
}
```

2. Run, confirm failure (no types). `... -only-testing:MyAIMapTests/ChatThreadStoreTests`

3. Implement `ChatTurn.swift`:

```swift
import Foundation

/// One question/answer exchange in the ChatDock thread. Codable mirror of
/// the web playground's `Turn` (`FindBar.tsx`), persisted by
/// `ChatThreadStore`. `q` is the user's ask, `answer` the engine's reply,
/// `matchIds` the ranked tool ids whose cards the user can tap to open.
struct ChatTurn: Identifiable, Codable, Sendable, Equatable {
    let id: Int
    let q: String
    let answer: String
    let matchIds: [String]
}
```

4. Implement `ChatThreadStore.swift`:

```swift
import Foundation
import Observation

/// Owns the ChatDock conversation thread and persists it across the
/// composer being hidden (a tool window covers it) and app launches —
/// `@MainActor @Observable`, injected via `.environment`, matching the
/// `UniverseViewModel` pattern.
///
/// Web parity (`FindBar.tsx` `loadTurns`/`persistTurns`): cap stored turns,
/// clamp the query/answer length, drop match ids no longer in the seed, and
/// store under a versioned key. Backed by `UserDefaults` instead of
/// `localStorage`. Dismiss is non-destructive in the UI (collapse); only
/// `clear()` empties the thread.
@MainActor
@Observable
final class ChatThreadStore {

    static let storageKey = "chatdock.turns.v1"
    static let maxStoredTurns = 20
    static let maxQueryChars = 500
    static let maxAnswerChars = 900
    static let maxMatchIds = 8

    private(set) var turns: [ChatTurn] = []

    private let defaults: UserDefaults
    private let liveToolIds: Set<String>
    private var nextId = 1

    init(defaults: UserDefaults = .standard, liveToolIds: Set<String>) {
        self.defaults = defaults
        self.liveToolIds = liveToolIds
        self.turns = load()
        self.nextId = (turns.map(\.id).max() ?? 0) + 1
    }

    /// Append a turn, clamping fields and dropping stale match ids.
    func append(query: String, answer: String, matchIds: [String]) {
        let turn = ChatTurn(
            id: nextId,
            q: String(query.prefix(Self.maxQueryChars)),
            answer: String(answer.prefix(Self.maxAnswerChars)),
            matchIds: Array(matchIds.filter(liveToolIds.contains).prefix(Self.maxMatchIds))
        )
        nextId += 1
        turns.append(turn)
        if turns.count > Self.maxStoredTurns {
            turns.removeFirst(turns.count - Self.maxStoredTurns)
        }
        persist()
    }

    /// Empty the thread and persist the empty state (web parity:
    /// `persistTurns([])` removes the key).
    func clear() {
        turns.removeAll()
        defaults.removeObject(forKey: Self.storageKey)
    }

    // MARK: - Persistence

    private func persist() {
        guard !turns.isEmpty else {
            defaults.removeObject(forKey: Self.storageKey)
            return
        }
        let capped = Array(turns.suffix(Self.maxStoredTurns))
        if let data = try? JSONEncoder().encode(capped) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    private func load() -> [ChatTurn] {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let decoded = try? JSONDecoder().decode([ChatTurn].self, from: data)
        else { return [] }
        return decoded
            .suffix(Self.maxStoredTurns)
            .map { turn in
                ChatTurn(
                    id: turn.id,
                    q: String(turn.q.prefix(Self.maxQueryChars)),
                    answer: String(turn.answer.prefix(Self.maxAnswerChars)),
                    matchIds: Array(turn.matchIds.filter(liveToolIds.contains).prefix(Self.maxMatchIds))
                )
            }
    }
}
```

5. Re-run — all `ChatThreadStoreTests` pass.
6. Commit: `feat(ios): persisted ChatThreadStore + ChatTurn model`

---

## Task 3 — ChatDock view (composer + thread, ≤1/3 screen, liquid glass)

The bottom liquid-glass composer + scrollable thread. Mirrors `FindBar.tsx` interactions: submit runs `QueryEngine`, appends a turn, auto-scrolls; match cards open the brand window; swipe-down dismisses (non-destructive collapse); long-press peeks a match; haptics + Reduce Motion throughout. Thread area capped to ≤ 1/3 of screen height.

**Files**
- Create: `ios-app/Sources/MyAIMap/UI/Chat/ChatDock.swift`

### Steps

1. Write the implementation `ChatDock.swift`:

```swift
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
```

2. Build to confirm the view compiles:
   `xcodegen generate && xcodebuild build -scheme MyAIMap -destination 'platform=iOS Simulator,name=iPhone 16'`

3. Verify `BrandRadius.nested` / `BrandRadius.card` / `BrandSpacing.hair`/`.s`/`.m` exist (used by `SearchDock`/`ToolDetailSection`). If `BrandRadius.nested` is absent, substitute the radius `ToolDetailSection` uses for nested rows — do not invent a new token.
4. Commit: `feat(ios): ChatDock bottom chat composer + thread`

---

## Task 4 — Host ChatDock in UniverseScreen, gated on "no active panel"

Mount `ChatDock` in the canvas overlay so it shows only when the bottom sheet is **not** presented (web parity: the FindBar hides when a tool window opens). Provide the `ChatThreadStore` via `.environment`.

**Files**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift`
- Modify: `ios-app/Sources/MyAIMap/MyAIMapApp.swift` (inject `ChatThreadStore` if the app root injects shared stores; otherwise inject locally in `UniverseScreen`)

### Steps

1. In `UniverseScreen`, add the store and render `ChatDock` in the overlay stack, gated on `!sheetPresented`. Add near the other `@State`:

```swift
@State private var chatThread = ChatThreadStore(liveToolIds: Set(UniverseSeed.tools.map(\.id)))
```

2. In `canvas`, replace the bottom `Spacer(minLength: 0)` region so `ChatDock` sits above the rail and only when no panel is active. Inside the overlay `VStack`, change:

```swift
                Spacer(minLength: 0)
```

to:

```swift
                Spacer(minLength: 0)
                if !sheetPresented {
                    ChatDock()
                        .environment(chatThread)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
```

3. Wrap the `sheetPresented` toggle in `.task`/`onAppear` (line ~60) so the dock animates in/out: ensure the existing `withAnimation` paths that set `sheetPresented` use `BrandMotion.entry`. (The sheet is opened in `onAppear`; for P3 the dock is shown whenever the user dismisses the sheet to the smallest detent — if the app keeps the sheet always-presented at `.height(118)`, gate instead on `model.selection.selectedToolID == nil` OR a new `isPanelActive` computed flag. Use whichever the current screen treats as "no active panel"; do not add a second source of truth.)

4. Build and run on simulator; manually verify:
   - With no tool focused, ChatDock is visible at the bottom; typing "build a database fast" + send appends a turn with tappable matches.
   - Tapping a match opens the brand window (`RootSheet`) and hides the dock.
   - Swiping the thread down collapses it (turns persist; relaunch shows them).
   - Long-press a match card peeks its summary.
   - With Reduce Motion on (Settings → Accessibility), transitions are near-instant.

   `xcodebuild build -scheme MyAIMap -destination 'platform=iOS Simulator,name=iPhone 16'`

5. Run the full test suite to confirm no regressions:
   `xcodebuild test -scheme MyAIMap -destination 'platform=iOS Simulator,name=iPhone 16'`
6. Commit: `feat(ios): mount ChatDock in UniverseScreen, gated on no active panel`

---

## Verification checklist (success criteria)

- [ ] `QueryEngineTests`, `ChatThreadStoreTests`, and the existing suites all pass.
- [ ] NL ask (incl. Cyrillic demo ask) returns ranked matches; database ask surfaces `.infrastructure` tools.
- [ ] Thread persists across relaunch (UserDefaults) and across opening a tool window.
- [ ] ChatDock thread is capped to ≤ 1/3 screen height (`GeometryReader` fraction).
- [ ] Tapping a match opens the brand window via `focusTool`.
- [ ] Swipe-down dismiss is non-destructive (collapse, turns kept); long-press peeks; haptics fire; press scale 0.96.
- [ ] Reduce Motion collapses animations (via `BrandMotion.resolved` / `.brandAnimation`).
- [ ] ChatDock is hidden whenever a panel/tool window is active.
