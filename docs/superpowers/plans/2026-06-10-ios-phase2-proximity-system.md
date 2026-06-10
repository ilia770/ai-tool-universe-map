# iOS Phase 2 — ProximityCategorySystem Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the web `ProximityCategoryWatcher` to RealityKit — pinch-zoom toward a category anchor auto-opens its pocket (enter < 11), pulling the camera away auto-closes it (exit > 22) — step 4 of `docs/PHASE_2_PLAN.md`.

**Architecture:** All hysteresis/throttle/cooldown logic lives in `ProximityWatcherCore`, a pure Foundation+simd struct ported one-for-one from `src/components/AIToolUniverse3D/ProximityCategoryWatcher.tsx` (same pattern as `UniverseLayout` — independently unit-testable). A thin RealityKit `System` (`ProximityCategorySystem`) feeds it accumulated scene time and the live camera position each frame, reading per-scene state from a `UniverseStateComponent` attached to the universe root by `UniverseView`. Events route to `UniverseViewModel.selectCategory` via a closure passed down from `UniverseScreen`.

**Tech Stack:** Swift 6 (strict concurrency `complete`), RealityKit ECS (`System`, `Component`, `EntityQuery`), SwiftUI, Swift Testing (`@Suite`/`@Test`/`#expect`), XcodeGen.

**Worktree:** `/Users/ilia882/.config/superpowers/worktrees/ai-tool-universe-map/claude-ios-phase2-proximity`, branch `feat/ios-phase2-proximity` (created off `origin/main` at `c268ef0`). All commands run from this worktree root unless stated otherwise.

**Out of scope (later Phase 2 PRs):** `PocketShellEntity` + `PocketTransition` (step 5), tap/drag gestures, SearchDock, Sheets, haptics wiring. No camera "fly toward anchor" animation on auto-enter — the existing `.id(selectedCategory)` scene rebuild + `attach` snap is the Phase 1 mechanism this slice keeps.

## Web-parity contract (the spec)

From `src/components/AIToolUniverse3D/ProximityCategoryWatcher.tsx` and its wiring in `Scene.tsx:414-422`:

| Web | Value | iOS mapping |
| --- | --- | --- |
| `enterDistance` | 11 | same |
| `exitDistance` | 22 | same |
| `cooldownMs` | 1400 | `cooldown: TimeInterval = 1.4` |
| tick throttle | 160 ms (`useFrame` gate) | `tickInterval: TimeInterval = 0.16` |
| exit arm threshold | `exitDistance * 0.96` | `armFactor: Float = 0.96` |
| `activeCategory === 'all'` | overview | `activeCategory == .core` |
| `onEnter(id)` | `onSelectCategory(id)` | `model.selectCategory(id)` |
| `onExit()` | `onSelectCategory('all')` | `model.selectCategory(.core)` |

Behaviour rules (verbatim from the web watcher):

1. Ticks are throttled to one per 160 ms of scene time; after any enter/exit event, all triggers are suppressed for 1400 ms (cooldown).
2. **Auto-enter** fires only in overview (`.core`): nearest anchor with distance < 11 wins.
3. **Auto-exit** fires only when a pocket is open AND exit is *armed*: the camera must first come within `22 * 0.96 = 21.12` of the active anchor (arming), then pull past 22. This prevents a manual category click from instantly closing while the camera is still travelling.
4. Arming resets whenever `activeCategory` changes (web `useEffect`).
5. Missing anchor for the active category → do nothing (no crash).

**Accepted deviation:** the web scene persists across category changes, so its 1400 ms cooldown spans enter→exit. On iOS, `UniverseView` uses `.id(selectedCategory)` — every category change rebuilds the scene and creates a fresh `ProximityCategorySystem` (RealityKit instantiates one system per scene), so the cooldown clock restarts. Flicker is still impossible: after rebuild the camera snaps to the pocket framing at distance ≈ 20.2 from the anchor (inside the 11–22 hysteresis band), so neither trigger can re-fire immediately. Document this in the PR description.

**Swift 6 note for the System:** RealityKit calls `System.update(context:)` on the main thread. If the SDK's `System` protocol is `@MainActor`-annotated (iOS 18 SDK), calling the `@MainActor` event closure directly compiles. If the compiler reports that `update` is nonisolated, wrap the dispatch: `MainActor.assumeIsolated { state.onProximityEvent(event) }`. Do NOT make the closure non-isolated — it mutates the `@MainActor` view-model.

