# iOS 3D Map — Visual / Motion Redesign Spec

Lens: senior visual + motion designer. Goal = top-tier App Store quality, pure liquid glass, 60fps on a 6" phone. This is a concrete, numbers-first redesign of the RealityKit universe in `Sources/MyAIMap/Universe/`.

---

## 0. Root cause of "looks terrible" (read this first)

Three structural mistakes, all in `UniverseView.swift`:

1. **Labels are extruded 3D text sized in METERS.** `MeshResource.generateText(font: .systemFont(ofSize: 0.8 …))` makes the word "Coding" **0.8 world units tall** (the font size *is* the world height — see the comment at `UniverseView.swift:636`). Tools use `0.32`. At overview distance (~20 units) and especially when the camera dollies to `minDistance 7.5`, these become screen-filling slabs. They have **no backing, no stroke, no fill plate** — raw glowing geometry. This is the #1 reason it reads as broken.
2. **The web reference never did this** — it used billboarded HTML *pill badges* (`.universe-label-tool` in `src/index.css:126`): 10px text, frosted dark gradient backing, 999px radius, 1px border, glow shadow. The iOS port silently dropped the badge and shipped bare 3D text. The fix is to **render labels as flat textured planes (a pre-rendered glass pill image), not 3D text.**
3. **Orbs look crude** because `generateSphere` defaults to a low tessellation AND the base color is mixed 75% toward black (`darkened(by: 0.75)`), so most orbs are near-black lumps with a faint rim. "Crooked" = the vertical-lift layout math (`UniverseLayout.toolPosition` `verticalLift`) scatters orbs on an irregular sine, reading as random tilt rather than clean orbits.
4. **Lines tangle** because every core→category (op 0.5) and category→tool (op 0.22) plus all inferred edges (op up to 0.62) draw simultaneously at full strength with no depth fade and no selection-based culling.

---

## 1. LABEL BADGES (highest priority — do this first)

**Replace 3D extruded text with billboarded flat planes carrying a pre-rendered pill texture.** Render the pill once into a `UIImage` (text + stroke + rounded dark plate) via `UIGraphicsImageRenderer`, upload as a `TextureResource`, map onto a `ModelEntity(mesh: .generatePlane)` with `UnlitMaterial`, keep `BillboardComponent`. This gives crisp text at any distance, a real backing, and a stroke — exactly the web badge — at a fraction of the geometry cost of extruded glyphs.

### Pill rendering spec (UIGraphicsImageRenderer, @3x)
- **Text:** SF Pro / system, weight `.semibold` (category) / `.medium` (tool). Render at **28pt category / 22pt tool** into the bitmap (this is bitmap px, not world units — world size is set by the plane below).
- **Text color:** `#F8FCFF` at 96% (matches web `rgba(248,252,255,0.96)`).
- **Stroke / outline:** draw the text twice — first a **1.5px outline** in `rgba(0,0,0,0.55)` (web `text-shadow`), then the fill on top. This is the "crisp outline/stroke" the user asked for.
- **Plate (badge backing):**
  - Fill: vertical gradient `#0E1726 @ 0.86 → #04081 2 @ 0.76` over a base `#04081 2 @ 0.82` (web `.universe-label`). Net: very dark translucent navy.
  - Corner radius: **full pill (height/2)** for category labels; tool labels also full-pill.
  - Border: **1px** `rgba(255,255,255,0.18)` outer; for the category, tint the border to the category color at ~40% mixed with white (web `border-color: ${color}66`).
  - Inset top highlight: 1px `rgba(255,255,255,0.18)` inner top line (the liquid-glass sheen).
  - Padding: **category 7×10pt, tool 4×7pt** (web parity).
- **Optional leading color dot:** an 8px filled circle in the category color at the left of tool labels (mirrors the ChatDock match-card dot) — instantly ties orb→label.

