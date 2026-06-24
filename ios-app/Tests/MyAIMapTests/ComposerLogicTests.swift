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

    @Test func trailingButtonIsAddToolWhenComposerIsIdle() {
        #expect(ComposerLogic.showsSendButton(isFocused: false, hasText: false, hasAttachment: false) == false)
    }

    @Test func trailingButtonIsSendWhenFocused() {
        #expect(ComposerLogic.showsSendButton(isFocused: true, hasText: false, hasAttachment: false))
    }

    @Test func trailingButtonStaysSendWhenDraftRemainsAfterBlur() {
        #expect(ComposerLogic.showsSendButton(isFocused: false, hasText: true, hasAttachment: false))
    }

    @Test func trailingButtonStaysSendForAttachmentAfterBlur() {
        #expect(ComposerLogic.showsSendButton(isFocused: false, hasText: false, hasAttachment: true))
    }

    @Test func outgoingMessageUsesTrimmedQuery() {
        #expect(ComposerLogic.outgoingMessageText(query: "  привет universe  ", attachmentTitle: nil) == "привет universe")
    }

    @Test func outgoingMessageSupportsAttachmentOnlySend() {
        #expect(ComposerLogic.outgoingMessageText(query: "   ", attachmentTitle: "file") == "Attached file")
    }

    @Test func outgoingMessageIsNilWhenComposerIsEmpty() {
        #expect(ComposerLogic.outgoingMessageText(query: "   ", attachmentTitle: nil) == nil)
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

    // MARK: - Float lane: menu vs preview are mutually exclusive (§4)

    @Test func floatLaneEmptyWhenNoAttachmentAndMenuClosed() {
        // State A — no panel above the composer.
        #expect(ComposerLogic.showsAttachmentMenu(menuOpen: false) == false)
        #expect(ComposerLogic.showsAttachmentPreview(menuOpen: false, hasAttachment: false) == false)
    }

    @Test func menuShowsAndPreviewHiddenWhileMenuOpen() {
        // State B — menu open; preview suppressed even if an attachment exists.
        #expect(ComposerLogic.showsAttachmentMenu(menuOpen: true) == true)
        #expect(ComposerLogic.showsAttachmentPreview(menuOpen: true, hasAttachment: true) == false)
    }

    @Test func previewShowsWhenAttachedAndMenuClosed() {
        // State C — attachment staged, menu closed.
        #expect(ComposerLogic.showsAttachmentPreview(menuOpen: false, hasAttachment: true) == true)
        #expect(ComposerLogic.showsAttachmentMenu(menuOpen: false) == false)
    }

    @Test func menuAndPreviewAreNeverBothVisible() {
        for menuOpen in [true, false] {
            for hasAttachment in [true, false] {
                let menu = ComposerLogic.showsAttachmentMenu(menuOpen: menuOpen)
                let preview = ComposerLogic.showsAttachmentPreview(menuOpen: menuOpen, hasAttachment: hasAttachment)
                #expect(!(menu && preview))
            }
        }
    }

    // MARK: - De-duplication of access actions

    @Test func inMessageAccessActionsAreNeverRenderedAsButtons() {
        // Attach / Add-tool live only in the composer (single home). Assistant
        // messages must not render their own duplicate buttons.
        #expect(ComposerLogic.rendersInMessageAccessButtons == false)
    }

    // MARK: - Collapse / expand state

    @Test func collapsedConversationReturnsMapInteractionEvenWithContent() {
        #expect(ComposerLogic.keepsChatActive(
            isFocused: false,
            showsConversation: false,
            isCollapsedWithContent: true,
            attachmentMenuOpen: false,
            hasAttachment: false
        ) == false)
    }

    @Test func idleCollapsedConversationWithoutContentDoesNotKeepChatActive() {
        #expect(ComposerLogic.keepsChatActive(
            isFocused: false,
            showsConversation: false,
            isCollapsedWithContent: false,
            attachmentMenuOpen: false,
            hasAttachment: false
        ) == false)
    }

    @Test func attachmentMenuKeepsChatActiveUntilDismissed() {
        #expect(ComposerLogic.keepsChatActive(
            isFocused: false,
            showsConversation: false,
            isCollapsedWithContent: false,
            attachmentMenuOpen: true,
            hasAttachment: false
        ))
    }

    // MARK: - Message layout contracts

    @Test func userBubbleRatioStaysInRequestedRange() {
        #expect(ComposerLogic.userBubbleMaxWidthRatio >= 0.75)
        #expect(ComposerLogic.userBubbleMaxWidthRatio <= 0.82)
    }

    @Test func userBubbleMaxWidthUsesConfiguredRatio() {
        #expect(ComposerLogic.userBubbleMaxWidth(availableWidth: 400) == 320)
    }

    @Test func composerAutoGrowLimitsStayInReadableRange() {
        #expect(ComposerLogic.composerMinHeight == 44)
        #expect(ComposerLogic.composerMaxHeight >= 120)
        #expect(ComposerLogic.composerMaxHeight <= 160)
        #expect(ComposerLogic.composerMaxLines == 6)
    }

    // MARK: - Assistant response presentation

    @Test func assistantPresentationRemovesActionChipsProse() {
        let prose = AssistantResponsePresentation.prose(from: """
        **Summary**
        Use Figma first.

        **Recommended tools**
        - Figma for design.

        **Action chips**
        Open existing tool chips for details. Add suggested missing tools from their chips.
        """)

        #expect(prose.hasPrefix("Use Figma first."))
        #expect(prose.contains("**Recommended path**"))
        #expect(!prose.contains("Action chips"))
        #expect(!prose.contains("Open existing tool chips"))
    }

    @Test func assistantPresentationRenamesTradeoffSections() {
        let prose = AssistantResponsePresentation.prose(from: """
        **Options**
        - Fastest: Figma.

        **Caveats / tradeoffs**
        - Pricing unknown.
        """)

        #expect(prose.contains("**Cost / time tradeoffs**"))
        #expect(prose.contains("**Notes**"))
    }

    @Test func assistantClipboardUsesVisibleProseOnly() {
        let text = AssistantClipboardFormatter.text(from: """
        **Summary**
        Use Figma first.

        | Tool | Why |
        | --- | --- |
        | Figma | Design |

        **Action chips**
        Open existing tool chips for details.
        """)

        #expect(text == "Use Figma first.")
    }
}