**Test-runner blocker (known, pre-existing):** `xcodebuild test` hangs before the runner connects (CoreSimulator migration issue — `docs/AGENT_STATUS.md`). The verification gate for this slice is therefore **`build-for-testing`** (compiles app + test bundle). Write tests TDD-style anyway: "red" = test file references a type that doesn't exist yet, so `build-for-testing` FAILS to compile; "green" = it compiles. Use the simulator **id** destination (name matching is flaky):

```bash
# Fast typecheck (app sources only; test files need xcodebuild):
cd ios-app && xcrun swiftc -typecheck \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios18.0-simulator \
  $(find Sources -name '*.swift') && cd ..

# Full gate (regenerates the gitignored .xcodeproj first):
cd ios-app && xcodegen generate && \
xcodebuild -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,id=01F7938F-C881-43B9-9222-0E78E63D7A51' \
  build-for-testing 2>&1 | tail -5 && cd ..
```

Expected tail on success: `** TEST BUILD SUCCEEDED **`.

**Repo wart:** `.github/PULL_REQUEST_TEMPLATE.md` shows perpetually modified (case-collision with `pull_request_template.md` on APFS). Never stage or commit it.

---

### Task 1: `ProximityWatcherCore` — pure hysteresis logic (TDD)

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/ECS/ProximityWatcherCore.swift`
- Test: `ios-app/Tests/MyAIMapTests/ProximityWatcherCoreTests.swift`

- [x] **Step 1: Write the failing tests**

Create `ios-app/Tests/MyAIMapTests/ProximityWatcherCoreTests.swift`:

```swift
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
```

- [x] **Step 2: Verify it fails (compile error = red)**

```bash
cd ios-app && xcodegen generate && \
xcodebuild -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,id=01F7938F-C881-43B9-9222-0E78E63D7A51' \
  build-for-testing 2>&1 | tail -5 && cd ..
```

Expected: FAIL — `cannot find 'ProximityWatcherCore' in scope` (in the tail or the error lines above it).

- [x] **Step 3: Implement the core**

Create `ios-app/Sources/MyAIMap/Universe/ECS/ProximityWatcherCore.swift`:

```swift
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
```

- [x] **Step 4: Verify green**

```bash
cd ios-app && xcodegen generate && \
xcodebuild -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,id=01F7938F-C881-43B9-9222-0E78E63D7A51' \
  build-for-testing 2>&1 | tail -5 && cd ..
```

Expected: `** TEST BUILD SUCCEEDED **`. (Runner is blocked — see header — so compile of app + tests is the gate. Re-read each test against the implementation by hand before committing.)

- [x] **Step 5: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/ECS/ProximityWatcherCore.swift \
        ios-app/Tests/MyAIMapTests/ProximityWatcherCoreTests.swift
git commit -m "feat(ios): ProximityWatcherCore — pure hysteresis port of web watcher"
```

---

### Task 2: `UniverseStateComponent` + `ProximityCategorySystem` (RealityKit shell)

**Files:**
- Create: `ios-app/Sources/MyAIMap/Universe/ECS/UniverseStateComponent.swift`
- Create: `ios-app/Sources/MyAIMap/Universe/ECS/ProximityCategorySystem.swift`

No new unit tests: both types are RealityKit-bound (entity refs, scene update context) and cannot run headless; all decision logic is already covered by Task 1. Verification is compile (typecheck + build).

- [x] **Step 1: Create the component**

Create `ios-app/Sources/MyAIMap/Universe/ECS/UniverseStateComponent.swift`:

```swift
import Foundation
import RealityKit

/// Per-scene state for `ProximityCategorySystem`: which pocket is open,
/// the category anchor positions, the camera to measure from, and where
/// to send enter/exit events. `UniverseView` attaches it to the universe
/// root entity. The scene is rebuilt on every category change
/// (`.id(selectedCategory)` in UniverseView), so `activeCategory` is
/// fixed for the lifetime of each component instance.
struct UniverseStateComponent: Component {
    let activeCategory: ToolCategoryId
    let anchors: [ProximityWatcherCore.Anchor]
    let camera: Entity
    let onProximityEvent: @MainActor (ProximityWatcherCore.Event) -> Void
}
```

- [x] **Step 2: Create the system**

Create `ios-app/Sources/MyAIMap/Universe/ECS/ProximityCategorySystem.swift`:

```swift
import Foundation
import RealityKit

/// RealityKit System polling camera↔anchor distance each frame
/// (PHASE_2_PLAN step 4). Thin shell: throttle, cooldown, and
/// hysteresis all live in the pure `ProximityWatcherCore`.
final class ProximityCategorySystem: System {
    private static let query = EntityQuery(where: .has(UniverseStateComponent.self))

    private var core = ProximityWatcherCore()
    private var elapsedTime: TimeInterval = 0

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        elapsedTime += context.deltaTime
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let state = entity.components[UniverseStateComponent.self] else { continue }
            let event = core.tick(
                now: elapsedTime,
                cameraPosition: state.camera.position(relativeTo: nil),
                activeCategory: state.activeCategory,
                anchors: state.anchors
            )
            if let event {
                state.onProximityEvent(event)
            }
        }
    }
}
```

Swift 6 contingency (see header): if the compiler reports `update` is nonisolated and refuses the `@MainActor` closure call, replace the dispatch with:

```swift
            if let event {
                MainActor.assumeIsolated {
                    state.onProximityEvent(event)
                }
            }
```

(RealityKit runs system updates on the main thread; `assumeIsolated` documents and enforces that assumption at runtime.) If instead the compiler demands isolation annotations on `init(scene:)`/`update`, match the protocol's signatures exactly as suggested by the fix-it.

- [x] **Step 3: Typecheck app sources**

```bash
cd ios-app && xcrun swiftc -typecheck \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios18.0-simulator \
  $(find Sources -name '*.swift') && cd ..
```

Expected: exit 0, no output.

- [x] **Step 4: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/ECS/UniverseStateComponent.swift \
        ios-app/Sources/MyAIMap/Universe/ECS/ProximityCategorySystem.swift
git commit -m "feat(ios): ProximityCategorySystem — RealityKit shell over the pure core"
```

---

### Task 3: Wire scene + screen (registration, component, event routing)

**Files:**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseView.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift:18-21` (UniverseView call site)

- [x] **Step 1: UniverseView — accept the event closure, register ECS types, attach the component**

Three edits to `ios-app/Sources/MyAIMap/Universe/UniverseView.swift`.

(a) Add the closure property after `let selectedToolId: String` (line 12):

```swift
    let selectedToolId: String
    let onProximityEvent: @MainActor (ProximityWatcherCore.Event) -> Void
```

(b) In the `RealityView { content in` make closure, register the ECS types first, collect anchors in the existing category loop, and attach the component after the loop. The full make closure becomes:

```swift
        RealityView { content in
            // Idempotent; must run before the scene starts updating.
            UniverseStateComponent.registerComponent()
            ProximityCategorySystem.registerSystem()

            let universe = Entity()
            content.add(universe)

            let camera = PerspectiveCamera()
            universe.addChild(camera)
            cameraController.attach(camera, mode: viewMode, target: lookAtPosition(for: selectedCategory))

            universe.addChild(Self.makeToolNode(
                tool: UniverseSeed.tools.first { $0.id == "founder-os" },
                category: UniverseSeed.category(.core),
                position: .zero,
                selected: selectedCategory == .core
            ))

            var anchors: [ProximityWatcherCore.Anchor] = []
            for category in UniverseSeed.categories where category.id != .core {
                let center = UniverseLayout.categoryPosition(angleDegrees: category.angle)
                anchors.append(ProximityWatcherCore.Anchor(id: category.id, position: center))
                universe.addChild(Self.makeCategoryAnchor(category: category, position: center, selected: category.id == selectedCategory))

                let categoryTools = UniverseSeed.tools(in: category.id)
                for (index, tool) in categoryTools.enumerated() {
                    let isPocket = category.id == selectedCategory
                    let isSelectedTool = tool.id == selectedToolId
                    let position = isPocket
                        ? UniverseLayout.pocketToolPosition(
                            angleDegrees: tool.angle,
                            orbit: tool.orbit,
                            categoryAngleDegrees: category.angle,
                            slotIndex: index,
                            slotCount: max(categoryTools.count, 1)
                        )
                        : UniverseLayout.toolPosition(
                            angleDegrees: tool.angle,
                            orbit: tool.orbit,
                            categoryAngleDegrees: category.angle
                        )
                    universe.addChild(Self.makeToolNode(
                        tool: tool,
                        category: category,
                        position: position,
                        selected: isSelectedTool,
                        pocketed: isPocket
                    ))
                }
            }

            universe.components.set(UniverseStateComponent(
                activeCategory: selectedCategory,
                anchors: anchors,
                camera: camera,
                onProximityEvent: onProximityEvent
            ))

            let key = DirectionalLight()
            key.light.intensity = 1_200
            key.position = SIMD3<Float>(-4, 7, 10)
            universe.addChild(key)

            let fill = DirectionalLight()
            fill.light.intensity = 420
            fill.position = SIMD3<Float>(6, -2, 8)
            universe.addChild(fill)
        }
```

