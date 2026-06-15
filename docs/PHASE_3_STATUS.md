# iOS Phase 3 — visual parity status

Last updated: 2026-06-15. Owner: Claude Code. Render path: RealityKit
(canonical, see `docs/AGENT_STATUS.md`).

Phase 3 = backlog tasks 18–31 (Phase C in `docs/CLAUDE_BACKLOG.md`). Authored
retroactively as a *completion* record: the slices shipped ahead of a separate
plan doc, each test-gated on the ClaudeGate simulator and PR-merged.

## Slices

| # | Task | PR | Notes |
| --- | --- | --- | --- |
| 18 | Connection lines | #68 | `LinkGeometry`, core→cat→tool; pocket re-layout deferred |
| 19 | Star field | #69 | 220 stars, Fibonacci shell r=120, two tiers, shared mesh/material |
| 20 | Galaxy dust | #70 | sparse translucent haze, mid shell |
| 21 | Sparkles in pocket | #70 | `SparkleFieldEntity`, rides the shell lifecycle |
| 22 | Shell breathing + yaw sway | #77 | `ShellBreathingSystem`, pure curve, reduce-motion static |
| 23 | Category rings | #70 | orbit ring + billboarded label per anchor |
| 24 | Node selection pulse | #70 | emissive/transform pulse, reduce-motion static |
| 25 | Tool monogram textures | — | **superseded by 26** (sphere-mapped letters distort) |
| 26 | Billboarded tool labels | #78 | `ToolLabelFadeSystem`, distance-faded, pocket-scoped |
| 27 | Founder core hero halo | #70 | frosted shell + slow breathe |
| 28 | Skybox / background depth | #76 | `SkyboxEntity` inverted sphere, shares the IBL env map |
| 29 | IBL / environment lighting | #72 | `CosmicEnvironmentTexture` → `ImageBasedLightComponent` |
| 30/31 | Reduce-motion + VoiceOver | #71 | a11y sweep + `AccessibilityComponent` on every tappable entity |

Plus the CI unblock (#73) that turned the iOS verify workflow green after the
Phase C batch.

## Test gate

Full `xcodebuild test` on ClaudeGate (`4E244EB6-…`, iPhone 16 Pro, iOS 26.5)
per slice. **142 tests** on main after #78. iOS CI (`ios.yml`, Xcode 16.4)
green on main.

## Carried forward

- Connection lines don't follow pocket re-layout (deferred, #68 note).
- Web↔iOS material parity: clearcoat sheen proposed in PR **#79**
  (web visual change — pending desktop/mobile review, not auto-merged).
- Phase B tail (13 dolly-to-cursor, 17 camera-feel tuning) — low priority,
  device-class tuning.

## Design spec

The implemented visual system (materials, lighting rig, IBL, skybox, motion
language, reduce-motion matrix) is documented in `docs/design/README.md` →
"Implementation: iOS Phase 3 visual system".
