# SYNTHESIS — iOS "My AI Map" Visualization & App-Quality Research

Converged from six lens reports (ios-hig, designer-viz, viz-tech, product, qa, launch),
grounded in `Sources/MyAIMap/Universe/UniverseView.swift`. Date: 2026-06-16.
This brief feeds a brainstorm → design. It is decisive about the problem and offers
the user a clear viz-direction choice.

---

## 1. AGREED PROBLEMS (all/most lenses concur)

**Root cause — 6/6 lenses, unanimous:** the universe renders an **information graph in a
3D world-space engine**, so the things users read have no fixed pixel size.

- **P0 · Labels are world-space extruded 3D text sized in METERS.**
  `MeshResource.generateText(font: .systemFont(ofSize: 0.8 …))` → "Coding" is 0.8 world
  units tall; tools 0.32 (`UniverseView.swift:636,645`). No badge, no stroke, no plate,
  no max-width, no Dynamic Type. Balloons on dolly. This is the #1 "GIGANTIC/crooked"
  complaint and named the single highest-leverage fix by ios-hig, designer-viz, viz-tech,
  qa, and launch. **Unanimous.**
- **P0 · Connection lines are world-thickness boxes** (`makeLink`, thickness 0.008–0.02m),
  so sub-pixel at overview, crude bars up close, aliased, straight/overlapping ("messy"),
  AND static — they do not re-route when a pocket opens, so lines detach from nodes.
- **P0 · Orbs read crude/crooked** — default-tessellation `generateSphere`, base color
  crushed `darkened(by: 0.75)` → near-black lumps; materials *snap* on selection (no tween);
  noisy `verticalLift` scatters orbs so orbits look randomly tilted.
- **P0 · App-quality breakage (separate from viz):** chat does not scroll to bottom;
  chat composer unmounts when the detail sheet expands; dead buttons (Settings→History,
  double-tap == single-tap); black screen on cold launch (all scene build + IBL + edge
  inference is synchronous, no loading state); promised "+" Add-Tool button does not exist.
- **P1 · Product structure:** two competing query inputs (SearchDock + ChatDock) do the
  same job; "find fast" is a HUD floating over a moving 3D scene; six surfaces compete for
  one screen. (Product lens; others corroborate the "cluttered" feel.)

**Decisive read:** these are framework-shaped problems, not tuning bugs. Every finalist on
the web reference (BrainGraph, Bloom, Force3D, NeuralUniverse) uses **screen-space/billboarded
text with a stroke + dark badge, additive glow sprites for nodes, AA line strokes, and
focus-driven progressive label reveal** — never world-extruded text. The iOS port is the
only place that diverged, which is exactly why it looks worse than its own web reference.

---

## 2. RECOMMENDED VIZ DIRECTION — **"Overlay-Native Universe"** (Direction A)

Keep RealityKit ONLY for ambient cosmic depth; render everything users read in a
screen-space overlay. Highest quality-per-effort, lowest risk, preserves the brand "space"
feel, and fixes labels + lines + orbs legibility in one architectural move.

**Rendering approach:** RealityKit starfield/nebula as a slow ambient *background layer*;
the interactive graph (orbs, edges, labels) drawn in a **SwiftUI overlay** — a `Canvas`
for edges/orb glows + SwiftUI `Text` badges projected from each node's world position
(via camera `project(point:)`, throttled ~30Hz). This is the agreed end-state across
ios-hig, viz-tech, and launch.

**Label badge (the marquee fix) — concrete spec (web-token parity):**
- Capsule (radius = height/2). Text `#F8FCFF` @ 0.96, drawn with a 1.5px `#000` @ 0.55
  outline then fill. Plate: vertical gradient `#0E1726@0.86 → #040812@0.76`. Border 1px
  white @ 0.18 (category border tinted to the category color ~40%). 1px inner top highlight.
- Type via `@ScaledMetric` (Dynamic Type): category ≈ `.caption.bold` (~12pt), tool
  ≈ `.caption2.semibold` (~10–11pt), focused ≈ `.subheadline.bold`. `lineLimit(1)`,
  `minimumScaleFactor(0.85)`, max-width ~116 (tool) / 232 (focus) pt.
- Optional leading category-color dot on tool labels (ties orb→label).
- **Declutter (biggest legibility win):** overview shows only the 7 category pills + the
  selected tool. Tool labels appear only for the open pocket + selection. Screen-space
  collision: if two label centers project within ~36pt, fade the lower-priority one.

