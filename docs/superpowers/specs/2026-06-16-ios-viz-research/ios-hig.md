# iOS HIG / Apple Best-Practices Lens — "My AI Map" 3D Universe

Research date: 2026-06-16. Read-only audit of `/tmp/wt-ios/ios-app/Sources/MyAIMap`
against the web reference `/tmp/wt-ios/src/components/AIToolUniverse3D` and Apple's
Human Interface Guidelines (HIG: *Materials*, *Typography*, *Layout*, *Motion*,
*Gestures*, *Feedback*, *Spatial layout*, *Charting/data viz* notes, and the
iOS 26 *Liquid Glass* guidance).

## TL;DR — the one root cause behind "labels gigantic, orbs crooked, lines messy"

The web build draws **labels as screen-space DOM** (drei `<Html>` pill badges:
`distanceFactor` keeps a fixed on-screen size, with border + dark gradient backing +
blur + logo). The iOS build draws **labels as world-space extruded 3D text**
(`MeshResource.generateText`, font size = world height in **meters**:
`labelFontSize = 0.8`, `toolLabelFontSize = 0.32` in `UniverseView.swift:636,645`).
World-space text has no pixel size, no badge, no stroke, samples through the camera
projection, and grows/shrinks with dolly — so it reads as "GIGANTIC and crooked."
**This is the single highest-leverage fix.** Everything else (orbs, lines, motion,
glass) is polish on top.

Apple principle violated: HIG *Typography* — "Text should always be crisp and legible;
avoid scaling text geometrically with a 3D scene." Top-tier reference: **Apple Maps**
(3D POI labels), **Sky Guide**, **GraphPad/Grapher**, and **Swift Charts** all render
labels in a screen-aligned overlay layer, never as scene geometry.

---

## 1. LABELS — highest priority (badges, size, contrast, stroke, dynamic type)

### What a premium Apple app does
- Labels live in a **2D overlay**, projected from the 3D anchor, drawn at a **fixed
  point size** regardless of camera distance (Apple Maps 3D, Sky Guide constellation
  names). They never extrude or tilt with the scene.
- Legibility over busy backgrounds is guaranteed with a **material backing + vibrancy**,
  not raw text. HIG *Materials*: "Use a material behind text that sits over varied
  content so it remains legible." Maps uses a subtle dark/blur capsule behind every
  3D label.
- Text gets a **contrast guarantee**: either a darkened/blurred plate OR a thin
  contrasting outline. HIG *Color and contrast*: minimum 4.5:1 for body, 3:1 for
  large/bold. White-on-cosmos with no plate fails this in bright regions (nebula
  gradient, bright orbs).
- Respects **Dynamic Type** and at minimum **bold-text / increase-contrast** settings.

### What this app does wrong (concrete)
1. **3D extruded mesh text** (`makeToolLabel` / `makeCategoryLabel`,
   `UniverseView.swift:653-725`) sized in meters. Replace with an overlay.
2. **No badge backing.** Web has `.universe-label`: `border 1px rgba(255,255,255,.18)`,
   `background linear-gradient(180deg, rgba(14,23,38,.86), rgba(4,8,18,.76))`,
   `backdrop-filter blur(14px)`, `border-radius 999px`, padding `4-7px`
   (`index.css:87-173`). iOS has bare white text on the void.
3. **No stroke/shadow.** Web category labels use `text-shadow 0 1px 10px rgba(0,0,0,.55)`.
4. **Distance fade only, no size constancy.** `ToolLabelFade` (near 6 → far 18)
   fades, but the text still balloons as you dolly in because size is world-fixed.
5. **No Dynamic Type / accessibility text scaling** — mesh text can't honor it.
6. **Truncation at the wrong layer.** `lineBreakMode: .byTruncatingTail` on mesh text
   has no `max-width`; web caps `max-width: 116px` (tool) / `232px` (focus).

