# P4 iOS History Implementation Plan

> Part of the 2026-06-16 product-v2 set.

## Goal

Bring the web playground's "Recently added" history to iOS. The web build
(`src/playground/FindBar.tsx:196`) derives history with
`tools.filter((t) => t.userAdded).slice(-6).reverse()` and renders tappable
chips that call `openTool(id)`. iOS currently has **no** add/delete tool path
and **no** history surface. This plan adds a small, observable history store
that records **added** and **deleted** tool events, surfaces it as a row of
liquid-glass chips (a "quick strip" above the `SearchDock`), and routes a chip
tap to `model.focusTool(id)` — exactly mirroring the web `openTool` behaviour.
Each chip uses tap (open), long-press (peek/undo-delete affordance via context
menu), `PressableButtonStyle` (scale 0.96), `BrandMotion.nudge` micro-animations
and `BrandHaptics`. Reduce Motion is honoured through the existing
`PressableButtonStyle` / `brandAnimation` machinery.

Scope is **iOS only**. The web reference is the source of truth; no web files
are modified.

## Architecture

- **`ToolHistory` (value type)** — a pure, `Codable`, `Sendable` event log:
  an ordered array of `ToolHistoryEvent { id, toolID, kind (.added/.deleted),
  timestamp }`. Pure logic (record, recents, distinct-by-tool) lives here so it
  is unit-testable with no UI or `@MainActor` dependency, matching the
  `SearchCore` / `UniverseSelection` split already used in the codebase.
- **`UniverseViewModel`** (`@Observable`, single source of truth) gains a
  `private(set) var history: ToolHistory` plus intents `recordAdded(_:)`,
  `recordDeleted(_:)`, and a derived `recentHistory` array (last 6, most-recent
  first, mirroring the web `slice(-6).reverse()`). It already owns `focusTool`,
  which the chip strip reuses to open a brand's tool window.
- **`HistoryStrip` (View)** — a horizontal scroll of liquid-glass chips placed
  in `UniverseScreen` directly under `SearchDock`. Tap → `focusTool`;
  long-press → context menu ("Open", and "Restore"/"Remove" depending on the
  event kind). Hidden entirely when history is empty (web parity: the chip row
  only shows when `history.length > 0`).
- **Persistence** — `ToolHistory` round-trips through `UserDefaults` via a tiny
  `HistoryStore` helper so recents survive relaunch. `UniverseViewModel` loads
  on init and saves on every mutation. Persistence stays out of `ToolHistory`
  itself (kept pure) — the helper is the only `Foundation.UserDefaults`
  touch-point, consistent with how the codebase isolates side effects.

Note: a full add/delete tool **intake** flow is a separate product-v2 part. This
plan models the history events and the `recordAdded` / `recordDeleted` intents;
they are exercised by tests now and wired to the real intake when it lands. P1
(Settings → History tab) is not yet in the tree — the chip strip is the
shippable surface; a one-line hook for the P1 tab is noted at the end.

## Tech Stack

Swift 6 / SwiftUI, `@Observable` (Observation), Swift Testing (`import Testing`,
`@Test`, `#expect`), `UserDefaults`, existing brand primitives:
`liquidGlass(in:tint:)`, `PressableButtonStyle`, `BrandHaptics`,
`BrandMotion.nudge`/`.flow`, `brandAnimation`.

---

## Task 1 — `ToolHistory` pure event log

**Files**
- Create: `ios-app/Sources/MyAIMap/State/ToolHistory.swift`
- Create: `ios-app/Tests/MyAIMapTests/ToolHistoryTests.swift`

### Steps

1. Write the failing test `ios-app/Tests/MyAIMapTests/ToolHistoryTests.swift`:

```swift
import Foundation
import Testing
@testable import MyAIMap

@Suite("ToolHistory — pure event log")
struct ToolHistoryTests {

    @Test func recordingAddedAppendsAnEvent() {
        var history = ToolHistory()
        history.record(toolID: "figma", kind: .added)
        #expect(history.events.count == 1)
        #expect(history.events[0].toolID == "figma")
        #expect(history.events[0].kind == .added)
    }

    @Test func recentsAreMostRecentFirstAndCapped() {
        // Web parity: tools.filter(userAdded).slice(-6).reverse().
        var history = ToolHistory()
        for i in 0..<8 { history.record(toolID: "tool-\(i)", kind: .added) }
        let recents = history.recents(limit: 6)
        #expect(recents.count == 6)
        #expect(recents.first?.toolID == "tool-7")
        #expect(recents.last?.toolID == "tool-2")
    }

    @Test func recentsCollapseRepeatedToolToItsLatestEvent() {
        // A tool added then deleted shows once, with the latest (deleted) kind.
        var history = ToolHistory()
        history.record(toolID: "figma", kind: .added)
        history.record(toolID: "midjourney", kind: .added)
        history.record(toolID: "figma", kind: .deleted)
        let recents = history.recents(limit: 6)
        #expect(recents.map(\.toolID) == ["figma", "midjourney"])
        #expect(recents.first?.kind == .deleted)
    }

    @Test func roundTripsThroughCodable() throws {
        var history = ToolHistory()
        history.record(toolID: "figma", kind: .added)
        let data = try JSONEncoder().encode(history)
        let decoded = try JSONDecoder().decode(ToolHistory.self, from: data)
        #expect(decoded.events == history.events)
    }
}
```