**Orb spec:** lighter base (`darken` overview 0.55 / pocket 0.45 / selected 0.30),
emissive 0.35 / 0.70 / 1.60; universal clearcoat 0.15 (selected 0.60); add an **additive
aura halo** child (scale 1.2–1.6, opacity focus 0.38 / selected 0.18) that **lerps** toward
its target each frame instead of snapping. Three-step size ladder: core ≈ 2× a mid tool,
category shell ≈ 1.3× a tool. (In overlay mode, orbs become radial-gradient + halo sprites —
always perfectly round and identically lit.)

**Connection spec:** AA strokes (SwiftUI `Canvas` `Path`, constant screen-px width),
gently curved (quadratic Bézier sag). At rest a faint web: core→category op 0.28, cat→tool
0.10, inferred 0.06+conf·0.30. On selection, links touching the focus brighten to op 0.60 /
thick ~2px in the endpoint color; everyone else drops to 0.05. Re-route endpoints on pocket
open (in overlay mode this is automatic from live node coords).

**Motion spec:** adopt the web signature ease-out-expo `cubic-bezier(0.16,1,0.3,1)` for
camera reframes/selection (replace `.easeInOut`); springy select with 1.04× overshoot;
selection pulse ±5% / 1.4s on the selected orb + its aura only; label entrance fade+scale
0.85→1.0 / 0.32s; add orbit inertia (velocity capture + exponential decay); haptics
light(tap) / medium(pocket open) / success(fly-to settle); boundary haptic + rubber-band at
dolly clamps. All gated on Reduce Motion (currently inconsistent — several SwiftUI overlay
animations bypass `BrandMotion.resolved`).

---

## 3. ALTERNATIVE DIRECTIONS (for the user to choose)

**Direction B — Find-First, universe demoted to "Explore" tab.** (Product lens.)
Default home = instant search/list of the 49 tools (grouped by category, recents on top),
ONE unified Find field (substring-as-you-type + NL ranker on submit), kill the second
composer. The 3D universe becomes a deliberate "Explore" mode. *Tradeoff:* highest product
ROI (fixes ~80% of "looks terrible/cluttered" for free by removing the HUD-over-3D), and the
viz fixes still matter but only inside Explore — but it reframes the app's hero identity, a
bigger product bet than a pure visual polish. Pairs naturally on top of A.

**Direction C — Full 2.5D force-graph (drop interactive 3D), à la BrainGraph/Obsidian.**
(Viz-tech primary recommendation.) Render nodes/edges/labels entirely in SwiftUI Canvas +
TimelineView (or SpriteKit) on a flat plane with a spring `relax()` layout; optional RealityKit
starfield behind it. *Tradeoff:* the cheapest, most bulletproof path to 60fps App-Store-grade
legibility and the clearest "see the structure" read; reuses existing pure-math
(`UniverseLayout`, `RelationshipIntelligence`). But it sacrifices the volumetric 3D-orbit
"wow" that is currently the brand's signature marketing artifact.

**Direction D — Refine RealityKit in place (overlay labels only, keep 3D world graph).**
Minimal architectural change: just lift labels to the overlay, distance-compensate line
thickness, bump tessellation/aura. *Tradeoff:* lowest immediate effort and keeps the 3D scene
intact, but you keep fighting world-space text/line limitations forever (every lens flags this
as "fighting the framework"); it is A without the clean separation, and tends to accumulate
workarounds. Acceptable as a fast interim, not as the end state.