### World sizing (the part that's currently broken)
Set the plane's **world height by a target on-screen size**, not a fixed meter value. Use a fixed pixel-per-world heuristic: the label plane height in world units should be ≈ `kLabel * distanceToCamera`, where the system already knows distance (the fade system reads it). Practical static values that read correctly at the current framings:
- **Category label plane height: 0.42 world units** (down from the effective 0.8 of the glyph cap-height; the plate makes it look bigger, so the glyph can be smaller).
- **Tool label plane height: 0.26 world units.**
- Plane width = height × (bitmap aspect), so text never stretches.
- Keep the existing `labelInset 0.78` radial pull-in for edge categories.

### Lift (clear the orb, no overlap)
- Category lift: `baseAnchorRadius (0.48) + 0.34` above the anchor.
- Tool lift: `orbRadius + 0.22`. Currently `toolLabelLift 0.5` is fine; tie it to the orb's actual radius so big orbs don't get a label sitting inside them.

### Fade & declutter (keep 49 nodes legible)
- Keep `ToolLabelFadeSystem`. Tighten the curve: `nearDistance 7 → far 15` (was 6→18) so tool labels vanish faster as you pull back — only the pocket you're in shows tool names.
- **Never show all 49 tool labels at once.** Only render tool labels for: (a) the open pocket, plus (b) the single selected tool. Overview = category labels only (7 pills) + selected-tool pill. This is the single biggest legibility win on a 6" screen.
- Add a **per-frame max-opacity arbitration**: if two label centers project within ~36pt on screen, fade the lower-priority one (orbit 3 < orbit 1, unselected < selected). Cheap: compare projected screen positions in the fade system.

---

## 2. ORB / PLANET MATERIALS

### Tessellation (fixes "crude/blocky")
`MeshResource.generateSphere` is fine but generate at higher detail for the few hero spheres. RealityKit's sphere is already smooth-ish; the perceived crudeness is mostly the dark matte + emissive rim. Primary fix is material, not mesh. If still faceted on device, swap to a `MeshResource.generate(from:)` icosphere at ~3 subdivisions for the core + category anchors only (8 spheres), leave tool orbs as default.

### Color system (per category, from seed JSON — already defined)
| Category | Hex | Use |
|---|---|---|
| coding | `#6EE7FF` cyan | |
| design | `#FF8BD2` pink | |
| research | `#7FFFD4` aqua | |
| media | `#FFD166` amber | |
| distribution | `#9BFF8A` green | |
| infrastructure | `#A78BFA` violet | |
| knowledge | `#F0ABFC` orchid | |
| analytics | `#FF9BD2` rose | |
| core | `#D8FAFF` ice | hero |

These are good, vivid, well-separated hues — keep them. The problem is they're crushed by `darkened(by: 0.75)`.

### Material tuning (replace current `styleToolNode` values)
Goal: orbs read as **glowing colored glass beads**, not black lumps.
- **Base color darken:** overview `0.55` (was 0.75), pocketed `0.45`, selected `0.30`, dimmed `0.80`. Lighter base = the hue is visible at rest.
- **Emissive intensity:** overview `0.35` (was 0.18), pocketed `0.7`, selected `1.6`, dimmed `0.05`. (Web parity ToolNode: `0.16 / 0.55 / 0.72 / 1.35`.)
- **Roughness:** tool `0.38` (was 0.5 — glossier reads richer), core `0.3`.
- **Metallic:** `0.0` for tools (a colored dielectric bead), `0.1` core.
- **Clearcoat:** selected `0.6` / roughness `0.2` (keep). Add a faint `0.15` clearcoat to *all* orbs so the IBL gives every bead a single specular hotspot — this is what makes them look round and lit, killing the "crooked" flat look.
- **Add an additive aura halo** behind selected + pocketed orbs (the web `AURA_GEOM` at 0.46 radius, additive, opacity selected 0.18 / focus 0.38). A separate unlit additive sphere child, scaled 1.2–1.6×. This is the "subtle glow/depth" the user wants and it cheaply hides tessellation.

