# My AI Map — iOS app

Native iOS port of the [AI Tool Universe Map](https://ai-tool-universe-map.vercel.app)
to SwiftUI + RealityKit.

This directory holds the native iOS app per `docs/IOS_STRATEGY.md`.
Phase 0 created the SwiftUI + RealityKit scaffold; Phase 1 starts the
usable product shell: branded `My AI Map` chrome, category controls,
a glass bottom sheet, curated real tool data, and a RealityKit universe
that opens the selected category as a roomier pocket world.

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
- **Full `tools` array** — Phase 1 currently ships a curated seed slice
  for dogfooding; the full web array still needs to be ported/generated.
- **Full `PocketWorldShell`, `CategoryRing`, `ToolNode` ECS parity** —
  the current RealityKit scene has native category anchors and tool
  nodes, but not the full web visual grammar yet.
- **`ProximityCategoryWatcher`** ECS system — Phase 2.
- **Bloom / Bezier edges / force-directed layout** — Phase 3.
- **App Store metadata + privacy nutrition labels** — Phase 4.

## Phase 1 verification note

This repo can run a Swift parser sanity check without full Xcode:

```bash
xcrun swiftc -parse $(find Sources/MyAIMap -name '*.swift' | sort)
```

Simulator builds require full Xcode selected with `xcode-select`, not
just Command Line Tools.

## Coding convention

- Swift 6, strict concurrency.
- iOS 18.0 minimum (the RealityView APIs we need land there).
- MVVM-ish: views are dumb, view models are `@Observable`, the
  universe state lives in a single source of truth.
- Layout math stays in pure `simd` modules so it's testable without
  importing RealityKit.
- Brand identifier: `com.iliaturilia.myaimap`.
- Marketing name: **My AI Map**.
