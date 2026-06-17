# Branded cold-launch state (no black frame)

**Phase:** A · **Lens:** app-quality

## Goal (1-2 lines)
Show a branded loading/empty state from app launch until the RealityKit scene + overlay are ready, so the user never sees a black frame on cold start.

## Repro / symptom (grounded in real code)
- `MyAIMapApp.swift:13-20` mounts `UniverseScreen` directly with `.background(Color.black)` (`UniverseScreen.swift:69`). The `RealityView` builds its whole scene synchronously in the make closure (`UniverseView.swift:29-46`, bracketed by a `scene.build` signpost) and heavy ambient layers (skybox/starfield/galaxy dust, `:189-203`) are added during that one-time build.
- Until the first frame renders, the user sees the black backdrop — there is no branded placeholder. A `ProgressOrb` ("doubles as the boot indicator before the RealityKit scene has any geometry on screen", `ShimmerLoader.swift:53-79`) already exists but is **never mounted** anywhere — confirmed: no reference in `UniverseScreen`/`UniverseView`. So today launch = black → pop-in (design A-quality §4).

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- Modify `Universe/UniverseScreen.swift` (overlay a branded boot state; cross-fade out on scene-ready).
- Modify `Universe/UniverseView.swift` (emit a `onSceneReady` callback once the make closure finishes / first update lands).

## Approach (bullet steps)
- Add an `onSceneReady: @MainActor () -> Void` to `UniverseView`; fire it at the end of the make closure (after `content.add(universe)` and ambient layers) or on the first `update` pass — whichever is the real "first frame has geometry" signal.
- In `UniverseScreen`, hold `@State private var sceneReady = false`; render a full-bleed branded boot overlay (radial cosmic gradient matching `UniverseView.background` `:339-349` + centered `ProgressOrb` from `ShimmerLoader.swift:57`) above the canvas while `!sceneReady`.
- Cross-fade the overlay out with `BrandMotion.resolved(...)` on `sceneReady`; honor Reduce Motion (`ProgressOrb` already gates its pulse, `:71-76`).
- Keep `.background(Color.black)` as the absolute floor so even pre-overlay paint is intentional dark, never a flash.

## Interface / contract
```swift
// UniverseView gains:
let onSceneReady: @MainActor () -> Void
```

## Tests (Tests/MyAIMapTests conventions)
- `BootStateTests` (ImageRenderer, like `SettingsSheetTests.swift`/`ChromeSnapshotTests.swift`): `UniverseScreen` renders non-nil in the pre-ready state (force `sceneReady == false`) and shows the `ProgressOrb` ("Loading universe" a11y label, `ShimmerLoader.swift:77`).
- Assert `ProgressOrb` renders non-nil and carries its accessibility label (reuse `AccessibilityLabelTests.swift` pattern).
- Scene-ready transition itself verified by simulator screenshot per design Testing section.

## Done criteria (checklist)
- [ ] Cold launch shows branded boot state, never a bare black frame.
- [ ] Overlay cross-fades out once the scene is ready.
- [ ] Reduce Motion: no pulsing/animated fade.
- [ ] `onSceneReady` fires exactly once on the real first-frame signal.

## Dependencies (other tasks)
- None hard. Coordinates loosely with Phase R render tasks (they also touch `UniverseView`).