### Size hierarchy (core > category > tool, must be obvious)
Current radii are too flat. Target *appeared* radii:
- **Core (founder):** 0.55 selected / 0.42 rest (it's the hero — bump from 0.46/0.24-derived). Keep the frosted `founder-halo` at 1.2 but raise opacity 0.12 → 0.16 and emissive 0.4 → 0.55.
- **Category anchor:** 0.48 base / 0.74 selected (keep) — but make the frosted shell read: opacity rest `0.42` (was 0.5 felt muddy), selected `0.9`.
- **Tool orbs:** keep orbit-based `0.24 + orbit*0.025` but **widen the spread** so orbit tiers are legible: `0.22 + orbit*0.05` (orbit 3 = 0.37 vs orbit 1 = 0.27). Selected boost to `0.44 + orbit*0.05`.
- Net visual ladder: core ≈ 2× a mid tool, category shell ≈ 1.3× a tool — a clear three-step hierarchy.

---

## 3. CONNECTION LINES (de-tangle)

Current: 3 line classes all drawn at full strength, no depth awareness, opacity up to 0.62. On a phone this is the "messy" the user sees.

### New opacity / thickness ladder (subtle by default, lit by selection)
- **Core → category (structural spine):** opacity `0.28` (was 0.5), thickness `0.014` (was 0.02). Always visible but quiet — it's the skeleton.
- **Category → tool:** opacity `0.10` (was 0.22), thickness `0.008`. Barely-there filaments at rest.
- **Inferred (violet `#C9B4FF`):** opacity `0.06 + confidence*0.30` (range 0.06–0.36, was 0.12–0.62), thickness `0.006 + confidence*0.008`. These should *whisper*.

### Selection-driven emphasis (the key move)
Lines are currently static. Make link opacity **state-aware** like the orbs:
- A link **touching the selected tool or open category** brightens to opacity `0.6` and thickness `0.018`, in that endpoint's color.
- All other links drop to `0.05`. Result: at rest the graph is a faint web; on selection a clean constellation lights up around the focus. This is exactly the web `ConnectionLines` relationDepth behavior.
- Implement as a restyle pass in `applyLayout` (links are named `link:…` / `inferred:…`, easy to find), or a lightweight system. No per-frame cost — only restyle on selection change.

### Depth fade
Optionally fade link opacity by distance-to-camera in a system (reuse the label fade pattern) so far links recede. Lower priority than the selection emphasis.

### Curvature
Web uses `QuadraticBezierLine` (gentle arcs). Straight boxes read as a wireframe cage. If time allows, render category→tool links as a short 6-segment arc (slight outward bow) — arcs read as "organic connections," straight lines read as "scaffolding." Lower priority.

---

## 4. BACKGROUND / STARFIELD

Currently 220 tiny spheres on a 120-unit shell + radial gradient + skybox + galaxy dust. Mostly good; tune for depth and to stop competing with nodes.

- **Star sizes:** bright `0.42` / dim `0.26` world units at radius 120 — at that distance they're fine, but reduce **bright opacity 0.7 → 0.55**, keep dim 0.38. The current stars are slightly too present.
- **Add a third, faint tier** (50 stars, radius 90, opacity 0.2, size 0.18) for parallax depth between dust and main shell — cheap, big payoff.
- **Background gradient (`UniverseView.swift:339`):** keep the category-tinted radial but lower the tint `0.18 → 0.12` so the backdrop doesn't wash the orbs. Core gradient: center `selectedColor @ 0.12 → #02030A → #000`. The deep near-black center makes the glass orbs pop.
- **Vignette:** add a subtle SwiftUI radial dark vignette overlay (transparent center → `black @ 0.35` edge) on top of the RealityView. Standard cinematic framing; focuses the eye on the central cluster on a small screen.
- Galaxy dust: keep but cap at very low opacity (≤0.06) — it should be felt, not seen.

---

## 5. SPACING / DENSITY for 49 nodes on a 6" screen

The layout math (`UniverseLayout`) is largely good (category ellipse 4.55×3.45, orbit radii 0/0.96/1.48/1.98). Issues:
- **`verticalLift` (toolPosition) is too noisy** — `sin(toolRad*1.35 + categoryAngle*0.03) * (0.48 + orbit*0.12)` scatters orbs vertically, which reads as "crooked." **Halve the amplitude** to `0.24 + orbit*0.06` so tools sit closer to a clean tilted orbital plane. Keeps depth, kills the random-tilt look.
- **Overview is crowded** (8 categories × up to 11 tools near the center). On portrait, push the category ellipse out ~10%: `categoryRadiusX 5.0, categoryRadiusZ 3.8` so clusters breathe and don't overlap the core's halo.
- **Default framing:** overview eye `(0, 6.3, 19.5)` is okay but the cluster fills <60% of a tall screen. Pull in to `(0, 5.5, 17.5)` for overview so the universe fills the frame; keep pocket as-is.
- **Pocket layout** (Fibonacci sphere, radii up to 6.4) is good — it's the showcase. Ensure pocket tool labels (max ~11) use the declutter rule above.

---

## 6. MOTION (spring, 60fps, the "Apple" feel)

The app already has `BrandMotion` springs for UI. The 3D scene uses RealityKit `Entity.move(timingFunction: .easeInOut)` — replace key transitions with **spring-like timing** for the premium feel:
- **Pocket open/select:** keep `PocketTransition.duration 0.55` (web `smoothTime`), but the camera retarget and orb scale should feel springy. RealityKit `move(to:)` only offers ease curves; emulate a spring by using `.easeOut` with a tiny overshoot keyframe (scale to 1.04× then settle to 1.0 over the last 30%). Most impactful on the **selected orb** and the **category anchor grow**.
- **Selection pulse:** current ±3% / 1.1s breathing is too subtle to notice and competes with everything. Make it ±5% / 1.4s **only on the selected orb**, plus pulse the aura halo opacity (0.18↔0.28) in sync. Disable on reduce-motion (already handled).
- **Label entrance:** new pills should fade + scale-in (0.85→1.0) over 0.32s with the web easing `cubic-bezier(0.16,1,0.3,1)` (approximate via `.easeOut`). Drives that "things settle into place" polish.
- **Haptics:** the app has `BrandHaptics`. Fire `.light` on orb tap-select, `.medium` on pocket open, `.success` on fly-to settle. Wire in `handleTap`/`handleDoubleTap` (`UniverseView.swift:356`) — currently selection routes through the VM; confirm a haptic fires on the 3D tap path, not just the 2D list.
- **Tap feedback in 3D:** on tap, a quick scale-down-then-up (0.92→1.06→1.0 over 0.25s) on the tapped orb before the camera moves — the press-feedback the user asked for, in the scene itself.

---

## 7. Prioritized implementation order

1. **Labels → flat glass pill planes** (Section 1). Single biggest fix; kills "gigantic text" + adds stroke/badge the user explicitly asked for.
2. **Declutter labels** (overview = 7 category pills + selected only). Cheap, huge legibility win.
3. **Orb materials** (Section 2): lighter base, higher emissive, universal clearcoat 0.15, selection aura halo. Kills "crude/crooked."
4. **Connection-line ladder + selection emphasis** (Section 3). Kills "messy tangle."
5. **Layout calm**: halve `verticalLift`, push category ellipse out, tighten overview framing (Section 5).
6. **Background**: lower tint, add vignette + faint star tier (Section 4).
7. **Motion polish**: springy select, label fade-in, 3D tap feedback + haptics (Section 6).

---

## 8. Exact tokens (copy-paste reference)

```
// Labels (bitmap px @3x; world height in units)
labelTextColor        = #F8FCFF @ 0.96
labelOutline          = #000000 @ 0.55, 1.5px
labelPlateGradient    = [#0E1726@0.86 → #040812@0.76]
labelBorder           = #FFFFFF @ 0.18, 1px (category: mix category@0.40)
labelInnerHighlight   = #FFFFFF @ 0.18, 1px top inset
categoryGlyphPt       = 28 ; toolGlyphPt = 22
categoryPlanePadding  = 7×10pt ; toolPlanePadding = 4×7pt
categoryPlaneHeight   = 0.42 world ; toolPlaneHeight = 0.26 world
categoryLift          = anchorR + 0.34 ; toolLift = orbR + 0.22
fadeNear = 7 ; fadeFar = 15 ; screenDeclutterPx = 36

// Orbs
darken: overview 0.55 / pocket 0.45 / selected 0.30 / dimmed 0.80
emissive: overview 0.35 / pocket 0.70 / selected 1.60 / dimmed 0.05
roughness 0.38 (core 0.30) ; metallic 0.0 (core 0.10) ; clearcoat 0.15 (sel 0.60)
toolRadius = 0.22 + orbit*0.05 (sel 0.44 + orbit*0.05)
coreRadius = 0.42 (sel 0.55) ; founderHalo op 0.16 / emissive 0.55
anchorOpacity = 0.42 rest / 0.90 selected
aura: additive unlit sphere, scale 1.2–1.6, op sel 0.18 / focus 0.38

// Lines
core→category : op 0.28 / thick 0.014
category→tool : op 0.10 / thick 0.008
inferred(#C9B4FF): op 0.06+c*0.30 / thick 0.006+c*0.008
selected-touching: op 0.60 / thick 0.018 (endpoint color) ; others op 0.05

// Background
bgTint 0.12 ; bgCenter #02030A ; vignette edge #000 @ 0.35
star bright op 0.55 / dim 0.38 / faint tier (50 @ r90, op 0.20, size 0.18)

// Layout
categoryRadiusX 5.0 ; categoryRadiusZ 3.8
verticalLift amplitude → 0.24 + orbit*0.06 (halved)
overview eye (0, 5.5, 17.5)

// Motion
pocket/select 0.55s easeOut + 1.04 overshoot
selection pulse ±5% / 1.4s (selected orb + aura only)
label entrance fade+scale 0.85→1.0 / 0.32s easeOut
tap feedback 0.92→1.06→1.0 / 0.25s ; haptics light/medium/success
```

---

## Appendix — relevant files

- `Sources/MyAIMap/Universe/UniverseView.swift` — all label/orb/line/material construction (`makeCategoryLabel` :695, `makeToolLabel` :653, `styleToolNode` :863, `styleAnchor` :892, `makeLink` :537, `makeCategoryRing` :576, `makeFounderHalo` :769, label sizes :636/:645, bg gradient :339).
- `Sources/MyAIMap/Universe/UniverseLayout.swift` — `verticalLift` :40, category ellipse :11-13.
- `Sources/MyAIMap/Universe/Entities/ToolLabelFade.swift` — fade curve (near 6 / far 18 → 7 / 15).
- `Sources/MyAIMap/Universe/ECS/ToolLabelFadeSystem.swift` — per-frame opacity; add screen-projection declutter here.
- `Sources/MyAIMap/Universe/Camera/PocketTransition.swift` — radii, scales, durations.
- `Sources/MyAIMap/Universe/Entities/StarFieldGeometry.swift` / `StarFieldEntity.swift` — star tiers/opacities.
- `Resources/ai-tool-universe.seed.json` — category colors/angles (source of the color table above).
- Web parity references: `src/index.css:87-264` (pill badge spec), `src/components/AIToolUniverse3D/ToolNode.tsx` (emissive/aura ramps), `ConnectionLines.tsx` (relation-depth line emphasis).

Note (out-of-lens, flag only): the chat scroll-to-bottom in `ChatDock.swift:76` scrolls on `turns.map(\.id)` change, but the last turn's height grows *after* the id append (answer text + match cards mount), so `.bottom` anchor lands short. A separate UX/code lens should switch to scrolling on a content-size change or add a post-layout re-scroll.
