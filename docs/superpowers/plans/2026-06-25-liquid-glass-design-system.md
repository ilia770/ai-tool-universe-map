# Liquid Glass Design System (PR #1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the reusable Liquid Glass *morph* primitive, a ≥44pt hit-area helper, a rounded primary-control-label token, and an XCUITest autotap harness — the foundation every later surface-restyle PR builds on.

**Architecture:** Extend the existing token/effect layer (do NOT recreate it). `BrandSpacing` and `BrandTypography` (rounded-by-role) already exist; add one `controlLabel` token. The new core is `GlassMorphCluster` — a horizontal option cluster whose *selected* option is a single travelling glass shape (one `glassEffectID` morphs between slots), built on the existing `glassSurface` 3-tier + `navigationGlassMorphID` morph plumbing. Pure sub-logic (selection id, clamp, hit-area floor) is unit-tested; the glass visuals are proven by an XCUITest against a launch-arg demo screen.

**Tech Stack:** SwiftUI (iOS 26 Liquid Glass: `GlassEffectContainer`, `.glassEffect`, `.glassEffectID`), Swift Testing (unit), XCUITest (`MyAIMapUITests` target), XcodeGen.

## Global Constraints

- iOS 26 morph MUST be behind `#available(iOS 26.0, *)`; iOS 18–25 falls back to `matchedGeometryEffect`, Reduce Transparency to opaque `BrandColor.glassSolid` — all via the existing `glassSurface` / `navigationGlassMorphID`. Never call `.glassEffect` directly.
- Track A: the 2D graph stays the default render mode; this PR migrates NO existing surface (only adds the primitive + a hidden demo). No behavior change to shipping screens.
- No inline magic paddings — pull gaps from `BrandSpacing`.
- A `GlassEffectContainer`'s `spacing` MUST equal the cluster's `HStack` spacing.
- Build/test ONLY via `bash scripts/ios-verify.sh --run-tests --device-id <udid>` (XcodeGen picks up new files; bare xcodebuild misses them). Sim: `4F5273F7-8E4A-4CDD-8938-DF478A20193B`.
- Every commit message ends with: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 1: Hit-area floor + `.hitArea` modifier

**Files:**
- Create: `ios-app/Sources/MyAIMap/UI/Effects/HitArea.swift`
- Test: `ios-app/Tests/MyAIMapTests/HitAreaTests.swift`

**Interfaces:**
- Produces: `enum HitArea { static let minimum: CGFloat = 44; static func floored(_ size: CGSize, min: CGFloat = minimum) -> CGSize }` and `extension View { func hitArea(min: CGFloat = HitArea.minimum) -> some View }`.

- [ ] **Step 1: Write the failing test**

```swift
// HitAreaTests.swift
import Testing
import CoreGraphics
@testable import MyAIMap

@Suite("HitArea floor")
struct HitAreaTests {
    @Test func expandsBothDimensionsToMinimum() {
        #expect(HitArea.floored(CGSize(width: 10, height: 10)) == CGSize(width: 44, height: 44))
    }
    @Test func keepsDimensionsAlreadyAboveMinimum() {
        #expect(HitArea.floored(CGSize(width: 60, height: 30)) == CGSize(width: 60, height: 44))
    }
    @Test func respectsCustomMinimum() {
        #expect(HitArea.floored(CGSize(width: 5, height: 5), min: 30) == CGSize(width: 30, height: 30))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scripts/ios-verify.sh --run-tests --device-id 4F5273F7-8E4A-4CDD-8938-DF478A20193B`
Expected: FAIL — `cannot find 'HitArea' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// HitArea.swift
import SwiftUI

/// HIG minimum tap target. `floored` is the pure size math (unit-tested);
/// `.hitArea()` applies it to a view plus a hit-testable content shape.
enum HitArea {
    static let minimum: CGFloat = 44

    static func floored(_ size: CGSize, min: CGFloat = minimum) -> CGSize {
        CGSize(width: Swift.max(size.width, min), height: Swift.max(size.height, min))
    }
}

extension View {
    /// Guarantees a >= `min` x `min` tappable region around a control,
    /// regardless of its visual size, and makes the whole region hit-testable.
    func hitArea(min: CGFloat = HitArea.minimum) -> some View {
        frame(minWidth: min, minHeight: min).contentShape(Rectangle())
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scripts/ios-verify.sh --run-tests --device-id 4F5273F7-8E4A-4CDD-8938-DF478A20193B`
Expected: PASS (look for `** TEST SUCCEEDED **`).

- [ ] **Step 5: Commit**