### Concrete rules (target spec)
- **Render labels in a SwiftUI overlay**, not RealityKit geometry. Project each
  anchor's world position to screen via the camera (`Entity.position(relativeTo:)`
  + camera projection, or attach an invisible anchor and read its 2D projection)
  and place a SwiftUI badge at that point each frame (or throttled to ~30 Hz).
  If you must stay in RealityKit, use `ModelEntity` with an **unlit textured quad**
  rendered from a `UIView`/`CALayer` snapshot at a fixed pixel size and a
  `BillboardComponent` — but the SwiftUI overlay is cleaner and gets Dynamic Type for free.
- **Badge geometry** (port web tokens): corner radius 999 (capsule), padding ~6×10pt
  (category) / ~4×7pt (tool), border 1px white @ 0.18, dark gradient fill
  (top `#0E1726` @ 0.86 → bottom `#040812` @ 0.76), `.ultraThinMaterial`/`.regularMaterial`
  backdrop (Liquid Glass), drop shadow `0 1px 10px black@0.55`.
- **Type**: category `.caption.weight(.bold)` ≈ 12pt; tool `.caption2.weight(.semibold)`
  ≈ 10-11pt; focused tool `.subheadline.bold` ≈ 13pt. Scale with `@ScaledMetric` so
  Dynamic Type works. Add `.minimumScaleFactor(0.85)` + `.lineLimit(1)` + frame max-width
  (~116/146/232pt mirroring web).
- **Contrast**: white @ 0.96 over the dark plate (passes 4.5:1). For the no-plate
  category label variant, add a 0.5pt contrasting outline or always keep the plate.
- **Distance behavior**: keep `ToolLabelFade` for fade, but decouple size from distance —
  fixed point size, only opacity ramps. Consider a 2-tier system like the web:
  focused/selected/related labels always shown, distant ones hidden (web `wantsLabel`
  = selected || activeFocus || labelVisible).
- **Collision/declutter**: at overview, only show category labels + the selected
  tool's label (HIG: reduce label density on busy scenes; Maps drops overlapping POI
  labels). The web `labelLaneForTool` lane-staggering (`ToolNode.tsx:17`) is a good
  model if you later show many at once.

---

## 2. ORBS / MATERIALS — "crooked/crude" polish

### What a premium Apple app does
- Smooth, evenly-tessellated spheres; consistent PBR lighting; a soft additive
  **aura/bloom** on the focused element (the web has `AURA_GEOM`, additive blending,
  `ToolNode.tsx:172-180`); subtle clearcoat sheen on the selected node.
- Selection communicated by **scale + glow + material**, animated (eased), not snapped.

### What this app does wrong (concrete)
1. **Default sphere tessellation.** `.generateSphere(radius:)` (`UniverseView.swift:608,
   729`) uses RealityKit's default low segment count — at close pocket range the
   silhouette reads faceted/"crooked." Web uses `SphereGeometry(0.3, 20, 20)` /
   `(0.46,24,24)` — explicitly higher segments.
2. **No aura/bloom layer.** Web layers an additive `AURA_GEOM` halo that scales/fades
   with focus (`auraRef`). iOS only has the founder halo; per-tool selected orbs get
   emissive but no soft glow envelope → they look flat/crude vs web.
3. **Materials snap on selection.** `applyLayout` comment (`UniverseView.swift:453`):
   "Materials snap (RealityKit can't tween them)." The web *eases* emissive, opacity,
   clearcoat, aura every frame (`ToolNode.tsx:102-130`). The pop is the "crude" feel.
   RealityKit can't tween a material property directly, but you can drive
   `emissiveIntensity`/opacity in a small `System` each frame toward a target (lerp),
   exactly like the web `useFrame`.
4. **Lighting may over-flatten.** Key 2600 + fill 750 + IBL. Verify shadowed
   hemispheres aren't dead-black on device (the code already worries about this).
   HIG *Spatial*: depth should come from lighting gradients, not flat fills.

### Concrete rules
- Generate spheres with explicit higher tessellation. RealityKit's `generateSphere`
  doesn't expose segment counts in older APIs — if so, build a UV-sphere via
  `MeshDescriptor` (you already do custom meshes for rings/links) or use
  `LowLevelMesh`. Target ≥ 24 segments for hero/pocket orbs.
