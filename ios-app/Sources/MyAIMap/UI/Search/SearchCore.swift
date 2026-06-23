import CoreGraphics
import Foundation

/// Pure search ranking for the SearchDock. Foundation-only (no SwiftUI /
/// RealityKit) so it stays independently testable from `MyAIMapTests`,
/// matching the `UniverseLayout` pure-core pattern.
///
/// Web parity: `AIToolUniverseMap.tsx` caps search results at 6
/// (`searchResultTools = queryResultTools.slice(0, 6)`). The web filter is
/// flat; this core adds rank buckets so the dock surfaces the best matches
/// first within the same cap.
enum SearchCore {
    /// Web parity: `queryResultTools.slice(0, 6)`.
    static let maxResults = 6

    /// Ranked, capped search results.
    ///
    /// Matching is case- and diacritic-insensitive (Unicode folding via
    /// `String.folding`). Rank buckets, best first:
    /// 0. tool name has the query as a prefix
    /// 1. tool name contains the query
    /// 2. summary contains the query
    /// 3. category display name contains the query
    ///
    /// Each tool appears once, at its best rank. Order within a bucket is
    /// the input order. Buckets are concatenated and capped at
    /// ``maxResults``.
    static func results(
        for query: String,
        in tools: [Tool],
        categoryName: (ToolCategoryId) -> String,
        extraText: ((Tool) -> String)? = nil
    ) -> [Tool] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let needle = fold(trimmed)

        var buckets: [[Tool]] = [[], [], [], [], []]
        for tool in tools {
            let name = fold(tool.name)
            if name.hasPrefix(needle) {
                buckets[0].append(tool)
            } else if name.contains(needle) {
                buckets[1].append(tool)
            } else if fold(tool.summary).contains(needle) {
                buckets[2].append(tool)
            } else if let extraText, fold(extraText(tool)).contains(needle) {
                buckets[3].append(tool)
            } else if fold(categoryName(tool.category)).contains(needle) {
                buckets[4].append(tool)
            }
        }
        return Array(buckets.joined().prefix(maxResults))
    }

    private static func fold(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

/// Pure composer-state decisions for `SearchDock`. Foundation-only so the
/// rules in `INPUT_CHAT_SPEC.md` (send enablement, the single attachment
/// trigger glyph, remove availability, and access-action de-duplication) are
/// unit-testable without SwiftUI.
enum ComposerLogic {
    static let userBubbleMaxWidthRatio = 0.80
    static let assistantMessageMaxWidthRatio = 0.86
    static let composerMinHeight: CGFloat = 44
    static let composerMaxHeight: CGFloat = 148
    static let composerMaxLines = 6

    /// Send is enabled when there is text OR an attachment; disabled only when
    /// neither exists. (Spec: "Disabled only when no text AND no attachment".)
    static func canSend(hasText: Bool, hasAttachment: Bool) -> Bool {
        hasText || hasAttachment
    }

    /// The trailing action becomes Send as soon as the composer is in an
    /// active sendable state. Otherwise it remains the Add-tool plus button.
    static func showsSendButton(isFocused: Bool, hasText: Bool, hasAttachment: Bool) -> Bool {
        isFocused || hasText || hasAttachment
    }

    /// Submit uses the typed text when present. Attachment-only sends still
    /// produce a compact user message so the enabled Send button never becomes
    /// a no-op.
    static func outgoingMessageText(query: String, attachmentTitle: String?) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        guard let attachmentTitle else { return nil }
        return "Attached \(attachmentTitle.lowercased())"
    }

    /// Collapsing keeps the transcript resumable but returns map interaction to
    /// the normal navigation mode. Only active input, visible chat chrome, or an
    /// attachment affordance should keep the map suppressed.
    static func keepsChatActive(
        isFocused: Bool,
        showsConversation: Bool,
        isCollapsedWithContent: Bool,
        attachmentMenuOpen: Bool,
        hasAttachment: Bool
    ) -> Bool {
        isFocused || showsConversation || attachmentMenuOpen || hasAttachment
    }

    /// User bubbles should be compact for short text and wrap before becoming a
    /// wide block. Keep the ratio in the requested 75-82% range.
    static func userBubbleMaxWidth(availableWidth: CGFloat) -> CGFloat {
        availableWidth * userBubbleMaxWidthRatio
    }

    /// The attachment menu trigger is a single control with a stable glyph: it
    /// stays a paperclip whether empty or attached. The attached state is shown
    /// by a separate pill, never by flipping this glyph to the file/photo icon.
    /// (Spec: "No random flipping between plus / file / paperclip".)
    static func attachmentTriggerIcon(hasAttachment: Bool) -> String {
        "paperclip"
    }

    /// "Remove attachment" is offered only when an attachment exists. Its home
    /// is the floating preview's remove button (CHAT_INPUT_SPEC §3), not the
    /// attachment menu.
    static func showsRemoveAttachment(hasAttachment: Bool) -> Bool {
        hasAttachment
    }

    /// The float lane above the composer hosts at most one panel: the attachment
    /// menu OR the staged-attachment preview — never both (CHAT_INPUT_SPEC §4).
    /// The menu wins while open (state B); otherwise an attachment shows its
    /// preview (state C). Opening the menu therefore hides the preview.
    static func showsAttachmentMenu(menuOpen: Bool) -> Bool {
        menuOpen
    }

    static func showsAttachmentPreview(menuOpen: Bool, hasAttachment: Bool) -> Bool {
        hasAttachment && !menuOpen
    }

    /// Attach / Add-tool have a single home: the composer. Assistant messages
    /// never render their own duplicate access buttons; they only guide the
    /// user toward the composer controls via text. (Spec: "the SAME action
    /// never appears twice on screen at once".)
    static let rendersInMessageAccessButtons = false
}

/// Pure presentation cleanup for assistant text. The local assistant can keep
/// verbose internal structure for tests/routing, but the UI should show a short
/// answer first and move actions into real chips instead of prose.
enum AssistantResponsePresentation {
    static func prose(from text: String) -> String {
        var output: [String] = []
        var skippingActionSection = false

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("|") { continue }
            if trimmed.hasPrefix("**Next:**") || trimmed.hasPrefix("Next:") { continue }

            if isHeading(trimmed) {
                if headingTitle(trimmed) == "Action chips" {
                    skippingActionSection = true
                    continue
                }
                skippingActionSection = false
            }

            if skippingActionSection { continue }

            if let mapped = mappedHeading(trimmed) {
                if !mapped.isEmpty {
                    output.append(mapped)
                }
            } else {
                output.append(rawLine)
            }
        }

        return output
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func mappedHeading(_ line: String) -> String? {
        switch headingTitle(line) {
        case "Summary":
            return ""
        case "Recommended tools":
            return "**Recommended path**"
        case "Options":
            return "**Cost / time tradeoffs**"
        case "Caveats / tradeoffs":
            return "**Notes**"
        default:
            return nil
        }
    }

    private static func isHeading(_ line: String) -> Bool {
        headingTitle(line) != nil
    }

    private static func headingTitle(_ line: String) -> String? {
        guard line.hasPrefix("**"), line.hasSuffix("**"), line.count > 4 else { return nil }
        return String(line.dropFirst(2).dropLast(2))
    }
}
