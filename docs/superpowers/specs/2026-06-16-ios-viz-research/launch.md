# My AI Map — App Store Launch Readiness

Lens: shipping a top-charting, top-tier iOS app. What blocks launch, prioritized by leverage. Every line is verifiable in the current build.

---

## TL;DR — the single highest-leverage change

**Fix the 3D text labels.** They are the first thing every reviewer, screenshot, and user sees, and right now they are GIGANTIC and unreadable — a guaranteed App Store rejection-feel and a 1-star screenshot. The labels are built with `MeshResource.generateText` where **font size = world height in meters** (`UniverseView.swift:636` `labelFontSize = 0.8`, `:645` `toolLabelFontSize = 0.32`). A 0.8m-tall extruded glyph cluster at the ~20-unit overview distance reads as a wall of text, scales unpredictably with camera dolly/pinch, has no outline, no badge backing, and no max-width, so long names like "Perplexity" sprawl across the frame. This is the launch blocker that also happens to be the user's #1 complaint. See "Giant-text legibility" below for the concrete fix. **Do this first.**

---

## P0 — Hard launch blockers

### 1. Giant-text legibility (the marquee problem)
- **Where:** `UniverseView.swift:636,645,653-674,695-725` (`makeToolLabel`, `makeCategoryLabel`), `ToolLabelFade.swift`.
- **Why it's a blocker:** world-space extruded 3D text has no constant on-screen size, no stroke, no contrast backing, no truncation width. It looks crude and is unreadable — exactly the "GIGANTIC text" the user reports. App Store reviewers screenshot the home screen; this is the home screen.
- **Fix (recommended):** Replace `generateText` meshes with **SwiftUI overlay labels** projected from each anchor/orb's world position via the camera (RealityKit `project(point:)` / a tracked `attachment`). That gives you: crisp vector text at constant point size, a real darkened glass/badge pill backing, a 1px outline/stroke, `lineLimit(1)` + `truncationMode`, Dynamic Type, and VoiceOver — all the things the user asked for ("crisp outline/stroke + tidy darkened badge backing"). It is also *lighter* than extruded text meshes.
- **Cheaper interim:** if staying in-scene, drop font sizes ~3-4x, add a dark rounded `generateBox` plane behind each label, and clamp `containerFrame` width — but the SwiftUI-overlay route is the top-tier answer and unblocks accessibility too.

### 2. Black-screen-on-launch (perceived performance)
- **Where:** `UniverseScreen.swift:83-103` `canvas` → `RealityView { content in … }` (`UniverseView.swift:29-242`). The `make` closure does ALL scene construction synchronously on first render: registers 3 ECS systems, builds 49 tool orbs + category anchors + rings + every structural & inferred link (`RelationshipIntelligence.infer` over the full set, `:159-175`), a star field, galaxy dust, a procedurally-painted equirectangular **environment texture** rendered in CoreGraphics at launch (`CosmicEnvironmentTexture.makeEquirectangular`, `:234`) plus `EnvironmentResource` IBL derivation. **There is no loading/placeholder state** — confirmed: grep for `ProgressView`/`placeholder`/`isReady` in both files returns nothing. Until that build finishes the user sees the `Color.black` background (`UniverseScreen.swift:69`) = a dead black screen on cold launch.
- **Why it's a blocker:** first-run black screen reads as a crash/hang. Kills the first impression and inflates perceived launch time.
- **Fix:** (a) show a branded launch-continuity state — a star-field + logo + subtle shimmer (`ShimmerLoader` already exists) that crossfades into the scene; (b) move the IBL/env-texture generation and inferred-edge computation off the critical path (background task, add IBL after first frame); (c) the `UILaunchScreen` is just a solid `LaunchBackground` color (`Info.plist:23-27`) — make the launch screen visually continuous with the first real frame so there's no jarring color pop.

### 3. App icon must be verified real, not a placeholder
- **Where:** `AppIcon.appiconset` contains a single `AppIcon-1024.png` (249 KB) — modern single-size is fine for iOS 18. **Verify it is a finished, distinctive icon**, not a stand-in. The icon is the #1 conversion lever on the store and the one asset you cannot ship rough. If it's a placeholder, it's a P0.

---

## P1 — Launch-quality polish gaps

### 4. No first-run / onboarding / coach-mark
- **Confirmed:** no onboarding code anywhere — the `UserDefaults` hits are all persistence (`AppSettings`, `ChatThreadStore`, `HistoryStore`), no `hasLaunched`/`hasSeenIntro` flag exists. A novel 3D-orbit-with-proximity-navigation UI with **zero** guidance means users won't discover tap-anchor-to-open-pocket, double-tap fly-to, drag-to-orbit, pinch-dolly, or "ask the map." Top apps teach a non-obvious core interaction in 1-2 lightweight coach marks.
- **Fix:** a one-time, skippable 2-3 step overlay (gesture hints), gated on a `UserDefaults` flag. Cheap, high retention impact.

