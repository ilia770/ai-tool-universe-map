# R-motion — UniverseMotion
**Phase:** R · **Lens:** render

## Goal (1-2 lines)
A small pure motion helper: ease-out-expo for reframes/selection, frame-rate-independent smoothing `1 − exp(−k·dt)` for the overlay's per-frame lerps (orb scale, halo, parallax), and a single Reduce-Motion gate. Replaces ad-hoc `.easeInOut` and the snapping materials.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- create `Sources/MyAIMap/Universe/Overlay/UniverseMotion.swift` (pure: Foundation only for the math; a thin SwiftUI `Animation` accessor).
- reuse `Sources/MyAIMap/UI/Theme/BrandMotion.swift` — `resolved(_:reduceMotion:)` is the existing Reduce-Motion gate; do NOT add a second one, wrap it.
- consumed by R-node-badge (entrance), R-orb-layer (scale/pulse), R-connection-canvas (emphasis), R-viz-switcher (style cross-fade).

## Approach (bullet steps)
- `smoothing(k:dt:)` → `1 − exp(−k·dt)`: the lerp factor used each frame so motion is identical at 60 and 120 Hz (no per-frame constant). `lerp(current,target,t)` helper.
- `easeOutExpo(_:)` curve matching the web signature `cubic-bezier(0.16,1,0.3,1)` for discrete transitions (selection settle, reframe), exposed as a SwiftUI `Animation` via `BrandMotion.entry`-style spring or a custom timing curve.
- Reduce-Motion: route every animation through `BrandMotion.resolved(_:reduceMotion:)`; when reduced, `smoothing` returns 1 (snap) and curves collapse to near-instant — one gate, consistent (fixes the lenses' "inconsistent Reduce-Motion" finding).
- Selection pulse helper: `pulse(time:amplitude:period:)` (±5% / 1.4s) for the selected orb + aura only; returns 1.0 under Reduce Motion.
- No timers here; callers drive `dt` from `TimelineView`.

## Interface / contract
```swift
enum UniverseMotion {
    static func smoothing(k: Float, dt: Float) -> Float           // 1 - exp(-k·dt), clamped [0,1]
    static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float
    static func easeOutExpo(_ x: Float) -> Float                  // (0.16,1,0.3,1) approx
    static func pulse(time: Float, amplitude: Float, period: Float, reduceMotion: Bool) -> Float
    static func transition(reduceMotion: Bool) -> Animation       // wraps BrandMotion.resolved
}
```

## Tests (`Tests/MyAIMapTests`)
- create `Tests/MyAIMapTests/UniverseMotionTests.swift` (pure, like `ToolLabelFadeTests`/`PocketTransitionTests`):
  - `smoothing` ∈ [0,1], increases with `dt` and with `k`; → 1 as dt→∞.
  - frame-rate independence: two half-steps approximate one full step within tolerance (vs naive constant lerp which diverges).
  - `easeOutExpo(0)==0`, `easeOutExpo(1)==1`, monotonic, front-loaded (fast then settle).
  - `pulse` stays within `1 ± amplitude`; returns 1.0 when `reduceMotion`.
  - `smoothing` returns 1 (snap) path under reduce-motion contract.

## Done criteria (checklist)
- [ ] Frame-rate-independent smoothing (`1 − exp(−k·dt)`), unit-tested at 60/120 Hz steps.
- [ ] Ease-out-expo matches web signature for discrete transitions.
- [ ] Single Reduce-Motion gate via existing `BrandMotion.resolved` — no duplicate gate.
- [ ] Pure math headless-tested; clamped.

## Dependencies (other tasks)
- Reuses `BrandMotion`. Consumed by R-node-badge, R-orb-layer, R-connection-canvas, R-viz-switcher.