2. Run — it fails to compile (`ToolHistory` does not exist):

```bash
xcodebuild test -project ios-app/MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:MyAIMapTests/ToolHistoryTests 2>&1 | tail -25
```

3. Minimal implementation `ios-app/Sources/MyAIMap/State/ToolHistory.swift`:

```swift
import Foundation

/// Pure, testable history of tool add/delete events. Mirrors the web
/// playground's "Recently added" log (`FindBar.tsx:196`,
/// `tools.filter(userAdded).slice(-6).reverse()`), extended to also track
/// deletions. No UI, no persistence, no `@MainActor` — side effects live in
/// `HistoryStore`, exactly like `SearchCore` keeps ranking logic pure.
struct ToolHistory: Codable, Equatable, Sendable {

    enum Kind: String, Codable, Sendable {
        case added
        case deleted
    }

    struct Event: Identifiable, Codable, Equatable, Sendable {
        let id: UUID
        let toolID: String
        let kind: Kind
        let timestamp: Date
    }

    private(set) var events: [Event] = []

    /// Append a new event. Newest events live at the end of `events`.
    mutating func record(toolID: String, kind: Kind, at date: Date = Date()) {
        events.append(Event(id: UUID(), toolID: toolID, kind: kind, timestamp: date))
    }

    /// Most-recent-first, de-duplicated to one entry per tool (its latest
    /// event), capped at `limit`. Matches the web `slice(-6).reverse()` shape
    /// but collapses repeats so a tool re-added/deleted never floods the strip.
    func recents(limit: Int = 6) -> [Event] {
        var seen = Set<String>()
        var out: [Event] = []
        for event in events.reversed() {
            guard !seen.contains(event.toolID) else { continue }
            seen.insert(event.toolID)
            out.append(event)
            if out.count == limit { break }
        }
        return out
    }
}
```

4. Run the same test command — expect green.

5. Commit:

```bash
git add ios-app/Sources/MyAIMap/State/ToolHistory.swift \
        ios-app/Tests/MyAIMapTests/ToolHistoryTests.swift
git commit -m "$(cat <<'EOF'
P4 iOS history: pure ToolHistory event log

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 — `HistoryStore` persistence helper

**Files**
- Create: `ios-app/Sources/MyAIMap/State/HistoryStore.swift`
- Create: `ios-app/Tests/MyAIMapTests/HistoryStoreTests.swift`

### Steps

1. Write the failing test `ios-app/Tests/MyAIMapTests/HistoryStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import MyAIMap

@Suite("HistoryStore — UserDefaults persistence")
struct HistoryStoreTests {

    private func freshDefaults() -> UserDefaults {
        let suite = "HistoryStoreTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func loadReturnsEmptyHistoryWhenNothingStored() {
        let store = HistoryStore(defaults: freshDefaults())
        #expect(store.load().events.isEmpty)
    }

    @Test func savedHistoryLoadsBack() {
        let defaults = freshDefaults()
        let store = HistoryStore(defaults: defaults)
        var history = ToolHistory()
        history.record(toolID: "figma", kind: .added)
        store.save(history)
        #expect(HistoryStore(defaults: defaults).load() == history)
    }

    @Test func corruptDataLoadsAsEmptyHistory() {
        let defaults = freshDefaults()
        defaults.set(Data("not json".utf8), forKey: HistoryStore.key)
        #expect(HistoryStore(defaults: defaults).load().events.isEmpty)
    }
}
```

2. Run (fails — no `HistoryStore`):

```bash
xcodebuild test -project ios-app/MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:MyAIMapTests/HistoryStoreTests 2>&1 | tail -25
```

3. Minimal implementation `ios-app/Sources/MyAIMap/State/HistoryStore.swift`:

```swift
import Foundation

