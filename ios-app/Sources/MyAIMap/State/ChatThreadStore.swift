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