- Add a per-tool **additive aura halo** (a second slightly larger sphere, UnlitMaterial,
  additive/transparent blend) whose opacity+scale lerp on selection — mirror web
  `auraTargetOpacity` (focus 0.38 / selected 0.18 / related 0.08 / else 0) and
  `auraTargetScale` (1.58/1.22/1.04/0.86).
- **Ease material state** with a per-frame `System` (lerp emissive/opacity/clearcoat
  toward target at ~0.055/frame like web) instead of snapping in `applyLayout`.
- Keep clearcoat 0.6 on selected (already matches web). Good.

---

## 3. CONNECTION LINES — "barely visible/messy"

### What a premium Apple app does
- Lines are **anti-aliased, screen-space-width** strokes (constant pixel thickness),
  often gently curved, with opacity encoding importance. Swift Charts / Maps routes
  use screen-space line widths so they never disappear at distance.

### What this app does wrong (concrete)
1. **World-thickness boxes.** Links are unit boxes scaled to `thickness` in meters
   (`makeLink` + `LinkGeometry`, `UniverseView.swift:537-555`, thickness 0.008-0.02).
   At overview distance these subtend a sub-pixel width → "barely visible"; up close
   they read as crude rectangular bars, not lines. Web uses drei `QuadraticBezierLine`
   with `lineWidth` in **screen px** (0.24-2.6) — constant on-screen thickness.
2. **Aliased edges.** A thin opaque box has hard aliased edges; no AA softening.
3. **Straight, overlapping segments → "messy."** Web curves them (`QuadraticBezierLine`)
   so the bundle reads as flowing arcs, not a crosshatch.
4. **Static; never re-routed to pocket positions.** Comment at
   `UniverseView.swift:131-141`: pocket re-layout doesn't move links, so in an open
   pocket lines no longer reach their nodes → "messy/disconnected." Web recomputes
   `lineData` from live `positionById`.
5. **No importance hierarchy on screen.** Web modulates opacity AND width by
   selection/lens/depth (`ConnectionLines.tsx:87-117`); iOS uses fixed opacity 0.5 /
   0.22 / confidence — far less legible focus.

### Concrete rules
- Use a **screen-space-width line primitive**. RealityKit lacks a built-in screen-px
  line, so options: (a) render the graph edges in a SwiftUI `Canvas`/`Path` overlay
  (project both endpoints, stroke a quadratic Bézier with constant `lineWidth`,
  anti-aliased for free) — this also kills the aliasing and lets you curve them; or
  (b) keep boxes but scale thickness by camera distance each frame so on-screen width
  stays ~constant. Overlay (a) is the Apple-grade answer and pairs naturally with the
  label overlay from §1.
- **Curve** the edges (quadratic Bézier, sag toward midpoint) for the flowing look.
- **Re-route on pocket open** (recompute endpoints from live positions) so lines stay
  attached. Either move them in `applyLayout` or rebuild in `refreshToolLabels`.
- **Encode hierarchy on screen**: selected edge brightest/thickest, in-pocket next,
  out-of-context near-invisible (port web opacity/width tables).

---

## 4. CAMERA / MOTION FEEL — 60fps + premium easing

### What a premium Apple app does
- **Inertia / momentum** on pan and pinch with a smooth decay (Maps, Photos zoom).
- Camera moves use **spring or custom ease-out cubic** (`cubic-bezier(0.16,1,0.3,1)`),
  not linear/easeInOut. HIG *Motion*: motion should feel physical and decelerate
  naturally.
- **Respects Reduce Motion** (this app does — good, gated throughout).

### What this app does (assessment)
- CameraController is solid: clamped dolly (7.5-46), pitch clamp, head-on reframing,
  preserves dolly across orbit, stops animations when the user grabs control
  (`CameraController.swift`). Good fundamentals.
