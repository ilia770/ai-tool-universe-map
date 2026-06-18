import Testing
@testable import MyAIMap

/// Pure-logic tests for the detail-card logo fallback. Mirrors the web
/// app's `getToolInitials` rules (src/lib/tool-logos.ts) so the iOS
/// monogram fallback stays at parity.
@Suite("ToolMonogram — logo fallback initials")
struct ToolMonogramTests {

    @Test func twoWordNameUsesFirstLetterOfEachWord() {
        #expect(ToolMonogram.initials(for: "Claude Code") == "CC")
        #expect(ToolMonogram.initials(for: "Founder OS") == "OS")
    }

    @Test func allCapsTokenWinsAndCapsAtThree() {
        // A pure all-caps/numeric token (2–4 chars) is preferred whole, capped
        // at 3. "GPT-4" is not pure (it contains a hyphen) so it does NOT win.
        #expect(ToolMonogram.initials(for: "Founder OS") == "OS")
        #expect(ToolMonogram.initials(for: "ABCD map") == "ABC")
    }

    @Test func singleWordNameUsesFirstLetter() {
        #expect(ToolMonogram.initials(for: "Cursor") == "C")
        #expect(ToolMonogram.initials(for: "Vercel") == "V")
    }

    @Test func separatorsAreNormalised() {
        // Slashes / pipes / plus become word breaks.
        #expect(ToolMonogram.initials(for: "Figma / Make") == "FM")
        #expect(ToolMonogram.initials(for: "Affinity + Adobe") == "AA")
    }

    @Test func trailingDotOnlyIsStrippedNotMidWordDots() {
        // Only a dot at a word boundary is removed; a mid-token dot keeps the
        // token whole, so "Dessn.ai" is one word → "D" (parity with web).
        #expect(ToolMonogram.initials(for: "Dessn.ai") == "D")
        #expect(ToolMonogram.initials(for: "Node. Map") == "NM")
    }

    @Test func emptyOrWhitespaceNameFallsBackToQuestionMark() {
        #expect(ToolMonogram.initials(for: "") == "?")
        #expect(ToolMonogram.initials(for: "   ") == "?")
    }

    @Test func initialsAreUppercased() {
        #expect(ToolMonogram.initials(for: "claude code") == "CC")
    }
}