/// The only `UserDefaults` touch-point for tool history. Keeps `ToolHistory`
/// pure: this helper owns encode/decode + the storage key, and degrades to an
/// empty log on missing or corrupt data (never throws into the view-model).
struct HistoryStore {
    static let key = "com.myaimap.toolHistory.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ToolHistory {
        guard let data = defaults.data(forKey: Self.key),
              let history = try? JSONDecoder().decode(ToolHistory.self, from: data)
        else { return ToolHistory() }
        return history
    }

    func save(_ history: ToolHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
```

4. Run the same test command — expect green.

5. Commit:

```bash
git add ios-app/Sources/MyAIMap/State/HistoryStore.swift \
        ios-app/Tests/MyAIMapTests/HistoryStoreTests.swift
git commit -m "$(cat <<'EOF'
P4 iOS history: HistoryStore UserDefaults persistence

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 — Wire history into `UniverseViewModel`

**Files**
- Modify: `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift`
- Modify: `ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift`

### Steps

1. Add failing tests to `ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift`
   (append inside the existing `struct UniverseViewModelTests`, before the
   closing brace):

```swift
    @Test func recordingAddedSurfacesInRecentHistory() {
        let model = UniverseViewModel(history: ToolHistory(), historyStore: nil)
        model.recordAdded("figma")
        #expect(model.recentHistory.first?.toolID == "figma")
        #expect(model.recentHistory.first?.kind == .added)
    }

    @Test func recentHistoryIsCappedAtSixMostRecentFirst() {
        let model = UniverseViewModel(history: ToolHistory(), historyStore: nil)
        for i in 0..<8 { model.recordAdded("tool-\(i)") }
        #expect(model.recentHistory.count == 6)
        #expect(model.recentHistory.first?.toolID == "tool-7")
    }

    @Test func recordingDeletedKeepsToolInHistoryMarkedDeleted() {
        let model = UniverseViewModel(history: ToolHistory(), historyStore: nil)
        model.recordAdded("figma")
        model.recordDeleted("figma")
        #expect(model.recentHistory.first?.toolID == "figma")
        #expect(model.recentHistory.first?.kind == .deleted)
    }
```

2. Run (fails — no `recordAdded` / `recentHistory` / new init):

```bash
xcodebuild test -project ios-app/MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:MyAIMapTests/UniverseViewModelTests 2>&1 | tail -25
```

3. Edit `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift`. Add stored
   state + an init that accepts an optional store (tests pass `nil` to skip
   persistence). Insert after the `searchQuery` property (line 15):

```swift
    private(set) var history: ToolHistory
    private let historyStore: HistoryStore?

    init(history: ToolHistory? = nil, historyStore: HistoryStore? = HistoryStore()) {
        self.historyStore = historyStore
        self.history = history ?? historyStore?.load() ?? ToolHistory()
    }
```

   Add the derived value next to the other `// MARK: - Derived state`
   computed vars:

```swift
    /// Web parity: FindBar.tsx:196 `tools.filter(userAdded).slice(-6).reverse()`.
    /// Most-recent-first, de-duplicated per tool, capped at six.
    var recentHistory: [ToolHistory.Event] {
        history.recents(limit: 6)
    }
```

   Add the intents in the `// MARK: - Intents` section:

```swift
    /// Record that a tool was added to the universe. Persists immediately so
    /// the strip survives relaunch.
    func recordAdded(_ toolID: String) {
        history.record(toolID: toolID, kind: .added)
        historyStore?.save(history)
    }

    /// Record that a tool was removed from the universe.
    func recordDeleted(_ toolID: String) {
        history.record(toolID: toolID, kind: .deleted)
        historyStore?.save(history)
    }
```

4. Run the same test command — expect green (existing tests still pass because
   the new init params default to the old zero-arg behaviour).

5. Commit:

```bash
git add ios-app/Sources/MyAIMap/State/UniverseViewModel.swift \
        ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift
git commit -m "$(cat <<'EOF'
P4 iOS history: record add/delete events in UniverseViewModel

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 — `HistoryStrip` liquid-glass chip row

**Files**
- Create: `ios-app/Sources/MyAIMap/UI/Search/HistoryStrip.swift`
- Create: `ios-app/Tests/MyAIMapTests/HistoryStripModelTests.swift`

### Steps

1. The view itself is gesture/render glue; the *labelling* logic (chip title +
   accessibility label + which menu actions apply) is pure and gets a test.
   Write `ios-app/Tests/MyAIMapTests/HistoryStripModelTests.swift`:

```swift
import Testing
@testable import MyAIMap

@Suite("HistoryChipModel — chip presentation logic")
@MainActor
struct HistoryStripModelTests {

    private var figmaID: String {
        UniverseSeed.tools.first(where: { $0.id == "figma" })?.id
            ?? UniverseSeed.tools[0].id
    }

    @Test func chipUsesSeedToolName() {
        let tool = UniverseSeed.tools.first { $0.id == figmaID }!
        let event = ToolHistory.Event(id: .init(), toolID: figmaID,
                                      kind: .added, timestamp: .init())
        let chip = HistoryChipModel(event: event)
        #expect(chip.title == tool.name)
        #expect(chip.isDeleted == false)
    }

    @Test func deletedEventIsMarkedAndAccessible() {
        let event = ToolHistory.Event(id: .init(), toolID: figmaID,
                                      kind: .deleted, timestamp: .init())
        let chip = HistoryChipModel(event: event)
        #expect(chip.isDeleted)
        #expect(chip.accessibilityLabel.contains("Removed"))
    }

    @Test func unknownToolFallsBackToRawID() {
        let event = ToolHistory.Event(id: .init(), toolID: "ghost-tool",
                                      kind: .added, timestamp: .init())
        let chip = HistoryChipModel(event: event)
        #expect(chip.title == "ghost-tool")
    }
}
```

2. Run (fails — no `HistoryChipModel`):

```bash
xcodebuild test -project ios-app/MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:MyAIMapTests/HistoryStripModelTests 2>&1 | tail -25
```

3. Implement `ios-app/Sources/MyAIMap/UI/Search/HistoryStrip.swift`:

```swift
import SwiftUI

/// Pure presentation model for one history chip. Resolves the tool name from
/// the seed (falling back to the raw id) and exposes the accessibility label /
/// deleted flag the view renders. Kept out of the View so it is unit-testable.
@MainActor
struct HistoryChipModel: Identifiable {
    let event: ToolHistory.Event

    var id: String { event.id.uuidString }
    var isDeleted: Bool { event.kind == .deleted }

    var title: String {
        UniverseSeed.tools.first { $0.id == event.toolID }?.name ?? event.toolID
    }

    var accessibilityLabel: String {
        isDeleted ? "Removed \(title), tap to reopen" : "Recently added \(title), tap to open"
    }
}

/// Horizontal row of liquid-glass history chips, shown above the SearchDock.
/// Web parity: FindBar.tsx renders the "Recently added" chips only when
/// `history.length > 0` and routes a tap to `openTool(id)`; here that is
/// `model.focusTool`. Tap = open, long-press = context menu (Open + Restore/
/// Remove). The whole strip collapses when history is empty.
struct HistoryStrip: View {
    @Environment(UniverseViewModel.self) private var model

    private var chips: [HistoryChipModel] {
        model.recentHistory.map(HistoryChipModel.init)
    }

    var body: some View {
        if !chips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recently added")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips) { chip in
                            chipButton(chip)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .brandAnimation(BrandMotion.flow, value: chips.map(\.id))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func chipButton(_ chip: HistoryChipModel) -> some View {
        Button {
            openTool(chip.event.toolID)
        } label: {
            HStack(spacing: 6) {
                if chip.isDeleted {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(chip.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(chip.isDeleted ? 0.62 : 0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlass(in: Capsule(), strokeStrength: 0.1)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(chip.accessibilityLabel)
        .contextMenu {
            Button {
                openTool(chip.event.toolID)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            if chip.isDeleted {
                Button {
                    model.recordAdded(chip.event.toolID)
                    openTool(chip.event.toolID)
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button(role: .destructive) {
                    model.recordDeleted(chip.event.toolID)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    /// Mirrors UniverseScreen.focusToolFromMap: medium haptic on a real jump,
    /// light tick when the tool is already selected; animates with BrandMotion.
    private func openTool(_ id: String) {
        guard model.selection.selectedToolID != id else {
            BrandHaptics.fire(.light)
            return
        }
        BrandHaptics.fire(.medium)
        withAnimation(BrandMotion.flow) {
            _ = model.focusTool(id)
        }
    }
}
```

4. Run the same test command — expect green.

5. Commit:

```bash
git add ios-app/Sources/MyAIMap/UI/Search/HistoryStrip.swift \
        ios-app/Tests/MyAIMapTests/HistoryStripModelTests.swift
git commit -m "$(cat <<'EOF'
P4 iOS history: liquid-glass HistoryStrip chip row

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5 — Mount `HistoryStrip` in `UniverseScreen`

**Files**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift`

### Steps

1. There is no view-render unit test harness for `UniverseScreen` (it composes
   RealityKit); the verifiable goal is "the project still builds and the full
   suite is green with the strip mounted". Place `HistoryStrip` directly under
   `SearchDock` in the `canvas` overlay `VStack`. Edit lines 88-89:

```swift
                SearchDock()
                    .padding(.top, 10)
                HistoryStrip()
                    .padding(.top, 10)
```

2. Build + run the full test suite (no regressions, project compiles with the
   new view in the tree):

```bash
xcodebuild test -project ios-app/MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30
```

3. Commit:

```bash
git add ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift
git commit -m "$(cat <<'EOF'
P4 iOS history: mount HistoryStrip under SearchDock

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## P1 hook (when the Settings → History tab lands)

The same data powers the future Settings History tab. That view should read
`model.history.events` (full log, newest-last) rather than `recentHistory`
(capped strip), reuse `HistoryChipModel` for labelling, and route taps through
the same `model.focusTool(id)` path. No store changes are required — only a new
view consuming the already-exposed `history` property.
