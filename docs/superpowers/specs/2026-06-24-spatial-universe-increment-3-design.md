# Spatial Universe — Increment 3: Motion & Feel (Design)

Date: 2026-06-24
Status: Design (roadmap-approved in Increment 1 spec); proceeding to plan
Scope: iOS app (`ios-app/`), `.spatial3D` render path only

## Context

Increments 1 (spatial spine) + 2 (atmosphere & material) are done on `feat/spatial-universe`, both READY TO MERGE, 2D untouched. Increment 3 is the final pass toward "feels like the future" (principles 7 + 8): **animations must feel physical and expensive; every interaction instantaneous.** The marquee lever: the camera fly-to currently lands on RealityKit's generic `.easeInOut`; the premium feel is an expo-out decelerate (the web build's `cubic-bezier(0.16, 1, 0.3, 1)`, already encoded as `BrandMotion.entry`).

Still Track A: only `.spatial3D` changes; 2D stays default and untouched.

## What Increment 3 delivers

1. **Premium camera motion.** The fly-to a sun / tool / detail decelerates on an expo-out cubic-bezier instead of `.easeInOut` — the "expensive" arrival that reads as physical, not mechanical. The 0.15s anticipation pullback stays as-is.
2. **Spring-driven reveal.** The selected-tool glass card (Increment 2) enters/leaves on a spring (`BrandMotion.reveal`) with a subtle parallax tilt, so the one piece of inline UI feels alive rather than popping in flat.

## Design decisions (defaults — flag to redline)

- **Camera curve:** reuse the web parity curve `cubic-bezier(0.16, 1, 0.3, 1)` as a RealityKit `AnimationTimingFunction.cubicBezier`. One named constant (`CameraEasing.fly`) so every fly-to shares it; the anticipation pullback (0.15s, `.easeOut`) is unchanged.
- **Reveal motion:** `BrandMotion.reveal` (existing spring, response 0.5 / damping 0.86) drives the card's appear/disappear; apply the existing `ParallaxTilt` effect for depth. Honor reduce-motion via the existing `BrandMotion.resolved` / `brandAnimation` path.
- **Deferred:** a full bespoke glass detail *panel* (restyling the shared `RootSheet`/`ToolDetailSection`) is NOT in this increment — that surface is shared with 2D and the constraint is "2D untouched." Detail content stays as-is; only 3D-side motion changes here. Typography/negative-space deep polish is best judged on a real device (see Risks) and is explicitly out of scope.

## Scope boundaries (hard)

- Only `.spatial3D`. 2D untouched. No data-model change. No new product features, no new navigation.
- Do not restyle the shared detail sheet content. Motion only.

## Success criteria

- Camera fly-to decelerates with a premium expo-out arrival (not linear/mechanical). (Real-device / sim-with-delay.)
- The reveal card springs in/out with subtle depth instead of a flat pop.
- Reduce-motion still collapses these to safe near-instant transitions.
- 2D unchanged; `npm run ios:verify` build + unit + smoke stay green.

## Risks

- Motion "expensive-ness" and the parallax amount are taste calls; the curve constant makes the *intent* testable, but the final feel needs a real-device eyeball. **Recommendation: device-test Increments 1–3 before any further visual polish** — continued tuning on simulator-only verification has diminishing returns.
- RealityKit `AnimationTimingFunction.cubicBezier` control-point API: confirm signature at build; fall back to `.easeOut` if unavailable (still better than `.easeInOut` for arrival).