(A and B are complementary, not exclusive — A is the viz architecture, B is the product
framing. C and D are the two "pick one" rendering alternatives to A's hybrid.)

---

## 4. PRIORITIZED APP-QUALITY PUNCH LIST

**P0 — broken / launch-blocking:**
1. **Chat scroll-to-bottom.** Mount/visibility race (`ChatDock.swift:76-81`): on first ask,
   turns go 0→1 in the same render the ScrollView appears, so `onChange` never fires; and
   answer+cards grow the row *after* `scrollTo` runs. Fix: scroll post-layout
   (`Task { @MainActor … }` / `.onAppear`), anchor to a dedicated bottom view, trigger on
   count + content-size, keep the ScrollView mounted.
2. **Chat composer unmounts when detail sheet expands.** `isPanelActive = sheetDetent != .height(118)`
   removes ChatDock from the tree (`UniverseScreen.swift:17-19,122`) → draft text + scroll lost.
   Decouple chat visibility from the sheet detent.
3. **Black screen on cold launch.** All scene build + procedural env texture + IBL + edge
   inference is synchronous with no placeholder (`UniverseScreen.swift:83-103`). Add a branded
   shimmer/launch-continuity state; defer IBL + inferred edges off the critical path.
4. **Dead buttons.** Settings→History is a no-op haptic with a chevron implying navigation
   (`SettingsSheet.swift:158-165`); double-tap == single-tap (`UniverseView.swift:374`). Wire
   double-tap = fly-to / empty-space reset; wire or hide History.
5. **Add-Tool "+" promised but absent.** Copy + `classifySuccess` haptic assume it
   (`QueryEngine.swift:91`); no button exists. Ship the intake sheet or remove the promise.

**P1 — high-impact:**
6. Reduce-Motion gate is inconsistent — several SwiftUI overlay animations use raw
   `BrandMotion.flow` instead of `.resolved` (`UniverseScreen.swift:185-198`, HistoryStrip,
   PocketReadout, SearchDock, ToolDetailSection).
7. Gesture conflicts: tap-on-orb vs orbit-drag may both fire; ChatDock swipe-down `.gesture`
   fights the thread ScrollView (`ChatDock.swift:40-41`); match-card long-press vs tap race.
8. Two redundant query inputs → unify to one Find field (also a Direction-B product move).
9. Promote "Open <tool>" to the top of the detail sheet (currently buried at
   `ToolDetailSection.swift:237`).

**P2:** verify app icon is final not placeholder; onboarding coach-mark for the non-obvious
3D gestures; landscape/iPad label clipping; VoiceOver list alternative + Dynamic Type +
contrast pass on glass pills; adopt true iOS 26 `glassEffect`/`GlassEffectContainer`.

---

## 5. THE SINGLE HIGHEST-LEVERAGE CHANGE

**Replace world-space 3D extruded text labels with fixed-size, screen-space SwiftUI badge
pills (dark glass plate + 1.5px stroke + Dynamic Type), shown with overview→pocket declutter.**

Five of six lenses independently named this #1. It directly kills "GIGANTIC/crooked text,"
delivers the stroke + darkened badge the user explicitly asked for, is *lighter* than extruded
meshes, unlocks accessibility, and is the keystone of the recommended architecture (the same
overlay layer then carries the AA connection lines). Everything else is polish on top.

---

## ONE-PARAGRAPH SUMMARY (present verbatim to user)

The six lenses agree unanimously: the universe looks broken because it renders an information
graph in a 3D world-space engine, so labels are extruded 3D text sized in *meters* (no badge,
no stroke, ballooning on zoom), connection lines are world-thickness boxes (sub-pixel at
distance, detached from nodes when a pocket opens), and orbs are dark untessellated lumps that
snap rather than ease. Separately, real app-quality bugs are biting: chat doesn't scroll to
bottom, the chat composer vanishes when a tool sheet opens, there's a black screen on cold
launch, a couple of dead buttons, and a promised "+" Add-Tool button that doesn't exist. The
single highest-leverage fix — named #1 by five of six reviewers — is to replace the 3D text
labels with fixed-size screen-space SwiftUI glass-pill badges (stroke + dark plate + Dynamic
Type), shown with an overview→pocket declutter rule; that one move fixes the marquee complaint,
delivers the badge/stroke you asked for, is lighter than the current meshes, and becomes the
layer that also carries crisp anti-aliased connection lines. I recommend pairing that with
lighter, glowing orbs (aura halo + eased materials) and the web's signature ease-out-expo
motion. For the bigger rendering bet, here are the three directions to choose between:

- **Direction A — Overlay-Native Universe (recommended):** keep RealityKit for ambient cosmic
  depth only; draw orbs, edges, and labels in a screen-space SwiftUI/Canvas overlay. Best
  quality-per-effort, keeps the 3D "space" brand feel, fixes everything legibility-related at
  once.
- **Direction B — Find-First (product reframe, pairs with A):** make an instant search/list the
  home with ONE unified Find field, and demote the universe to a deliberate "Explore" tab.
  Highest product ROI for a 49-tool set; fixes most "cluttered" complaints for free, but changes
  the app's hero identity.
- **Direction C — Full 2.5D force-graph (drop interactive 3D):** render the whole graph flat in
  Canvas/SpriteKit like Obsidian/BrainGraph. Cheapest path to bulletproof 60fps legibility and
  the clearest "see the structure" read, but sacrifices the volumetric 3D-orbit wow factor.
