#if canImport(UIKit)
import SwiftUI
import CoreMotion

/// Subtle parallax tilt driven by device-motion. Used on the bottom
/// sheet header and the founder OS card so they feel like physical
/// glass tilting under the device. Disabled when reduce motion is on
/// or when CoreMotion is unavailable (Simulator without virtual
/// motion).
///
/// Usage:
///
/// ```swift
/// FounderHeader()
///   .parallaxTilt(maxOffset: 6)
/// ```
extension View {
    func parallaxTilt(maxOffset: CGFloat = 8) -> some View {
        modifier(ParallaxTiltModifier(maxOffset: maxOffset))
    }
}

@MainActor
private final class MotionSource: ObservableObject {
    @Published var offset: CGSize = .zero
    private let manager = CMMotionManager()

    init() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let pitch = CGFloat(motion.attitude.pitch).clamped(to: -0.5...0.5)
            let roll = CGFloat(motion.attitude.roll).clamped(to: -0.5...0.5)
            self?.offset = CGSize(width: roll, height: pitch)
        }
    }

    deinit {
        manager.stopDeviceMotionUpdates()
    }
}

private struct ParallaxTiltModifier: ViewModifier {
    let maxOffset: CGFloat
    @StateObject private var motion = MotionSource()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let resolved = reduceMotion ? .zero : motion.offset
        content
            .offset(
                x: resolved.width * maxOffset,
                y: resolved.height * maxOffset
            )
            .brandAnimation(BrandMotion.flow, value: resolved.width + resolved.height)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
#else
import SwiftUI

extension View {
    func parallaxTilt(maxOffset: CGFloat = 8) -> some View { self }
}
#endif
