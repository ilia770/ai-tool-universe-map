# My AI Map — iOS app

Native iOS port of the [AI Tool Universe Map](https://ai-tool-universe-map.vercel.app)
to SwiftUI + RealityKit.

This directory holds the **Phase 0 scaffold** per `docs/IOS_STRATEGY.md`:
the project builds and launches on a Simulator or device with a
placeholder RealityKit scene (Founder OS core + 8 category anchors on
one ring). Phase 1 ports the real data + Fibonacci-sphere pocket
layout; Phase 2 wires interactions; Phase 3+ adds bloom, force-directed
layout, App Store metadata, and TestFlight release.

## Prerequisites

- macOS 14+ with Xcode 16+ (iOS 18 SDK).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation:

  ```bash
  brew install xcodegen
  ```

- (Phase 4+) Apple Developer Program membership for TestFlight + App
  Store submission.

## One-time setup

```bash
cd ios-app
xcodegen generate
```

That produces `MyAIMap.xcodeproj`. It is gitignored — the
canonical project definition lives in `project.yml`, edit that
instead.

## Build + run

```bash
open MyAIMap.xcodeproj
# In Xcode: select the "My AI Map" scheme and a Simulator, then ⌘R.
```

Or from the CLI (no Xcode GUI):

```bash
xcodebuild \
  -project MyAIMap.xcodeproj \
  -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

## Tests

```bash
xcodebuild \
  -project MyAIMap.xcodeproj \
  -scheme MyAIMap \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

The Phase 0 tests cover the pure layout math
(`UniverseLayoutTests.swift`) — same parity contract the web app
relies on (`tests/visual-smoke.spec.ts` in the repo root).

## File map

```
ios-app/
  project.yml                              # XcodeGen project definition
  Sources/MyAIMap/
    MyAIMapApp.swift                       # @main entry — single window, dark
    Universe/
      UniverseView.swift                   # RealityView wrapper
      UniverseLayout.swift                 # Pure math, ports layout.ts
    Data/
      ToolCategory.swift                   # Mirror of web ToolCategory
      Tool.swift                           # Mirror of web AITool + UniverseLink
      UniverseSeed.swift                   # Phase 0 hand-curated categories
    Resources/Assets.xcassets/             # AppIcon placeholder, AccentColor
  Tests/MyAIMapTests/
    UniverseLayoutTests.swift              # Parity checks against web math
```

## What's intentionally not here yet

- **AppIcon-1024.png** — placeholder. Drop a 1024×1024 PNG into
  `Sources/MyAIMap/Resources/Assets.xcassets/AppIcon.appiconset/`
  before TestFlight upload.
- **Real `tools` array** — Phase 1 ports `src/data/ai-tool-universe.ts`.
- **`PocketWorldShell`, `CategoryRing`, `ToolNode`** entities — Phase 1.
- **`ProximityCategoryWatcher`** ECS system — Phase 2.
- **Bloom / Bezier edges / force-directed layout** — Phase 3.
- **App Store metadata + privacy nutrition labels** — Phase 4.

## Coding convention

- Swift 6, strict concurrency.
- iOS 18.0 minimum (the RealityView APIs we need land there).
- MVVM-ish: views are dumb, view models are `@Observable`, the
  universe state lives in a single source of truth.
- Layout math stays in pure `simd` modules so it's testable without
  importing RealityKit.
- Brand identifier: `com.iliaturilia.myaimap`.
- Marketing name: **My AI Map**.
