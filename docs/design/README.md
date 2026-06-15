# UI/UX Direction

Last updated: 2026-06-15

This folder is the UI/UX specialist area. Put visual references, screenshots, critiques, interaction notes, and design acceptance criteria here.

## Visual Target

My AI Map should feel like:

- premium cosmic command center
- liquid glass controls
- readable luminous labels
- smooth spatial zoom into category worlds
- clear tool cards and explanations
- professional founder/operator product, not a toy demo

Avoid:

- random unreadable circles
- labels colliding everywhere
- abrupt hover flicker
- flat directory-like layouts
- excessive right-panel text
- decorative effects that hide the product meaning

## Required Screens

| Screen | UX Goal |
| --- | --- |
| Universe overview | User understands the AI ecosystem at a glance. |
| Category focus | User sees a mini-world with more spacing and stronger relationships. |
| Tool selected | User understands what the service is and why it connects. |
| Search/filter | User quickly narrows the universe without losing context. |
| Add tool input | User pastes a name/URL and sees classification feedback. |
| Mobile bottom sheet | User can inspect tools on iPhone without panel clutter. |

## Reference Screenshot Inventory

Current repo screenshots:

- `screenshots/ai-tool-universe-desktop.png`
- `screenshots/ai-tool-universe-hover-bubbles.png`
- `screenshots/ai-tool-universe-hover-focus.png`
- `screenshots/ai-tool-universe-relation-lens.png`
- `screenshots/ai-tool-universe-selected-tool.png`
- `screenshots/ai-tool-universe-search-scan.png`
- `screenshots/ai-tool-universe-clarity-focus.png`
- `screenshots/ai-tool-universe-design-cluster.png`
- `screenshots/vercel-camera-drag-compact-panel.png`
- `screenshots/vercel-large-logo-badges.png`

## Design QA Rubric

Score each item 1-5 before release:

| Area | 1 | 5 |
| --- | --- | --- |
| Orientation | User is lost | User always knows where they are |
| Readability | Labels collide | Labels are legible and staged |
| Interaction | Hover/click feels broken | Hover/click feels smooth and intentional |
| Visual Premium | Demo-like | App-store-worthy |
| Information | Too much or too little | Tool purpose and relationships are clear |
| Mobile | Hard to use | Natural mobile bottom-sheet experience |

Release target: no category below 4.

## Implementation: iOS Phase 3 visual system (backlog 18–31)

The "premium cosmic liquid glass" target above, in concrete RealityKit
terms. Web↔iOS constants are reconciled in `docs/UNIVERSE_CONSTANTS.md`;
this section is the *visual-language* map.

### Materials

| Surface | Material | Key params |
| --- | --- | --- |
| Tool / core node | `PhysicallyBasedMaterial` | base tinted + darkened by state (0.6–0.85), roughness 0.5 (core 0.35), metallic 0.05; emissive hierarchy 0.06→2.0 by focus/selection; selected adds clearcoat 0.6 / clearcoatRoughness 0.2 ("lit from within"). Web parity: `meshPhysicalMaterial` clearcoat 0.6 on focus (PR #79). |
| Category anchor | `PhysicallyBasedMaterial` | frosted glass, hue-tinted, faint emissive lift. |
| Pocket shell + rings | `UnlitMaterial` (transparent) | fixed brightness, independent of the light rig. |
| Labels (category + tool) | `UnlitMaterial` | `generateText`, billboarded; tool labels distance-faded. |
| Star field / galaxy dust / skybox | `UnlitMaterial` | ambient layers, never lit. |

### Lighting rig

- **Key** `DirectionalLight` 2 600, soft neutral, upper-left.
- **Fill** `DirectionalLight` 750, cool (R0.74 G0.80 B1.0), lifts shadowed hemispheres.
- **IBL** (backlog 29) — `ImageBasedLightComponent` from a procedurally
  generated equirectangular cosmic env map (`CosmicEnvironmentTexture`),
  cascaded to all PBR nodes via `ImageBasedLightReceiverComponent`. Replaces
  the earlier code-only bounce light; gives real reflections.
- **Skybox** (backlog 28) — `SkyboxEntity`, an inverted sphere (r=300) textured
  with the *same* env map so backdrop and reflections agree; SwiftUI radial
  gradient kept as fallback.

### Depth layers (near → far)

Node cloud → galaxy dust → star field (shell 120) → skybox (shell 300).

### Motion language

| Motion | Driver | Cadence |
| --- | --- | --- |
| Pocket-shell breathing + yaw sway | `ShellBreathingSystem` / pure `ShellBreathing` | scale ±1.8 % @ 0.32 rad/s, yaw ±0.04 rad @ 0.28 rad/s (web-matched) |
| Ring spins | `FromToByAnimation` (repeat) | per `PocketShellGeometry` spin rates |
| Founder halo breathe | `FromToByAnimation` | ±6 % over 2.6 s |
| Selection pulse | transform/emissive | eased on the selected node |
| Pocket fade-in | `OpacityComponent` + animation | 0.36 s (`BrandMotion.flow`) |
| Tool-label distance fade | `ToolLabelFadeSystem` / pure `ToolLabelFade` | opacity 1 ≤6 u → 0 ≥18 u |
| Camera transitions | `CameraController` / `PocketTransition` | eased, persistent scene (no rebuild) |

### Reduce-motion matrix (`accessibilityReduceMotion`)

| Element | Motion ON | Reduce-motion |
| --- | --- | --- |
| Pocket shell | breathe + sway + spins + fade-in | static at final opacity, no component attached |
| Founder halo | slow breathe | static |
| Selection pulse | animated pulse | static emphasis |
| Tool labels | distance-faded (camera-driven, not time) | distance fade retained (not a motion effect) |
| Camera retarget | eased fly | instant retarget |
| Star field / dust / skybox | static (no per-frame motion either way) | unchanged |

VoiceOver (backlog 30/31): every tappable entity carries
`AccessibilityComponent` label/value/hint, trait `.button`.

## How To Add References

Add files as:

```text
docs/design/references/<source>-<pattern>.md
docs/design/references/<source>-<pattern>.png
```

Each reference note should include:

```markdown
# Reference: <Name>

Why it matters:
- Specific reusable pattern.

Apply to My AI Map:
- Exact adaptation.

Do not copy:
- What to avoid.
```

