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
