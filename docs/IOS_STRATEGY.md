# iOS App Store strategy

The web app at <https://ai-tool-universe-map.vercel.app> needs an iOS
test build for personal TestFlight use, with App Store quality as a
non-negotiable bar. This document lays out the three credible paths,
their trade-offs, the recommendation, and a phased plan.

## Goal

- Run the AI Tool Universe Map on iPhone/iPad as a native-feeling app.
- Ship to **TestFlight** for personal use first.
- Keep an honest path open to public App Store release later.
- Preserve the current 3D look (cosmic galaxy, pocket worlds, animated
  edges) and ideally make it sharper, in the spirit of Obsidian's
  experimental 3D graph (April 2026, Three.js + Metal).

## Paths considered

### Path A — Capacitor wrap of the React app

- **What it is:** wrap the existing Vite build in `@capacitor/ios`,
  ship as a WKWebView app.
- **Effort:** 1–2 days to TestFlight.
- **Pros:** ~100 % code reuse, fast.
- **Cons:**
  - WKWebView WebGL is throttled in background and on older hardware.
  - Touch gestures don't feel native (no system inertia, no
    proper haptic taps).
  - Lighthouse-style perf metrics on a wrapped web view often
    degrade against the native baseline.
  - App Store review historically discourages thin-wrapper apps.

### Path B — React Native + `react-three-fiber/native`

- **What it is:** rebuild the UI in React Native, keep the 3D scene
  via `expo-three` or `react-three-fiber/native`.
- **Effort:** 3–4 weeks.
- **Pros:** Shared 3D code with the web; native shell.
- **Cons:**
  - `react-three-fiber/native` is still WebGL under the hood
    (`expo-gl`); the perf ceiling stays similar.
  - Maintaining two render targets multiplies edge cases.

### Path C — Fresh SwiftUI + RealityKit native port

- **What it is:** new SwiftUI app, 3D scene in RealityKit via
  `RealityView`, ECS for nodes/edges, Metal under the hood.
- **Effort:** 4–6 weeks for parity, faster after Apple skills
  load (the cloned `claude-code-apple-skills` collection covers
  `swiftui`, `ios`, `app-store`, `design`, `release-review`,
  `monetization`, `growth`, `performance`).
- **Pros:**
  - Native performance — Metal everywhere, no WebGL throttling.
  - Native gestures, haptics, dynamic type, dark mode "for free".
  - Apple Intelligence + on-device foundation models become
    options for the future classifier.
  - App Store reviewers treat native code as the safe default.
- **Cons:**
  - Real rewrite. Three.js scene math has to translate to
    RealityKit ECS + position math.
  - Data layer needs a Swift model that mirrors
    `src/data/ai-tool-universe.ts`.

## Recommendation

**Path C, with Path A as a same-week throwaway.**

Reasoning:

1. The product's headline value is the 3D map. A wrapped web view
   compromises that on day one and never recovers — every later
   perf or polish task fights the wrapper.
2. RealityKit + SwiftUI is Apple's current path (SceneKit is
   deprecated as of WWDC25 — see `docs/DESIGN_REFS.md`). Building on
   the supported stack now avoids a forced migration later.
3. A 1-day Capacitor build in week 1 lets you keep dogfooding on
   the iPhone while the native port is being assembled. Toss it
   the moment the SwiftUI build can launch.

## Phased plan

### Phase 0 — De-risk (week 1)

- Stand up the Capacitor wrap (`./ios-wrap/`). TestFlight build for
  personal use only. Mark in `CHANGELOG.md` as a throwaway artifact.
- Create the SwiftUI scaffold (`./ios-app/MyAIMap.xcodeproj`),
  empty `RealityView`, App Icon, splash, dark glassy launch screen
  per Apple skills guidance.
- Apple Developer enrollment if not done; bundle id
  `com.ilyatur.myaimap`.

### Phase 1 — Data + scene parity (weeks 2–3)

- Port `src/data/ai-tool-universe.ts` to a Swift module
  (`AIToolUniverse/Data/Tools.swift`). Hand-curated arrays first,
  not JSON — keep the existing shape.
- Implement `CategoryRing`, `ToolNode`, `Founder OS core` as ECS
  entities. Reuse the Fibonacci-sphere layout math from
  `layout.ts` verbatim.
- Camera controller mirrors `CameraControls` semantics
  (`minDistance`, `maxDistance`, lookAt smoothing).

### Phase 2 — Pocket worlds + interactions (week 4)

- `ProximityCategoryWatcher` becomes a per-frame ECS system that
  reads `arView.cameraTransform` and dispatches enter/exit events.
- SwiftUI overlay panels (left intake, right detail, bottom lens)
  with the bottom-sheet pattern on iPhone, side-rail on iPad.
- Haptics: light tap on pocket open, success haptic on auto-classify.

### Phase 3 — Polish + Lighthouse-equivalent (week 5)

- Bloom + curved Bezier edges (Obsidian-style — see
  `docs/DESIGN_REFS.md`).
- Force-directed layout option using a Swift port of `d3-force-3d`
  semantics (entity components run inside `update()`).
- Settings: clarity modes (Focus / Context / Atlas) bound to a
  segmented control + keyboard shortcuts on iPad.

### Phase 4 — Release review (week 6)

- Run the `release-review`, `legal`, and `app-store` Apple skills
  end-to-end. App Store metadata, privacy nutrition labels,
  in-app screenshots at every required size.
- Internal TestFlight, then private testers.

## Current TestFlight path

The active native project lives in `ios-app/` and is generated from
`ios-app/project.yml`. Current release-facing values:

- App name: `My AI Map`
- Bundle id: `com.ilyatur.myaimap`
- SKU: `myaimap-ios`
- Minimum iOS: 18.0
- Target families: iPhone and iPad

Remaining non-code gates for a real personal TestFlight build:

1. Active Apple Developer Program membership.
2. Apple team selected in Xcode for the `MyAIMap` target.
3. Bundle id registered/available in App Store Connect.
4. Successful simulator sanity check.
5. Successful real-device signing run.
6. Xcode Archive upload to App Store Connect.
7. Internal tester added and build installed through TestFlight.

For exact steps, use `ios-app/TESTFLIGHT_CHECKLIST.md`.

## Skills loaded

`.claude/skills/` now contains 23 skill packs from
[`rshankras/claude-code-apple-skills`](https://github.com/rshankras/claude-code-apple-skills):

```
app-store           foundation     legal      mapkit
apple-intelligence  generators     macos      monetization
core-ml             growth         performance  release-review
design              ios            product      security
shared              swift          swiftdata    swiftui
testing             visionos       watchos
```

Use them via the Skill tool — e.g. invoke `ios` before any
RealityView edit, `app-store` before the metadata pass,
`release-review` before submission.

## Decision needed from you

Before I start cutting code:

1. **Approve Path C** as the long-horizon target. Approve Path A as
   the week-1 stopgap (or skip it).
2. Confirm the bundle identifier remains `com.ilyatur.myaimap`.
3. Confirm App Store Connect access / Apple Developer enrollment
   status.
4. Confirm whether the iOS app should reuse the same brand name
   ("AI Tool Universe Map") or get a fresh name for App Store
   discoverability.
