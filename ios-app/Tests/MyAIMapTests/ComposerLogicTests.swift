import Testing
@testable import MyAIMap

@Suite("ComposerLogic — pure SearchDock composer state")
struct ComposerLogicTests {

    // MARK: - Send enablement (text OR attachment)

    @Test func sendDisabledWhenNoTextAndNoAttachment() {
        #expect(ComposerLogic.canSend(hasText: false, hasAttachment: false) == false)
    }

    @Test func sendEnabledWithTextOnly() {
        #expect(ComposerLogic.canSend(hasText: true, hasAttachment: false) == true)
    }

    @Test func sendEnabledWithAttachmentOnly() {
        #expect(ComposerLogic.canSend(hasText: false, hasAttachment: true) == true)
    }

    @Test func sendEnabledWithTextAndAttachment() {
        #expect(ComposerLogic.canSend(hasText: true, hasAttachment: true) == true)
    }

    // MARK: - Attachment trigger icon (no random flipping)

    @Test func attachmentTriggerIsPaperclipWhenEmpty() {
        #expect(ComposerLogic.attachmentTriggerIcon(hasAttachment: false) == "paperclip")
    }

    @Test func attachmentTriggerStaysPaperclipWhenAttached() {
        // The attached state is communicated by the separate pill, never by
        // flipping the trigger glyph to the file/photo icon.
        #expect(ComposerLogic.attachmentTriggerIcon(hasAttachment: true) == "paperclip")
    }

    // MARK: - Remove attachment availability

    @Test func removeAttachmentHiddenWhenEmpty() {
        #expect(ComposerLogic.showsRemoveAttachment(hasAttachment: false) == false)
    }

    @Test func removeAttachmentShownWhenAttached() {
        #expect(ComposerLogic.showsRemoveAttachment(hasAttachment: true) == true)
    }

    // MARK: - De-duplication of access actions

    @Test func inMessageAccessActionsAreNeverRenderedAsButtons() {
        // Attach / Add-tool live only in the composer (single home). Assistant
        // messages must not render their own duplicate buttons.
        #expect(ComposerLogic.rendersInMessageAccessButtons == false)
    }
}
