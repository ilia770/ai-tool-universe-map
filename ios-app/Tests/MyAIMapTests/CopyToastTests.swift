import Testing
@testable import MyAIMap

@Suite("CopyToast — message + clipboard logic")
struct CopyToastTests {
    @Test func answerKindReadsAnswerCopied() {
        #expect(CopyToastKind.answer.message == "Answer copied")
    }

    @Test func toolInfoKindReadsToolInfoCopied() {
        #expect(CopyToastKind.toolInfo.message == "Tool info copied")
    }

    @Test func clipboardJoinsNameSummaryAndURL() {
        let text = ToolInfoClipboard.text(
            name: "Supabase",
            summary: "Postgres backend.",
            url: "https://supabase.com"
        )
        #expect(text == "Supabase\nPostgres backend.\nhttps://supabase.com")
    }

    @Test func clipboardOmitsMissingURL() {
        let text = ToolInfoClipboard.text(name: "Acme", summary: "A tool.", url: nil)
        #expect(text == "Acme\nA tool.")
    }

    @Test func clipboardOmitsBlankURL() {
        let text = ToolInfoClipboard.text(name: "Acme", summary: "A tool.", url: "   ")
        #expect(text == "Acme\nA tool.")
    }

    @Test func richClipboardIncludesProfileSummary() {
        let text = ToolInfoClipboard.text(
            name: "Claude",
            category: "Coding",
            summary: "AI assistant for coding.",
            pricingStatus: "Unknown",
            keyFeatures: ["Code help", "Review", "Planning", "Extra ignored"],
            url: nil
        )

        #expect(text.contains("Category: Coding"))
        #expect(text.contains("Pricing: Unknown"))
        #expect(text.contains("Key features: Code help; Review; Planning"))
        #expect(!text.contains("Extra ignored"))
    }
}
