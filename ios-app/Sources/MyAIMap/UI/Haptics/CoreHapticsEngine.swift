#if canImport(CoreHaptics) && canImport(UIKit)
import CoreHaptics
import UIKit

/// Rich haptic patterns via Core Haptics. Reserved for the moments
/// that deserve a longer, layered cue — primarily the pocket-world
/// reveal (a 0.3 s sustained "depth" burst layered with a sharp
/// "click" at the end) and the classify-success cascade (three
/// ascending sharp taps over 0.12 s).
///
/// All call sites go through `BrandHaptics.fireRich(.pocketOpen)` etc.
/// — they should never reach for `CHHapticEngine` directly. That keeps
/// the simple `BrandHaptics.fire(.medium)` API tidy.
@MainActor
final class CoreHapticsEngine {
    static let shared = CoreHapticsEngine()

    enum Pattern {
        case pocketOpen
        case pocketClose
        case classifySuccess
    }

    private var engine: CHHapticEngine?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.stoppedHandler = { [weak self] _ in self?.engine = nil }
            engine.resetHandler = { [weak self] in try? self?.engine?.start() }
            try engine.start()
            self.engine = engine
        } catch {
            // Silent — Core Haptics is best-effort. Fall back to
            // UIImpactFeedbackGenerator at call sites.
            self.engine = nil
        }
    }

    /// Plays the named pattern. Returns `false` if the device or OS
    /// can't fulfil it; callers should fall back to a simple
    /// `BrandHaptics.fire(.medium)` in that case.
    @discardableResult
    func play(_ pattern: Pattern) -> Bool {
        guard BrandHaptics.isEnabled, let engine else { return false }
        do {
            let events = Self.events(for: pattern)
            let chPattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: chPattern)
            try player.start(atTime: 0)
            return true
        } catch {
            return false
        }
    }

    private static func events(for pattern: Pattern) -> [CHHapticEvent] {
        switch pattern {
        case .pocketOpen:
            return [
                // Sustained "depth" — a continuous swell over 0.3 s.
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.18),
                    ],
                    relativeTime: 0,
                    duration: 0.3
                ),
                // Capping click at the end.
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                    ],
                    relativeTime: 0.28
                ),
            ]

        case .pocketClose:
            return [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.22),
                    ],
                    relativeTime: 0,
                    duration: 0.2
                ),
            ]

        case .classifySuccess:
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55),
                    ],
                    relativeTime: 0.06
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.75),
                    ],
                    relativeTime: 0.12
                ),
            ]
        }
    }
}

extension BrandHaptics {
    /// Rich haptic patterns. Falls back to the closest simple haptic if
    /// Core Haptics is unavailable.
    @MainActor
    static func fireRich(_ pattern: CoreHapticsEngine.Pattern) {
        let played = CoreHapticsEngine.shared.play(pattern)
        guard !played else { return }
        switch pattern {
        case .pocketOpen: fire(.medium)
        case .pocketClose: fire(.light)
        case .classifySuccess: fire(.success)
        }
    }
}
#else
@MainActor
final class CoreHapticsEngine {
    static let shared = CoreHapticsEngine()
    enum Pattern { case pocketOpen, pocketClose, classifySuccess }
    @discardableResult func play(_ pattern: Pattern) -> Bool { false }
}

extension BrandHaptics {
    @MainActor
    static func fireRich(_ pattern: CoreHapticsEngine.Pattern) {}
}
#endif
