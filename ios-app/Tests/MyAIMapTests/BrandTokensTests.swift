import Testing
import SwiftUI
@testable import MyAIMap

@Suite("Brand tokens")
struct BrandTokensTests {

    @Test func radiiAreOrdered() {
        #expect(BrandRadius.tight.value < BrandRadius.node.value)
        #expect(BrandRadius.node.value < BrandRadius.nested.value)
        #expect(BrandRadius.nested.value < BrandRadius.card.value)
        #expect(BrandRadius.card.value < BrandRadius.pill.value)
    }

    @Test func spacingFollowsFourPointGrid() {
        let values: [CGFloat] = [
            BrandSpacing.hair.value,
            BrandSpacing.xs.value,
            BrandSpacing.s.value,
            BrandSpacing.m.value,
            BrandSpacing.l.value,
            BrandSpacing.xl.value,
            BrandSpacing.xxl.value,
            BrandSpacing.section.value,
        ]
        for v in values where v != BrandSpacing.hair.value {
            #expect(v.truncatingRemainder(dividingBy: 4) == 0, "spacing \(v) is off the 4 px grid")
        }
    }

    @Test func semanticControlSpacingRemainsTenPoints() {
        #expect(BrandSpacing.sm.value == 10)
    }

    @Test func brandColoursAreDistinct() {
        let palette: [Color] = [
            BrandColor.violet, BrandColor.pink, BrandColor.teal,
            BrandColor.orange, BrandColor.cyan, BrandColor.lime,
            BrandColor.amber, BrandColor.core,
        ]
        let descriptions = palette.map { String(describing: $0) }
        #expect(Set(descriptions).count == palette.count, "two brand colours collide")
    }

    @Test func reducedMotionReplacesAnimation() {
        // Animation is Equatable; comparing values avoids coupling to
        // SwiftUI's internal description format, which changes between
        // SDKs (.linear(duration:) now describes as BezierAnimation).
        let resolved = BrandMotion.resolved(
            BrandMotion.entry,
            reduceMotion: true,
            arguments: []
        )
        #expect(resolved == .linear(duration: 0.001))
        #expect(BrandMotion.resolved(
            BrandMotion.entry,
            reduceMotion: false,
            arguments: []
        ) == BrandMotion.entry)
    }

    @Test func staticUITestModeDisablesMotion() {
        let arguments = ["My AI Map", "-uitestStatic"]

        #expect(BrandMotion.isMotionDisabled(reduceMotion: false, arguments: arguments))
        #expect(BrandMotion.resolved(
            BrandMotion.entry,
            reduceMotion: false,
            arguments: arguments
        ) == .linear(duration: 0.001))
    }

    @Test func pressScaleHonorsMotionPolicy() {
        #expect(BrandMotion.pressScale(
            0.97,
            isPressed: true,
            reduceMotion: false,
            arguments: []
        ) == 0.97)
        #expect(BrandMotion.pressScale(
            0.97,
            isPressed: true,
            reduceMotion: true,
            arguments: []
        ) == 1)
        #expect(BrandMotion.pressScale(
            0.97,
            isPressed: true,
            reduceMotion: false,
            arguments: ["-uitestStatic"]
        ) == 1)
    }

    @Test @MainActor func glassControlAvoidsStackedNativeScale() {
        #expect(GlassControlButtonStyle.resolvedScale(
            isPressed: true,
            reduceMotion: false,
            arguments: [],
            usesNativeGlassResponse: true
        ) == 1)
        #expect(GlassControlButtonStyle.resolvedScale(
            isPressed: true,
            reduceMotion: false,
            arguments: [],
            usesNativeGlassResponse: false
        ) == 0.97)
        #expect(GlassControlButtonStyle.resolvedScale(
            isPressed: true,
            reduceMotion: false,
            arguments: ["-uitestStatic"],
            usesNativeGlassResponse: false
        ) == 1)
    }

    @Test @MainActor func glassControlFallsBackWhenNativeInteractionIsUnavailable() {
        #expect(GlassControlButtonStyle.nativeGlassResponseEnabled(
            platformSupportsNativeGlass: true,
            reduceTransparency: false,
            reduceMotion: false,
            arguments: []
        ))
        #expect(!GlassControlButtonStyle.nativeGlassResponseEnabled(
            platformSupportsNativeGlass: true,
            reduceTransparency: true,
            reduceMotion: false,
            arguments: []
        ))
        #expect(!GlassControlButtonStyle.nativeGlassResponseEnabled(
            platformSupportsNativeGlass: true,
            reduceTransparency: false,
            reduceMotion: true,
            arguments: []
        ))
        #expect(!GlassControlButtonStyle.nativeGlassResponseEnabled(
            platformSupportsNativeGlass: true,
            reduceTransparency: false,
            reduceMotion: false,
            arguments: ["-uitestStatic"]
        ))
        #expect(GlassControlButtonStyle.resolvedOpacity(
            isPressed: true,
            usesNativeGlassResponse: false
        ) == 0.9)
    }

    @Test @MainActor func hapticsDisabledIsNoOp() {
        BrandHaptics.isEnabled = false
        defer { BrandHaptics.isEnabled = true }
        // Just an API smoke — fire must not crash with disabled flag.
        BrandHaptics.fire(.medium)
        BrandHaptics.fire(.success)
    }
}
