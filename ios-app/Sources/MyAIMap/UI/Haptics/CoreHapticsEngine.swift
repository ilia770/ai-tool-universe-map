/// Anti-machine-gun shape for the multi-add Map badge tick, decided by
/// the add delta. Pure (no Core Haptics dependency) so it is unit
/// testable on every platform. See the motion/haptics spec:
/// N=1 single · N=2–4 ascending arpeggio · N≥5 swell + capping transient.
enum TickerTier: Equatable {
    case single
    /// Ascending arpeggio with `steps` transients (2…4).
    case arpeggio(steps: Int)
    case swell

    init(count: Int) {
        let n = max(count, 1)
        switch n {
        case 1: self = .single
        case 2...4: self = .arpeggio(steps: n)
        default: self = .swell
        }
    }
}

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

    enum Pattern: Equatable {
        case pocketOpen
        case pocketClose
        case classifySuccess

        /// Add-to-universe success: a continuous "whoosh" ramp into a
        /// firm "land" transient, capped by a soft "settle". The single
        /// felt success for the add flow — do not also fire `.success`.
        case toolLand

        /// Multi-add Map badge tick. Graduated by `count` to avoid a
        /// machine-gun feel: 1 = single transient; 2–4 = ascending
        /// arpeggio; 5+ = one continuous swell capped by a transient.
        case ticker(count: Int)
    }

    private var engine: CHHapticEngine?

    private init() {
        self.engine = makeEngine()
    }

    /// Returns a started engine, recreating one if the previous instance
    /// was niled by the `stoppedHandler`. Returns `nil` only when the
    /// hardware lacks haptics or engine creation/start fails.
    private func activeEngine() -> CHHapticEngine? {
        if engine == nil {
            engine = makeEngine()
        }
        return engine
    }

    /// Builds and starts a fresh `CHHapticEngine`, wiring the stopped /
    /// reset handlers. Returns `nil` on unsupported hardware or failure.
    private func makeEngine() -> CHHapticEngine? {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        do {
            let engine = try CHHapticEngine()
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.engine = nil }
            }
            engine.resetHandler = { [weak self] in
                Task { @MainActor in try? self?.engine?.start() }
            }
            try engine.start()
            return engine
        } catch {
            // Silent — Core Haptics is best-effort. Fall back to
            // UIImpactFeedbackGenerator at call sites.
            return nil
        }
    }

    /// Plays the named pattern. Returns `false` if the device or OS
    /// can't fulfil it; callers should fall back to a simple
    /// `BrandHaptics.fire(.medium)` in that case.
    @discardableResult
    func play(_ pattern: Pattern) -> Bool {
        guard BrandHaptics.isEnabled else { return false }
        // The `stoppedHandler` nils `engine` when the system stops it
        // (e.g. app backgrounded, audio session interruption). Lazily
        // recreate and restart before falling back to a simple haptic.
        guard let engine = activeEngine() else { return false }
        do {
            let events = Self.events(for: pattern)
            let curves = Self.parameterCurves(for: pattern)
            let chPattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: chPattern)
            try player.start(atTime: 0)
            return true
        } catch {
            return false
        }
    }

    /// Some patterns ramp intensity over a continuous event, which needs
    /// a parameter curve in addition to the events themselves.
    private static func parameterCurves(for pattern: Pattern) -> [CHHapticParameterCurve] {
        switch pattern {
        case .toolLand:
            // Whoosh ramp 0.25 → 0.55 over the flight.
            return [
                CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        .init(relativeTime: 0, value: 0.25),
                        .init(relativeTime: 0.54, value: 0.55),
                    ],
                    relativeTime: 0
                ),
            ]
        case let .ticker(count) where TickerTier(count: count) == .swell:
            // Continuous swell 0.3 → 0.6 under the cap transient.
            return [
                CHHapticParameterCurve(
                    parameterID: .hapticIntensityControl,
                    controlPoints: [
                        .init(relativeTime: 0, value: 0.3),
                        .init(relativeTime: 0.32, value: 0.6),
                    ],
                    relativeTime: 0
                ),
            ]
        default:
            return []
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

        case .toolLand:
            return [
                // Whoosh — continuous flight (intensity ramped by curve).
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                    ],
                    relativeTime: 0,
                    duration: 0.54
                ),
                // Land — firm thunk as the node seats.
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.95),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55),
                    ],
                    relativeTime: 0.54
                ),
                // Settle — soft lock-in.
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                    ],
                    relativeTime: 0.62
                ),
            ]

        case let .ticker(count):
            return tickerEvents(count: count)
        }
    }

    /// Graduated badge tick. `count` is the add delta.
    private static func tickerEvents(count: Int) -> [CHHapticEvent] {
        switch TickerTier(count: count) {
        case .single:
            // Single transient.
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.65),
                    ],
                    relativeTime: 0
                ),
            ]
        case let .arpeggio(steps):
            // Ascending arpeggio, 40 ms apart, intensity 0.40 → 0.70.
            let gap = 0.04
            let intensities = stride(from: 0.40, through: 0.70, by: (0.70 - 0.40) / Double(steps - 1))
            return Array(intensities.enumerated().map { index, intensity in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6),
                    ],
                    relativeTime: Double(index) * gap
                )
            }.prefix(steps))
        case .swell:
            // One continuous swell (intensity ramped by curve) capped by
            // a single firm transient.
            return [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                    ],
                    relativeTime: 0,
                    duration: 0.32
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                    ],
                    relativeTime: 0.32
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
        case .toolLand: fire(.heavy)
        case .ticker: fire(.light) // single light tick regardless of count
        }
    }
}
#else
@MainActor
final class CoreHapticsEngine {
    static let shared = CoreHapticsEngine()
    enum Pattern: Equatable {
        case pocketOpen, pocketClose, classifySuccess
        case toolLand
        case ticker(count: Int)
    }
    @discardableResult func play(_ pattern: Pattern) -> Bool { false }
}

extension BrandHaptics {
    @MainActor
    static func fireRich(_ pattern: CoreHapticsEngine.Pattern) {}
}
#endif
