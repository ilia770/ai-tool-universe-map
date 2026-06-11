# My AI Map - iOS app

Native iOS port of the [AI Tool Universe Map](https://ai-tool-universe-map.vercel.app)
to SwiftUI + RealityKit.

This directory holds the native iOS app per `docs/IOS_STRATEGY.md`.
Phase 0 created the SwiftUI + RealityKit scaffold; Phase 1 starts the
usable product shell: branded `My AI Map` chrome, category controls,
a glass bottom sheet, curated real tool data, and a RealityKit universe
that opens the selected category as a roomier pocket world.

## Prerequisites

- macOS with full Xcode 26.5 installed and selected.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation:

  ```bash
  brew install xcodegen
  ```

- Apple Developer Program membership for a real personal TestFlight build.

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

Or from the CLI without booting a simulator:

```bash
cd ..
npm run ios:verify
```

For TestFlight, use Xcode's Archive flow rather than a simulator build:

1. Sign in to Xcode with the Apple Developer account.
2. Set the `MyAIMap` target Team to the account's team.
3. Keep Bundle Identifier as `com.iliaturilia.myaimap`.
4. Create the App Store Connect app with SKU `myaimap-ios`.
5. Product -> Archive -> Distribute App -> App Store Connect -> Upload.

See `TESTFLIGHT_CHECKLIST.md` for the account, signing, screenshot, and
known-risk checklist.

## Tests

Default verification builds the app and test bundle against a generic iOS
Simulator destination:

```bash
npm run ios:verify
```

For full simulator tests, use a concrete simulator id. Device-name matching is
flaky when multiple iOS runtimes are installed.

```bash
xcrun simctl list devices available
npm run ios:verify -- --full-test --device-id <simulator-udid>
```

The native tests cover pure layout, camera, state, proximity, haptics, and
pocket-shell geometry. See `docs/ios/RUNBOOK.md` for the current runner flow.

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

- **Final App Store metadata** - App Store Connect description, keywords,
  privacy labels, screenshots, support URL, and review notes still need to be
  filled in before a public App Store submission.
- **Full `tools` array** — Phase 1 currently ships a curated seed slice
  for dogfooding; the full web array still needs to be ported/generated.
- **Full `PocketWorldShell`, `CategoryRing`, `ToolNode` ECS parity** —
  the current RealityKit scene has native category anchors and tool
  nodes, but not the full web visual grammar yet.
- **`ProximityCategoryWatcher`** ECS system — Phase 2.
- **Bloom / Bezier edges / force-directed layout** — Phase 3.
- **Public App Store release polish** - TestFlight can happen first, but public
  review still needs screenshots, privacy nutrition labels, and a release review
  pass.

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
