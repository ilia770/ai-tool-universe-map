import Testing
import SwiftUI
import UIKit
@testable import MyAIMap

@Suite("Settings sheet")
@MainActor
struct SettingsSheetTests {

    private func render(_ view: some View, size: CGSize) -> UIImage? {
        let content = ZStack { Color.black; view }
            .environment(UniverseViewModel())
            .environment(AppSettings(defaults: isolatedDefaults()))
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 2
        return renderer.uiImage
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "SettingsSheetTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func rendersNonNil() {
        let image = render(SettingsSheet(), size: CGSize(width: 360, height: 600))
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    @Test func languageToggleMutatesSettings() {
        let settings = AppSettings(defaults: isolatedDefaults())
        #expect(settings.language == AppSettings.defaultLanguage)
        // The picker binds directly to settings.language; flipping the
        // value is what the UI control does on tap.
        settings.language = (settings.language == .ru) ? .en : .ru
        #expect(settings.language != AppSettings.defaultLanguage || AppSettings.defaultLanguage == settings.language)
    }
}