(Only three things changed inside the closure: the two `register*()` calls at the top, the `anchors` accumulation line inside the loop, and the `universe.components.set(...)` block after the loop. Everything else is verbatim Phase 1 code.)

(c) Update the `#Preview` at the bottom:

```swift
#Preview {
    UniverseView(selectedCategory: .design, selectedToolId: "figma", onProximityEvent: { _ in })
}
```

- [x] **Step 2: UniverseScreen — route events into the view-model**

In `ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift`, replace the `UniverseView` call (line 20):

```swift
            UniverseView(
                selectedCategory: model.selection.activeCategory,
                selectedToolId: selectedTool.id,
                onProximityEvent: { event in
                    // Web parity (Scene.tsx:420-421): onEnter selects the
                    // category, onExit returns to the overview ('all' ↔ .core).
                    switch event {
                    case .enter(let id):
                        model.selectCategory(id)
                    case .exit:
                        model.selectCategory(.core)
                    }
                }
            )
                .ignoresSafeArea()
```

- [x] **Step 3: Typecheck, then full test-build gate**

```bash
cd ios-app && xcrun swiftc -typecheck \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -target arm64-apple-ios18.0-simulator \
  $(find Sources -name '*.swift') && cd ..

cd ios-app && xcodegen generate && \
xcodebuild -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,id=01F7938F-C881-43B9-9222-0E78E63D7A51' \
  build-for-testing 2>&1 | tail -5 && cd ..
```

Expected: typecheck exits 0; `** TEST BUILD SUCCEEDED **`.

- [x] **Step 4: Commit**

```bash
git add ios-app/Sources/MyAIMap/Universe/UniverseView.swift \
        ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift
git commit -m "feat(ios): wire ProximityCategorySystem — pinch-zoom auto-opens/closes pockets"
```

---

### Task 4: Branch review + PR

- [x] **Step 1: Final verify on the whole branch**

```bash
cd ios-app && xcodegen generate && \
xcodebuild -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,id=01F7938F-C881-43B9-9222-0E78E63D7A51' \
  build-for-testing 2>&1 | tail -5 && cd ..
git log --oneline origin/main..HEAD
git status --short   # only the known PULL_REQUEST_TEMPLATE.md wart may show
```

Expected: `** TEST BUILD SUCCEEDED **`, exactly 3 commits, no stray staged files.

- [x] **Step 2: Push + PR**

```bash
git push -u origin feat/ios-phase2-proximity
gh pr create \
  --title "feat(ios): Phase 2 — ProximityCategorySystem (auto enter/exit pockets)" \
  --body "$(cat <<'EOF'
## Summary
- Step 4 of `docs/PHASE_2_PLAN.md`: RealityKit port of the web `ProximityCategoryWatcher` — pinch-zoom within 11 of a category anchor auto-opens its pocket; pulling past 22 auto-closes it (hysteresis + 160 ms tick throttle + 1.4 s cooldown + exit arming at 22×0.96, all web-parity).
- `ProximityWatcherCore`: pure Foundation+simd state machine (unit-tested, 10 tests).
- `ProximityCategorySystem` + `UniverseStateComponent`: thin ECS shell; events route to `UniverseViewModel.selectCategory` (`'all'` ↔ `.core`).

## Deviations from web
- Scene rebuild on category change (`.id(selectedCategory)`) restarts the 1.4 s cooldown clock per scene. No flicker is possible: the post-rebuild camera snap lands at ≈20.2 from the anchor, inside the 11–22 hysteresis band.

## Verify
- `xcodebuild build-for-testing` SUCCEEDED (app + test bundle compile).
- `xcodebuild test` remains blocked by the known CoreSimulator runner hang (`docs/AGENT_STATUS.md`); tests are committed and will run once the runner unblocks.

Plan with execution log: `docs/superpowers/plans/2026-06-10-ios-phase2-proximity-system.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

(Commit the plan file itself together with this step if not already committed: `git add docs/superpowers/plans/2026-06-10-ios-phase2-proximity-system.md && git commit -m "docs: proximity-system implementation plan"` before pushing.)
