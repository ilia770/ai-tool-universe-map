# Universe 3D — Canonical Constants (web ↔ iOS)

Last audited: 2026-06-11 (backlog task 39). Both ports MUST keep these in
sync; when you change one side, update the other (or file it here as an
intentional deviation). Sources of truth: web `src/components/
AIToolUniverse3D/layout.ts` + scene components; iOS `ios-app/Sources/
MyAIMap/Universe/`.

Audit verdict 2026-06-11: **100 % match on all 33 shared constants.**
No unintended drift. Deviations below are intentional and documented.

## Layout

| Name | Value | Web | iOS |
| --- | --- | --- | --- |
| pocketWorldRadius | 7.0 | `layout.ts` | `UniverseLayout.swift` |
| categoryRadiusX / Z | 4.55 / 3.45 | `layout.ts` | `UniverseLayout.swift` |
| orbitRadii | [0, 0.96, 1.48, 1.98] | `layout.ts` | `UniverseLayout.swift` |
| pocketOrbitRadii | [0, 2.9, 4.6, 6.4] | `layout.ts` | `UniverseLayout.swift` |
| goldenAngle | π·(3−√5) | `layout.ts` | `UniverseLayout.swift` |
| category Y lift / angle scale | 1.35 / 1.7 | `layout.ts` | `UniverseLayout.swift` |
| tool Y lift base / orbit scale | 0.48 / 0.12 | `layout.ts` | `UniverseLayout.swift` |
| tool Z radius scale | 0.78 | `layout.ts` | `UniverseLayout.swift` |
| pocket Y scale / local-angle blend | 0.62 / 0.22 | `layout.ts` | `UniverseLayout.swift` |

## Pocket shell

| Name | Value | Web | iOS |
| --- | --- | --- | --- |
| shellScale | (1.18, 0.18, 0.74) | `PocketWorldShell.tsx` | `PocketShellGeometry.swift` |
| shellOpacity | 0.052 | same | same |
| outer/inner ring opacity | 0.28 / 0.12 | same | same |
| outer/inner tube radius | 0.018 / 0.012 | same | same |
| innerRadiusFactor | 0.64 | same | same |
| ring spins (rad/s) | +0.035 / −0.055 | same | same |
| innerRingTilt (XYZ Euler) | (π/2.18, 0.24, 0.2) | same | same |
| ring segments (radial, tubular) | (8, 104) / (8, 88) | same | `PocketShellEntity.swift` |
| pocketNodeScale | 1.18 | — (iOS-only, PHASE_2_PLAN step 5) | `PocketShellGeometry.swift` |
| shell fade duration | 0.36 s | per-frame lerp ×0.04 | one-shot ease-out (see deviations) |

## Camera

| Name | Value | Web | iOS |
| --- | --- | --- | --- |
| minDistance / maxDistance | 7.5 / 46 | `CameraController.tsx` | `CameraController.swift` |
| smoothTime (normal / reduced) | 0.55 / 0.04 | same | same |
| overview offset | (0, 6.3, 19.5) | same | same |
| pocket offset | (0, 6.8, 19.0) | same | same |
| node offset | (0, 5.0, 15.5) | same | same |
| draggingSmoothTime | 0.08 | web-only (mouse inertia) | sync when orbit drag lands (backlog 11) |
| orbit pitch clamp | ±0.55 rad | TBD on web (backlog 42) | iOS-only today |

## Proximity watcher

| Name | Value | Web | iOS |
| --- | --- | --- | --- |
| enterDistance / exitDistance | 11 / 22 | `ProximityCategoryWatcher.tsx` | `ProximityWatcherCore.swift` |
| tickInterval | 160 ms | same | same |
| cooldown | 1400 ms | same | same |
| armFactor | 0.96 (arm at 21.12) | same | same |

## Search

| Name | Value | Web | iOS |
| --- | --- | --- | --- |
| max search results | 6 | `AIToolUniverseMap.tsx` (`slice(0, 6)`) | `SearchCore.maxResults` |

## Intentional deviations

1. **Shell fade** — web lerps opacity per frame (`+= (0.052 − o) × 0.04`);
   iOS plays one 0.36 s ease-out fade because the scene rebuilds via
   `.id(selectedCategory)` (no persistent entity). Same visual outcome.
2. **Shell breathing (±1.8 %) + group yaw sway** — dropped on iOS
   (sub-2 % ambient effects); rings still spin. Revisit with backlog 22
   (needs the persistent scene container, backlog 16).
3. **Web-only, pending port:** Sparkles particle field (backlog 21),
   "Pocket world · N tools" readout (backlog 8).
4. **iOS-only:** procedural torus generation (RealityKit has no torus
   primitive), tap targets on entities, PBR materials + lighting rig
   (PR #43), pocketNodeScale 1.18.