- **Gaps:**
  1. **No orbit inertia.** `orbitEnded()` just drops baselines — the map stops dead.
     Premium feel = decaying spin after a flick (track velocity, decay in a System).
  2. **`.easeInOut` everywhere** for camera/layout moves (`retarget`, `applyLayout`,
     `move(to:)`). The web signature easing is `cubic-bezier(0.16,1,0.3,1)` (ease-out
     expo) used for *every* label/badge transition (`index.css:108`). Match it — it's
     the difference between "snappy Apple" and "generic." RealityKit `move(to:)` only
     offers `.easeInOut/.linear`; for custom curves drive transforms in a System or
     use `AnimationResource` with a timing curve, or animate via SwiftUI for overlay
     elements.
  3. **Pinch has no rubber-band at clamps.** At min/max distance the dolly hard-stops;
     Maps rubber-bands slightly past the limit then settles.

### Concrete rules
- Add **orbit momentum**: capture drag velocity at `onEnded`, spin down with
  exponential decay in a per-frame System, cancel on next touch.
- Adopt **ease-out-expo** (`0.16,1,0.3,1`) for camera reframes and selection moves to
  match the web's polished feel; reserve spring for press/tap micro-bounces.
- Optional rubber-band at dolly clamps.
- Budget: keep these in the existing `System` update (already `.rendering` phase);
  they're cheap.

---

## 5. GESTURE GRAMMAR — HIG standard gestures

### What a premium Apple app does (HIG *Gestures*)
- **Tap** = primary select; **double-tap** = zoom-to/focus; **drag** = pan/orbit;
  **pinch** = zoom; **long-press** = contextual preview/menu; **two-finger / edge** =
  navigate. Gestures should be **discoverable, forgiving, and standard**.

### What this app does (assessment)
- Tap selects, double-tap fly-to (currently same routing), drag orbits, pinch dollies,
  long-press peeks match cards in chat, swipe-down dismisses sheets/thread. Good
  coverage and standard mappings.
- **Gaps:**
  1. **Double-tap is a no-op differentiator** — `handleDoubleTap` just calls
     `handleTap` (`UniverseView.swift:374`). HIG expects double-tap to *zoom*. Make
     double-tap on empty space reset to overview (the comment admits this is deferred),
     and double-tap a node should fly closer than a single select.
  2. **No long-press on orbs** for a peek/context menu (web has hover→badge; iOS has
     no equivalent on the 3D nodes). Add `.contextMenu` or a long-press peek to mirror
     the chat-card peek grammar across the app.
  3. **No haptic on orbit/pinch boundaries.** HIG *Feedback*: confirm limits. A light
     tick at dolly min/max and on snap-to-head-on would feel intentional.
  4. **"Some buttons don't work"** (user report): `ClarityMenu` is intentionally hidden
     (`UniverseScreen.swift:114-118` — "a visible control that does nothing is worse").
     Audit `CategoryRail`, `SearchDock`, header `AccountButton`, and match cards for
     dead targets; the hidden ClarityMenu suggests other half-wired controls exist.

### Concrete rules
- Differentiate double-tap (zoom/fly-to closer; empty-space double-tap = reset to core).
- Add long-press peek/context menu on orbs (parity with chat-card peek + web hover badge).
- Add boundary/snap haptics (`.light`) for dolly clamps and head-on reframe.
- Sweep every control for no-op handlers; hide or wire each (HIG: no dead controls).

---

## 6. LIQUID GLASS — already strong, refine

### Assessment
- `LiquidGlass.swift` is well-architected: native iOS 26 `.regularMaterial` + tint +
  stroke, with an `.ultraThinMaterial` + gradient-highlight fallback. This is the
  correct HIG approach.