### 5. Empty state for "ask the map"
- The chat `emptyState` (`ChatDock.swift:156-177`) is decent (3 example queries). Good. But the thread only appears once `!thread.turns.isEmpty` — verify the very-first-run experience surfaces the example prompts prominently rather than just a thin composer pill. Minor.

### 6. The crude/crooked orbs and faint connection lines
- **Orbs (`styleToolNode` `:863-887`):** plain `generateSphere` PBR with emissive. "Crooked/crude" likely = low default sphere tessellation + harsh single-key lighting producing facets, plus per-orb scale jitter from `PocketTransition.toolNodeScale`. Raise sphere detail, soften the key/fill ratio (`:210-221`), and verify scales aren't producing ellipsoids.
- **Lines (`makeLink` `:537-555`):** thin unlit boxes at opacity 0.012-0.22 thickness — "barely visible/messy" is expected at those alphas/thicknesses against a dark field, and the comment at `:134-148` admits pocket-open links **don't follow** their re-laid-out nodes (they stay at overview positions = visually wrong/messy in an open pocket). Either bump thickness/opacity and add a soft additive glow, or hide secondary links when a pocket is open. The orphaned-line-in-pocket bug is a real visual defect.

### 7. Chat scroll-to-bottom (user reported "does NOT scroll")
- **Where:** `ChatDock.swift:55-82`. There IS a `ScrollViewReader` + `.onChange(of: thread.turns.map(\.id))` → `scrollTo(last, anchor: .bottom)`. So the *intent* exists. Likely failure modes to check: (a) the new turn's answer renders taller than the frame and `.bottom` anchor lands above the match cards (anchor on the last **card** id, not the turn id); (b) the keyboard pushes content and the scroll fires before layout settles — add a tiny delay or scroll again `.onChange` of keyboard/focus; (c) `BrandMotion.flow` animation racing the content insert. This is a real bug worth reproducing and fixing for launch — chat that doesn't pin to the newest message feels broken.

### 8. "Some buttons don't work"
- The `ClarityMenu` is intentionally **not mounted** (`UniverseScreen.swift:114-117`) because the renderer doesn't honor clarityMode yet — good call to hide it. But audit every visible control end-to-end: `AccountButton`→settings (wired `:162-165`), `CategoryRail`, `SearchDock`, `HistoryStrip`, match cards. The user reports dead buttons; reproduce and list which. A visible no-op control is a reviewer red flag.

---

## P2 — Accessibility & store-readiness

### 9. Accessibility is half-built
- **Good:** orbs/anchors have VoiceOver labels/hints/traits (`UniverseView.swift:613-624,737-747`), reduce-motion is threaded through pulses/halo/camera. Genuinely above average for a 3D app.
- **Gaps:** (a) **Dynamic Type** — once labels move to SwiftUI overlays (P0#1) they should scale with text size; in-scene 3D text can't. (b) Contrast — white-on-color glass pills need a WCAG pass. (c) The whole spatial scene needs a VoiceOver "rotor" or list alternative — blind users can't orbit a camera; consider a flat accessible list of tools/categories as an a11y affordance. (d) Verify `prefersCrossFadeTransitions` / reduce-transparency for the liquid glass.

### 10. Orientation & device matrix
- App supports iPhone portrait+landscape and full iPad (`project.yml:22-23`) with a real iPad split layout (`UniverseScreen.swift:47-67`). Good. **Test landscape label clipping** — `labelInset` (`:641`) is tuned for "portrait iPhone narrow FOV"; landscape and iPad will frame differently. Verify the 3D scene + labels don't break across the matrix.

### 11. Metadata / privacy / version
- `Info.plist`: `CFBundleShortVersionString 1.0`, build `1`, `ITSAppUsesNonExemptEncryption=false` (good, avoids export-compliance prompt). No tracking/permissions requested (no camera/location/ATT) — clean, but confirm no `NSUserTrackingUsageDescription` is needed if analytics get added. Prepare App Privacy "nutrition label" (likely "Data Not Collected" — a selling point).

---

## Suggested launch sequence
1. **Labels → SwiftUI overlays** (P0#1) — fixes legibility, badges, outline, accessibility in one move.
2. **Launch-continuity / kill black screen** (P0#2) — defer IBL+inferred-edges, add branded shimmer.
3. **Verify/finish app icon** (P0#3).
4. Onboarding coach-marks (P1#4), chat scroll fix (P1#7), dead-button audit (P1#8).
5. Orb/line polish (P1#6), then a11y Dynamic Type + device matrix (P2).