```bash
git add ios-app/Sources/MyAIMap/UI/Effects/HitArea.swift ios-app/Tests/MyAIMapTests/HitAreaTests.swift
git commit -m "feat(glass): HitArea floor + .hitArea modifier (HIG 44pt)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Morph-cluster selection logic

**Files:**
- Create: `ios-app/Sources/MyAIMap/UI/Effects/GlassMorphSelection.swift`
- Test: `ios-app/Tests/MyAIMapTests/GlassMorphSelectionTests.swift`

**Interfaces:**
- Produces: `enum GlassMorphSelection { static func glassID(optionIndex: Int, selectedIndex: Int, base: String) -> String; static func clamped(_ index: Int, count: Int) -> Int }`.

- [ ] **Step 1: Write the failing test**

```swift
// GlassMorphSelectionTests.swift
import Testing
@testable import MyAIMap

@Suite("GlassMorphCluster selection logic")
struct GlassMorphSelectionTests {
    @Test func selectedOptionSharesTheSingleTravellingID() {
        // The selected slot carries the one "active" id; that shared id is what
        // makes a single glass shape morph between slots.
        #expect(GlassMorphSelection.glassID(optionIndex: 2, selectedIndex: 2, base: "tabs") == "tabs.active")
    }
    @Test func unselectedOptionsCarryStablePerSlotIDs() {
        #expect(GlassMorphSelection.glassID(optionIndex: 1, selectedIndex: 2, base: "tabs") == "tabs.option1")
    }
    @Test func clampGuardsAgainstStaleIndices() {
        #expect(GlassMorphSelection.clamped(5, count: 3) == 2)
        #expect(GlassMorphSelection.clamped(-1, count: 3) == 0)
        #expect(GlassMorphSelection.clamped(0, count: 0) == 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scripts/ios-verify.sh --run-tests --device-id 4F5273F7-8E4A-4CDD-8938-DF478A20193B`
Expected: FAIL — `cannot find 'GlassMorphSelection' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// GlassMorphSelection.swift

/// Pure logic behind `GlassMorphCluster`: which `glassEffectID` each option
/// carries, and a clamp that defends a stored selection against a shrunken
/// option set. Kept free of SwiftUI so it is unit-testable.
enum GlassMorphSelection {
    /// The selected option shares the single travelling "active" id so exactly
    /// one glass shape morphs between slots; others get a stable per-slot id.
    static func glassID(optionIndex: Int, selectedIndex: Int, base: String) -> String {
        optionIndex == selectedIndex ? "\(base).active" : "\(base).option\(optionIndex)"
    }

    static func clamped(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Swift.min(Swift.max(index, 0), count - 1)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scripts/ios-verify.sh --run-tests --device-id 4F5273F7-8E4A-4CDD-8938-DF478A20193B`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ios-app/Sources/MyAIMap/UI/Effects/GlassMorphSelection.swift ios-app/Tests/MyAIMapTests/GlassMorphSelectionTests.swift
git commit -m "feat(glass): GlassMorphCluster selection logic (travelling active id + clamp)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `controlLabel` token + `GlassMorphCluster` view

**Files:**
- Modify: `ios-app/Sources/MyAIMap/UI/Theme/BrandTypography.swift` (add one token)
- Create: `ios-app/Sources/MyAIMap/UI/Components/Glass/GlassMorphCluster.swift`

**Interfaces:**
- Consumes: `HitArea` / `.hitArea` (Task 1); `GlassMorphSelection.glassID/clamped` (Task 2); `glassSurface(tint:interactive:)`, `navigationGlassMorphID(_:in:)`, `BrandSpacing`, `BrandColor`, `BrandMotion`, `withBrandAnimation`, `PressableButtonStyle`, `BrandTypography`.
- Produces: `BrandTypography.controlLabel: Font`; `struct GlassMorphCluster<Option: Identifiable, Label: View>: View` with init `(options: [Option], selection: Binding<Int>, base: String, spacing: CGFloat = BrandSpacing.xs.value, tint: Color? = nil, @ViewBuilder label: @escaping (Option, Bool) -> Label)`.

- [ ] **Step 1: Add the `controlLabel` token**

In `BrandTypography.swift`, after the `chip` token (line ~23), add:

```swift
    /// Primary control label — buttons, pills, tab/segment labels. Rounded so
    /// the interactive layer reads as one tactile family (secondary/metadata
    /// stay `.default`).
    static let controlLabel: Font = .system(.subheadline, design: .rounded, weight: .semibold)
```

- [ ] **Step 2: Write the cluster view**

```swift
// GlassMorphCluster.swift
import SwiftUI

/// A horizontal cluster of options whose *selected* option is a single
/// travelling Liquid Glass shape: one glass element morphs place/shape/size
/// between slots instead of separate elements appearing/disappearing. The
/// canonical pattern for tab bars, segmented controls, and mode toggles.
///
/// Tiering lives in `glassSurface` / `navigationGlassMorphID`: iOS 26 native
/// `glassEffect` + `glassEffectID`; iOS 18–25 `matchedGeometryEffect`; Reduce
/// Transparency opaque. Container spacing equals the HStack spacing per HIG.
struct GlassMorphCluster<Option: Identifiable, Label: View>: View {
    let options: [Option]
    @Binding var selection: Int
    let base: String
    var spacing: CGFloat = BrandSpacing.xs.value
    var tint: Color? = nil
    @ViewBuilder let label: (Option, Bool) -> Label

    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedIndex: Int {
        GlassMorphSelection.clamped(selection, count: options.count)
    }

    var body: some View {
        container {
            HStack(spacing: spacing) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    let isSelected = index == selectedIndex
                    Button {
                        withBrandAnimation(BrandMotion.morph, reduceMotion: reduceMotion) {
                            selection = index
                        }
                    } label: {
                        label(option, isSelected)
                            .font(BrandTypography.controlLabel)
                            .padding(.horizontal, BrandSpacing.m.value)
                            .padding(.vertical, BrandSpacing.s.value)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: .light))
                    .glassSurface(tint: isSelected ? (tint ?? .white.opacity(0.10)) : nil, interactive: true)
                    .navigationGlassMorphID(
                        GlassMorphSelection.glassID(optionIndex: index, selectedIndex: selectedIndex, base: base),
                        in: ns
                    )
                    .hitArea()
                    .accessibilityIdentifier("\(base).\(index)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(spacing)
        }
    }

    @ViewBuilder
    private func container<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}
```

- [ ] **Step 3: Build to verify it compiles (no unit test — Fonts/glass aren't introspectable; proven by Task 4 XCUITest)**

Run: `rm -rf ios-app/build/Logs/Test/*.xcresult; bash scripts/ios-verify.sh --run-tests --device-id 4F5273F7-8E4A-4CDD-8938-DF478A20193B`
Expected: PASS — whole suite still green, new file compiles.

- [ ] **Step 4: Commit**

```bash
git add ios-app/Sources/MyAIMap/UI/Theme/BrandTypography.swift ios-app/Sources/MyAIMap/UI/Components/Glass/GlassMorphCluster.swift
git commit -m "feat(glass): GlassMorphCluster view + rounded controlLabel token

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Demo screen + XCUITest autotap harness

**Files:**
- Create: `ios-app/Sources/MyAIMap/UI/Components/Glass/GlassDemoScreen.swift`
- Modify: `ios-app/Sources/MyAIMap/MyAIMapApp.swift` (gate the demo behind `-uitestGlassDemo`)
- Create: `ios-app/Tests/MyAIMapUITests/GlassMorphClusterUITests.swift`

**Interfaces:**
- Consumes: `GlassMorphCluster` (Task 3).
- Produces: launch arg `-uitestGlassDemo` → root replaced by `GlassDemoScreen`; identifiers `GlassDemo.cluster.<index>` and label `GlassDemo.selectedIndex` (its `.accessibilityValue` is the selected index as a string).

- [ ] **Step 1: Write the demo screen**

```swift
// GlassDemoScreen.swift
import SwiftUI

/// XCUITest-only harness proving the GlassMorphCluster morph + hit area. Gated
/// behind `-uitestGlassDemo`; never reachable in production.
struct GlassDemoScreen: View {
    private struct Opt: Identifiable { let id: Int; let title: String }
    private let options = [Opt(id: 0, title: "Map"), Opt(id: 1, title: "Friends"), Opt(id: 2, title: "Passport")]
    @State private var selection = 0

    var body: some View {
        VStack(spacing: BrandSpacing.section.value) {
            Text("\(selection)")
                .accessibilityIdentifier("GlassDemo.selectedIndex")
                .accessibilityValue("\(selection)")
            GlassMorphCluster(options: options, selection: $selection, base: "GlassDemo.cluster") { opt, selected in
                Text(opt.title).foregroundStyle(selected ? .white : .white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColor.void)
        .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 2: Gate it in `MyAIMapApp.swift`**

In `MyAIMapApp.body`, wrap the root so the demo replaces it under the flag. Change:

```swift
        WindowGroup {
            RootShell()
                .environment(model)
                .preferredColorScheme(.dark)
                .onAppear { ... }
        }
```

to:

```swift
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-uitestGlassDemo") {
                GlassDemoScreen()
            } else {
                RootShell()
                    .environment(model)
                    .preferredColorScheme(.dark)
                    .onAppear { ... }   // keep the existing onAppear body unchanged
            }
        }
```

- [ ] **Step 3: Write the XCUITest**

```swift
// GlassMorphClusterUITests.swift
import XCTest

final class GlassMorphClusterUITests: XCTestCase {
    func testTappingOptionMorphsSelectionAndHasLegalHitTarget() {
        let app = XCUIApplication()
        app.launchArguments += ["-uitestGlassDemo"]
        app.launch()

        let readout = app.staticTexts["GlassDemo.selectedIndex"]
        XCTAssertTrue(readout.waitForExistence(timeout: 10))
        XCTAssertEqual(readout.value as? String, "0")

        let passport = app.buttons["GlassDemo.cluster.2"]
        XCTAssertTrue(passport.waitForExistence(timeout: 5))
        // HIG hit target: the tappable frame is at least 44x44pt.
        XCTAssertGreaterThanOrEqual(passport.frame.height, 44)
        XCTAssertGreaterThanOrEqual(passport.frame.width, 44)

        passport.tap()
        XCTAssertEqual(readout.value as? String, "2")
    }
}
```

- [ ] **Step 4: Run the UITest target to verify it passes**

Run: `rm -rf ios-app/build/Logs/Test/*.xcresult; bash scripts/ios-verify.sh --run-tests --device-id 4F5273F7-8E4A-4CDD-8938-DF478A20193B`
Expected: PASS — both unit and UITest targets green (`** TEST SUCCEEDED **`). If the UITest target needs explicit inclusion, the scheme already lists `MyAIMapUITests` (project.yml test targets).

- [ ] **Step 5: Commit**

```bash
git add ios-app/Sources/MyAIMap/UI/Components/Glass/GlassDemoScreen.swift ios-app/Sources/MyAIMap/MyAIMapApp.swift ios-app/Tests/MyAIMapUITests/GlassMorphClusterUITests.swift
git commit -m "test(glass): demo screen + XCUITest autotap (morph selection + 44pt hit target)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Sim screenshot, push, PR

**Files:** none (verification + delivery).

- [ ] **Step 1: Screenshot the demo for the visual record**

```bash
APP="ios-app/build/Build/Products/Debug-iphonesimulator/My AI Map.app"
xcrun simctl install 4F5273F7-8E4A-4CDD-8938-DF478A20193B "$APP"
xcrun simctl launch 4F5273F7-8E4A-4CDD-8938-DF478A20193B com.ilyatur.myaimap -uitestGlassDemo
# wait ~3s, then:
xcrun simctl io 4F5273F7-8E4A-4CDD-8938-DF478A20193B screenshot scratchpad/glass-demo.png
```
Expected: a centered glass cluster (Map / Friends / Passport) with one tinted glass selection. Confirm no layout break.

- [ ] **Step 2: Full verify green**

Run: `rm -rf ios-app/build/Logs/Test/*.xcresult ios-app/build/*.xcresult; bash scripts/ios-verify.sh --run-tests --device-id 4F5273F7-8E4A-4CDD-8938-DF478A20193B`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Push + open PR**

```bash
git push -u origin feat/liquid-glass-design-system
gh pr create --base main --title "feat(glass): Liquid Glass morph design system (foundation)" \
  --body "GlassMorphCluster (one travelling glass selection), .hitArea (44pt), rounded controlLabel token, XCUITest autotap harness + demo. Tokens (BrandSpacing/BrandTypography) already existed. No shipping surface migrated (Track A). Unit + XCUITest green."
```

- [ ] **Step 4: Device hand-off**

Ask the user to device-test the demo (`-uitestGlassDemo`) for the morph feel, then merge. Surface PRs (chat → universe → sheets → settings → onboarding) follow on this foundation.

---

## Self-Review

**Spec coverage:** spacing scale ✓ (exists — noted), typography rounded-by-role ✓ (exists; +`controlLabel`), morph primitive ✓ (Task 3), hit-area helper ✓ (Task 1), XCUITest harness ✓ (Task 4), demo ✓ (Task 4), Track A ✓ (no surface migrated). Per-surface pipeline + surface order live in the spec; they are PR #2+, intentionally out of this plan.

**Placeholders:** none — every step has concrete code/commands. The one `// keep the existing onAppear body unchanged` is an explicit instruction, not a TODO.

**Type consistency:** `GlassMorphSelection.glassID/clamped`, `HitArea.floored/.hitArea`, `GlassMorphCluster(options:selection:base:spacing:tint:label:)`, `BrandTypography.controlLabel`, identifiers `GlassDemo.cluster.<index>` / `GlassDemo.selectedIndex` — consistent across Tasks 1–4.