- **Gaps / refinements:**
  1. The native branch uses `.regularMaterial` rather than the true `glassEffect`
     API — comment says call sites avoid `.glassEffect` directly, but the native
     modifier itself should adopt `.glassEffect(in:)` / `GlassEffectContainer` on
     iOS 26 for the real refractive Liquid Glass (lensing, specular edge), not just a
     blurred material. HIG iOS 26: use the system glass for controls floating over
     content; don't hand-roll it where the real one exists.
  2. **Glass over the 3D canvas**: HIG warns against stacking glass on glass and
     against glass over low-contrast/busy backgrounds without enough separation. The
     chat dock, search dock, history strip, pocket readout, rail are all glass over the
     starfield — verify legibility (the §1 label plate logic applies here too) and that
     they don't all overlap into glass-on-glass.
  3. Bring the **same glass plate to the 3D labels/badges** so chrome and in-scene
     labels read as one material family (web does — every label is the same dark
     glass pill).

---

## 7. CHAT DOESN'T SCROLL TO BOTTOM — concrete diagnosis

`ChatDock.threadScroll` (`ChatDock.swift:55-82`) *does* wire a `ScrollViewReader` +
`.onChange(of: thread.turns.map(\.id))` → `scrollTo(last, anchor: .bottom)`. Likely
failure modes (in priority order):

1. **Scroll fires before the new row has laid out its full height.** A turn row
   (`turnRow`) contains the question bubble, the answer text, AND N match cards
   (`ChatDock.swift:85-108`). `scrollTo` runs the instant the id array changes, but the
   answer + cards inflate the row taller *after* the scroll resolves, so the bottom
   ends up below the viewport. Fix: scroll **after** layout — wrap the `scrollTo` in a
   second pass (e.g. `Task { @MainActor in withAnimation { scrollTo(...) } }` or scroll
   on an `.onChange` of a content-height/last-turn-answer key, not just id count), and
   consider a bottom **spacer/anchor view** with a fixed `.id("BOTTOM")` and scroll to
   that instead of the last turn id.
2. **Anchor `.bottom` of the turn id vs. the scroll content.** Anchoring to the last
   turn's `.bottom` aligns that row's bottom to the viewport bottom — fine — but if the
   row is taller than the viewport (long answer + many cards, and the thread is capped
   at 1/3 screen, `maxThreadFraction`), the bottom of the row can't reach. A dedicated
   bottom anchor view fixes this.
3. **Animation timing vs. keyboard.** When `submit()` runs, the keyboard may still be
   animating; the scroll competes with the safe-area inset change. Re-assert the scroll
   on keyboard-frame settle.

HIG note: messaging UIs (Messages) always pin to the latest message; this is expected
behavior, so it's worth getting exactly right.

---

## Prioritized action list

P0 (fixes the "looks terrible" core):
1. **Replace 3D mesh labels with fixed-size screen overlay badges** (dark glass pill,
   stroke, shadow, Dynamic Type) — §1.
2. **Connection lines → screen-space anti-aliased curved strokes** (SwiftUI Canvas
   overlay or distance-compensated thickness), re-routed on pocket open — §3.
3. **Fix chat scroll-to-bottom** (scroll after layout to a dedicated bottom anchor) — §7.

P1 (premium polish):
4. **Orbs**: higher tessellation + per-tool additive aura + eased material transitions — §2.
5. **Motion**: ease-out-expo for camera/selection + orbit inertia — §4.
6. **Gestures**: real double-tap zoom + empty-space reset, long-press peek on orbs,
   boundary haptics; audit dead buttons — §5.

P2 (consistency):
7. Adopt true iOS 26 `glassEffect`/`GlassEffectContainer` in the native LiquidGlass
   branch; unify the label plate material with chrome glass — §6.

## Example apps to study (Apple-grade references)
- **Apple Maps** — 3D POI/road labels: fixed-size, material-backed, decluttered.
- **Sky Guide / Night Sky** — constellation/star labels over a cosmos exactly like
  this scene: screen-space text plates, fade-by-importance, momentum pan.
- **Swift Charts** — screen-space anti-aliased lines, opacity-as-importance, axis
  label legibility.
- **Photos / Maps** — pinch+pan inertia, rubber-band at zoom limits, double-tap zoom.
- **Messages** — the canonical "always scroll to newest" chat behavior.
