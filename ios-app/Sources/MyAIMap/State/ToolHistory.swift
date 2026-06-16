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
