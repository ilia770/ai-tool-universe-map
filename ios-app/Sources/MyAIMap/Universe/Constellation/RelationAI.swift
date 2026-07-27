import Foundation

/// Phase 2 — AI-resolved tool relations. Prompts the DeepSeek backend for the
/// tools most related to a given tool, validates the returned ids against the
/// catalog, and returns them for caching. Pure parsing is split out so it is
/// unit-tested without a network. Any failure (no key, offline, bad reply)
/// returns `[]` so the map silently falls back to the derived base.
enum RelationAI {

    static func prompt(for tool: Tool, in tools: [Tool], limit: Int = 6) -> String {
        let catalog = tools
            .filter { $0.id != tool.id }
            .map { "\($0.id): \($0.name)" }
            .joined(separator: "\n")
        return """
        Tool: "\(tool.name)" — \(tool.summary)
        Category: \(tool.category.rawValue), stage: \(tool.stage.rawValue)

        From the catalog below, choose up to \(limit) tools most related to it
        (alternatives, or commonly used together in a workflow). Reply with ONLY a
        JSON array of their ids, e.g. ["id-a","id-b"]. No prose.

        Catalog:
        \(catalog)
        """
    }

    /// Lenient parse: decode a JSON string array if possible, else scrape quoted
    /// tokens. Keep only ids present in `catalog`, drop `selfID`, dedupe, cap.
    static func parseRelatedIDs(from reply: String, catalog: Set<String>,
                               excluding selfID: String, limit: Int = 6) -> [String] {
        var ids: [String] = []

        if let start = reply.firstIndex(of: "["),
           let end = reply.lastIndex(of: "]"),
           start < end {
            let slice = String(reply[start...end])
            if let data = slice.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String].self, from: data) {
                ids = decoded
            }
        }
        if ids.isEmpty {
            // Fallback: scrape "quoted" tokens.
            var token = ""
            var inQuote = false
            for ch in reply {
                if ch == "\"" {
                    if inQuote { ids.append(token); token = "" }
                    inQuote.toggle()
                } else if inQuote {
                    token.append(ch)
                }
            }
        }

        var seen = Set<String>()
        var result: [String] = []
        for id in ids {
            let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed != selfID, catalog.contains(trimmed), !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
            if result.count >= limit { break }
        }
        return result
    }

    /// Async fetch via the DeepSeek backend. Returns `[]` on any failure.
    #if DEBUG
    static func relatedIDs(for tool: Tool, in tools: [Tool],
                          client: DeepSeekClient = DeepSeekClient()) async -> [String] {
        let catalog = Set(tools.map(\.id))
        do {
            let reply = try await client.reply(
                to: prompt(for: tool, in: tools),
                systemPrompt: "You map relationships between AI tools. Reply with ONLY a JSON array of tool ids."
            )
            return parseRelatedIDs(from: reply, catalog: catalog, excluding: tool.id)
        } catch {
            return []
        }
    }
    #else
    /// Provider-backed relation inference is deliberately absent from release
    /// until it can call an app-owned hosted service with server-side policy.
    static func relatedIDs(for tool: Tool, in tools: [Tool]) async -> [String] {
        []
    }
    #endif
}
