import Foundation
import simd

/// Pure port of the web build's proximity watcher
/// (`src/components/AIToolUniverse3D/ProximityCategoryWatcher.tsx`).
/// Foundation + simd only — independently unit-testable, like
/// `UniverseLayout`. `ProximityCategorySystem` feeds it accumulated
/// scene time and the live camera position once per frame.
///
/// Hysteresis: auto-enter below `enterDistance` (overview only),
/// auto-exit past `exitDistance` — but only after the camera first
/// reached the pocket region (`exitDistance * armFactor`), so a manual
/// category tap doesn't immediately close while the camera is still
/// travelling from the overview.
struct ProximityWatcherCore {

    struct Anchor: Equatable, Sendable {
        let id: ToolCategoryId
        let position: SIMD3<Float>

        init(id: ToolCategoryId, position: SIMD3<Float>) {
            self.id = id
            self.position = position
        }
    }

    enum Event: Equatable, Sendable {
        case enter(ToolCategoryId)
        case exit
    }

    // Web parity: Scene.tsx wires enterDistance 11, exitDistance 22,
    // cooldownMs 1400; the watcher itself ticks at ~160 ms and arms
    // auto-exit at exitDistance * 0.96.
    static let enterDistance: Float = 11
    static let exitDistance: Float = 22
    static let tickInterval: TimeInterval = 0.16
    static let cooldown: TimeInterval = 1.4
    static let armFactor: Float = 0.96

    private var lastTickTime: TimeInterval = -.infinity
    private var lastTriggerTime: TimeInterval = -.infinity
    private var exitArmedCategory: ToolCategoryId?
    private var lastSeenCategory: ToolCategoryId = .core

    /// Advance the watcher. `now` is monotonically increasing scene
    /// time in seconds. Returns at most one event; the caller applies
    /// it to the view-model.
    mutating func tick(
        now: TimeInterval,
        cameraPosition: SIMD3<Float>,
        activeCategory: ToolCategoryId,
        anchors: [Anchor]
    ) -> Event? {
        // Web parity: the useEffect on activeCategory drops arming when
        // the pocket changes or the map returns to the overview.
        if activeCategory != lastSeenCategory {
            lastSeenCategory = activeCategory
            exitArmedCategory = nil
        }

        if now - lastTickTime < Self.tickInterval { return nil }
        lastTickTime = now
        if now - lastTriggerTime < Self.cooldown { return nil }

        guard activeCategory == .core else {
            return exitEvent(now: now, cameraPosition: cameraPosition, activeCategory: activeCategory, anchors: anchors)
        }
        return enterEvent(now: now, cameraPosition: cameraPosition, anchors: anchors)
    }

    /// Auto-exit: pocket open, camera pulled back past `exitDistance` —
    /// armed only once it first came within `exitDistance * armFactor`.
    private mutating func exitEvent(
        now: TimeInterval,
        cameraPosition: SIMD3<Float>,
        activeCategory: ToolCategoryId,
        anchors: [Anchor]
    ) -> Event? {
        guard let anchor = anchors.first(where: { $0.id == activeCategory }) else { return nil }
        let distSq = simd_length_squared(cameraPosition - anchor.position)
        let exitSq = Self.exitDistance * Self.exitDistance
        let armDistance = Self.exitDistance * Self.armFactor
        if distSq <= armDistance * armDistance {
            exitArmedCategory = activeCategory
        }
        guard exitArmedCategory == activeCategory, distSq > exitSq else { return nil }
        lastTriggerTime = now
        exitArmedCategory = nil
        return .exit
    }

    /// Auto-enter: overview showing, nearest anchor strictly inside
    /// `enterDistance` wins.
    private mutating func enterEvent(
        now: TimeInterval,
        cameraPosition: SIMD3<Float>,
        anchors: [Anchor]
    ) -> Event? {
        let enterSq = Self.enterDistance * Self.enterDistance
        var nearestID: ToolCategoryId?
        var nearestDistSq = enterSq
        for anchor in anchors {
            let distSq = simd_length_squared(cameraPosition - anchor.position)
            if distSq < nearestDistSq {
                nearestDistSq = distSq
                nearestID = anchor.id
            }
        }
        guard let nearestID else { return nil }
        lastTriggerTime = now
        return .enter(nearestID)
    }
}
