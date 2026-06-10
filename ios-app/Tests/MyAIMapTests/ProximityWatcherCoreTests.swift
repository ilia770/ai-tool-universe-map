import Testing
import simd
@testable import MyAIMap

@Suite("ProximityWatcherCore — web ProximityCategoryWatcher parity")
struct ProximityWatcherCoreTests {

    private let anchors: [ProximityWatcherCore.Anchor] = [
        .init(id: .design, position: SIMD3<Float>(10, 0, 0)),
        .init(id: .coding, position: SIMD3<Float>(-10, 0, 0)),
    ]

    // MARK: - Auto-enter (overview)

    @Test func entersNearestAnchorUnderEnterDistance() {
        var core = ProximityWatcherCore()
        // 4 units from design (10,0,0); 24 from coding — design wins.
        let event = core.tick(
            now: 1.0,
            cameraPosition: SIMD3<Float>(6, 0, 0),
            activeCategory: .core,
            anchors: anchors
        )
        #expect(event == .enter(.design))
    }

    @Test func picksNearestWhenSeveralAnchorsAreInRange() {
        var core = ProximityWatcherCore()
        // 9.5 from design, 10.5 from coding — both < 11, design nearer.
        let event = core.tick(
            now: 1.0,
            cameraPosition: SIMD3<Float>(0.5, 0, 0),
            activeCategory: .core,
            anchors: anchors
        )
        #expect(event == .enter(.design))
    }

    @Test func noEnterBeyondEnterDistance() {
        var core = ProximityWatcherCore()
        // Exactly 11 from design (10,0,0) → web uses strict <, no enter.
        let event = core.tick(
            now: 1.0,
            cameraPosition: SIMD3<Float>(21, 0, 0),
            activeCategory: .core,
            anchors: anchors
        )
        #expect(event == nil)
    }

    // MARK: - Throttle + cooldown

    @Test func ticksAreThrottledTo160ms() {
        var core = ProximityWatcherCore()
        let near = SIMD3<Float>(6, 0, 0)
        let far = SIMD3<Float>(40, 0, 0)
        // First tick is accepted (far camera → no event, no cooldown).
        #expect(core.tick(now: 1.0, cameraPosition: far, activeCategory: .core, anchors: anchors) == nil)
        // 100 ms later: inside the 160 ms tick window — even a near
        // camera produces nothing because the tick itself is swallowed.
        #expect(core.tick(now: 1.1, cameraPosition: near, activeCategory: .core, anchors: anchors) == nil)
        // 170 ms after the LAST ACCEPTED tick it fires.
        #expect(core.tick(now: 1.17, cameraPosition: near, activeCategory: .core, anchors: anchors) == .enter(.design))
    }

    @Test func cooldownSuppressesRetriggerFor1400ms() {
        var core = ProximityWatcherCore()
        let near = SIMD3<Float>(6, 0, 0)
        #expect(core.tick(now: 1.0, cameraPosition: near, activeCategory: .core, anchors: anchors) == .enter(.design))
        // Still in overview (caller ignored the event), 1.0 s later —
        // past the tick throttle but inside the 1.4 s cooldown.
        #expect(core.tick(now: 2.0, cameraPosition: near, activeCategory: .core, anchors: anchors) == nil)
        // 1.5 s after the trigger: cooldown over, fires again.
        #expect(core.tick(now: 2.5, cameraPosition: near, activeCategory: .core, anchors: anchors) == .enter(.design))
    }

    // MARK: - Auto-exit (pocket open)

    @Test func exitRequiresArmingFirst() {
        var core = ProximityWatcherCore()
        // Pocket open on design, camera far away (e.g. still travelling
        // after a manual click) — NOT armed, must not exit.
        let far = SIMD3<Float>(40, 0, 0) // 30 from design
        #expect(core.tick(now: 1.0, cameraPosition: far, activeCategory: .design, anchors: anchors) == nil)
        // Camera reaches the pocket region (distance 5 ≤ 21.12) → arms.
        let inside = SIMD3<Float>(15, 0, 0)
        #expect(core.tick(now: 1.2, cameraPosition: inside, activeCategory: .design, anchors: anchors) == nil)
        // Camera pulls past exitDistance 22 → exit fires.
        let out = SIMD3<Float>(33, 0, 0) // 23 from design
        #expect(core.tick(now: 1.4, cameraPosition: out, activeCategory: .design, anchors: anchors) == .exit)
    }

    @Test func betweenArmAndExitDistanceNeitherArmsNorExits() {
        var core = ProximityWatcherCore()
        // 21.5 from design: > 21.12 (no arm), ≤ 22 (no exit).
        let between = SIMD3<Float>(31.5, 0, 0)
        #expect(core.tick(now: 1.0, cameraPosition: between, activeCategory: .design, anchors: anchors) == nil)
        // Pull out past 22 — still nil because arming never happened.
        let out = SIMD3<Float>(40, 0, 0)
        #expect(core.tick(now: 1.2, cameraPosition: out, activeCategory: .design, anchors: anchors) == nil)
    }

    @Test func armingResetsWhenCategoryChanges() {
        var core = ProximityWatcherCore()
        // Arm on design.
        let insideDesign = SIMD3<Float>(15, 0, 0)
        #expect(core.tick(now: 1.0, cameraPosition: insideDesign, activeCategory: .design, anchors: anchors) == nil)
        // User switches pocket to coding (rail tap). Old arming must not
        // leak: camera is 25 from coding (> 22) but coding never armed.
        let nearDesignFarFromCoding = SIMD3<Float>(15, 0, 0)
        #expect(core.tick(now: 1.2, cameraPosition: nearDesignFarFromCoding, activeCategory: .coding, anchors: anchors) == nil)
        #expect(core.tick(now: 1.4, cameraPosition: nearDesignFarFromCoding, activeCategory: .coding, anchors: anchors) == nil)
        // User switches back to design, camera now 30 from design
        // (> 22). Without the category-change reset the stale .design
        // arming from tick 1.0 would still match and emit a spurious
        // .exit — the reset must have cleared it.
        let farFromDesign = SIMD3<Float>(40, 0, 0)
        #expect(core.tick(now: 1.6, cameraPosition: farFromDesign, activeCategory: .design, anchors: anchors) == nil)
    }

    @Test func missingAnchorForActiveCategoryIsIgnored() {
        var core = ProximityWatcherCore()
        // .media has no anchor in the fixture — must be a no-op.
        let event = core.tick(
            now: 1.0,
            cameraPosition: SIMD3<Float>(0, 0, 0),
            activeCategory: .media,
            anchors: anchors
        )
        #expect(event == nil)
    }

    @Test func noEnterWhilePocketIsOpen() {
        var core = ProximityWatcherCore()
        // Camera 4 from coding, but design pocket is open → the watcher
        // is in exit mode; it must not emit .enter(.coding).
        let nearCoding = SIMD3<Float>(-6, 0, 0)
        let event = core.tick(now: 1.0, cameraPosition: nearCoding, activeCategory: .design, anchors: anchors)
        #expect(event == nil)
    }
}
