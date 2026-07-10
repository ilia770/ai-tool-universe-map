# Neural Universe (iOS) — Design Spec

Date: 2026-07-10 · Approved by user (brainstorm session): metaphor = **Neural
Universe (web variant O → iOS)**; strategy = **one hero renderer** (both Bloom
2D and PBR-planets retire). User diagnosis of current renderers: flat/cheap,
boring planet metaphor, dead/static, not the web-O vibe. User left for ~24h
with explicit instruction to build autonomously.

## Vision

The universe is a living neural network: translucent glass neurons, glowing
synapse threads with light impulses running along them, cinematic depth.
Calm, premium, alive — Vision-Pro-glass meets Cosmograph, on RealityKit.

## Visual system (replaces PBR-planet look; layout/camera/gestures unchanged)

- **Neuron (category)** = persistent entity trio on the existing
  `PlanetHandle`: outer glass shell (PBR, transparent blending, low roughness,
  high clearcoat, near-zero metallic, faint tint), bright **emissive core**
  sphere inside (~0.45× shell radius, category accent, gentle intensity
  pulse), additive **rim glow** shell (fresnel fake). No opaque balls.
- **Founder OS core** = largest neuron, white-cyan; keeps the breathing halo.
- **Synapses (links)** = existing `LinkGeometry` lines, dimmer base, plus
  **light pulses**: small additive emissive beads animating from→to along
  each link, staggered, looping (`FromToByAnimation` on position — ECS-cheap,
  frame-rate independent). Budget ≤ 24 live beads; pause-aware (Reduce
  Motion / detail / chat / hidden).
- **Tools (satellites)** = small glass beads with emissive cores, same
  language, on the existing `SatelliteBranch`.
- **Depth cue** = static per-node dimming tier from authored layout depth
  (no per-frame fog math).
- **Selection choreography** = focused neuron core brightens + shell clears
  (roughness ×0.6), its links pulse faster (clip restart), others dim via
  existing `UniverseMode` opacity projections. No rings/borders.
- **Background** = keep void gradient + restrained stars.

## Architecture

No new subsystems: the Phase-2/3 foundation (PlanetHandle registry,
SatelliteBranch, structure signature, CameraRigController, InteractionPhase,
descriptors) carries the redesign — only entity APPEARANCE builders and a new
`SynapsePulses` helper (owns bead entities per link set, start/stop/pause)
change. Single renderer: `UniverseRealityView` becomes the only map;
`BloomGraphView`/`BloomEngine`/`BloomAdjacency` + the 2D/3D toggle +
`UniverseRenderMode` retire (stored pref ignored on load).

## Slices (WS-NU in LOOP_QUEUE; gate each: compile + 40x-suite + sim shot)

- NU.0 land pending VO-bridge + implementation report; commit spec.
- NU.1 Neuron look (shell/core/rim materials on PlanetHandle + SatelliteHandle).
- NU.2 Synapse pulses (bead system, stagger, pause matrix).
- NU.3 Depth tiers + core emissive pulse + selection choreography.
- NU.4 Single renderer: delete Bloom + toggle + renderMode (AFTER NU.1-3
  visuals verified on sim — destructive step last).
- NU.5 Polish vs web-O reference + perf sanity (entity budget, cold-boot) +
  reduce-motion matrix; screenshots for user review.
- NU.6 Docs closeout (implementation report update, LOOP_LOG, memory).

Risks: RealityKit iOS has no true refraction/bloom — glass is
transparent-PBR + additive rim (proven pattern in repo); pulses are entities,
not shaders (CustomMaterial deferred). Sim cold-boot ~40s ≠ hang. If Neural
look flops on sim, Bloom still exists until NU.4 — reversible.
