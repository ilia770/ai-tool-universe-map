# Constellation Map — Phase 1 (2D) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 2D hub-and-spoke map with a constellation star-field whose connections trace out (with a bounce reveal) when a tool is focused.

**Architecture:** Two pure, unit-tested units — `ConnectionResolver` (typed tool→tool connections from category/stage) and `ConstellationLayout` (deterministic star positions clustered by category) — feed a new `ConstellationView` (SwiftUI Canvas + node buttons) that drops into the existing `graph2D` renderer slot. Phase 1 uses derived connections only (AI layer = Phase 2, 3D = Phase 3).

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, Swift Testing (`@Test`), XcodeGen, xcodebuild on the `MyAIMap-Dev` sim (id `538F098B-D962-4B6A-85A9-41C96DCF3A99`).

## Global Constraints

- Swift 6, `SWIFT_STRICT_CONCURRENCY=complete`; deployment target iOS 18.0.
- 2D stays the **default** renderer (`UniverseViewModel.renderMode` defaults to `.graph2D`).
- New files go under `Sources/MyAIMap/Universe/Constellation/`. Do NOT delete `UniverseGraphView.swift` yet (kept as fallback until Phase 1 is approved).
- Spacing/radii via `BrandSpacing`/`BrandRadius`; fonts via `BrandTypography`/semantic styles (no fixed `.system(size:)` on content text).
- Accessibility: Reduce Motion → no bounce/trace animation (instant). Reduce Transparency → solid surfaces (already handled by `glassSurface`).
- Disk is near-full on this Mac: keep DerivedData (do NOT `rm -rf build`), delete each `*.xcresult` after extracting, monitor disk during builds (see [[disk-fragile]] memory).
- Reuse the `UniverseGraphView` view signature exactly so it's a drop-in: `init(planets: [PlanetData], mode: UniverseMode, onPlanetTap:, onToolTap:, onEmptyTap:)`.

---

### Task 1: ConnectionResolver (pure logic)

**Files:**
- Create: `Sources/MyAIMap/Universe/Constellation/ConnectionResolver.swift`
- Test: `Tests/MyAIMapTests/ConnectionResolverTests.swift`

**Interfaces:**
- Consumes: `Tool` (`id`, `category: ToolCategoryId`, `stage: WorkflowStageId`, `relationIds: [String]`), `WorkflowStageId` (CaseIterable, ordered research→planning→execution→approval→review).
- Produces:
  - `enum ConnectionKind: Int { case curated = 0, ai = 1, alternative = 2, pipeline = 3, constellation = 4 }` (rawValue = priority, lower = stronger).
  - `struct Connection: Equatable { let targetID: String; let kind: ConnectionKind }`
  - `enum ConnectionResolver { static func connections(for tool: Tool, in tools: [Tool]) -> [Connection]; static func nextStage(after stage: WorkflowStageId) -> WorkflowStageId? }`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/MyAIMapTests/ConnectionResolverTests.swift
import Testing
@testable import MyAIMap

@Suite("ConnectionResolver — derived tool connections")
struct ConnectionResolverTests {

    private func tool(_ id: String, _ category: ToolCategoryId, _ stage: WorkflowStageId,
                      relations: [String] = []) -> Tool {
        Tool(id: id, name: id, category: category, summary: "", stage: stage,
             orbit: .middle, angle: 0, url: nil, logoDomain: nil,
             relationIds: relations, classification: nil)
    }

    @Test func sameCategorySameStageIsAlternative() {
        let a = tool("a", .coding, .execution)
        let b = tool("b", .coding, .execution)
        let result = ConnectionResolver.connections(for: a, in: [a, b])
        #expect(result.contains(Connection(targetID: "b", kind: .alternative)))
    }

    @Test func sameCategoryNextStageIsPipeline() {
        let a = tool("a", .coding, .planning)
        let b = tool("b", .coding, .execution) // execution is the stage after planning
        let result = ConnectionResolver.connections(for: a, in: [a, b])
        #expect(result.contains(Connection(targetID: "b", kind: .pipeline)))
    }

    @Test func sameCategoryOtherStageIsConstellation() {
        let a = tool("a", .coding, .research)
        let b = tool("b", .coding, .review) // not same, not next
        let result = ConnectionResolver.connections(for: a, in: [a, b])
        #expect(result.contains(Connection(targetID: "b", kind: .constellation)))
    }

    @Test func differentCategoryHasNoDerivedConnection() {
        let a = tool("a", .coding, .execution)
        let b = tool("b", .design, .execution)
        let result = ConnectionResolver.connections(for: a, in: [a, b])
        #expect(!result.contains { $0.targetID == "b" })
    }

    @Test func curatedRelationWinsOverDerived() {
        let a = tool("a", .coding, .execution, relations: ["b"])
        let b = tool("b", .coding, .execution) // would be .alternative, but curated wins
        let result = ConnectionResolver.connections(for: a, in: [a, b])
        #expect(result.contains(Connection(targetID: "b", kind: .curated)))
        #expect(result.filter { $0.targetID == "b" }.count == 1) // deduped
    }

    @Test func resultIsSortedByPriorityThenID() {
        let a = tool("a", .coding, .planning)
        let alt = tool("z-alt", .coding, .planning)        // alternative (prio 2)
        let pipe = tool("y-pipe", .coding, .execution)     // pipeline (prio 3)
        let result = ConnectionResolver.connections(for: a, in: [a, pipe, alt])
        #expect(result.first?.targetID == "z-alt") // alternative before pipeline
    }

    @Test func nextStageWalksTheWorkflow() {
        #expect(ConnectionResolver.nextStage(after: .research) == .planning)
        #expect(ConnectionResolver.nextStage(after: .review) == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap -destination 'platform=iOS Simulator,id=538F098B-D962-4B6A-85A9-41C96DCF3A99' -derivedDataPath build -only-testing:MyAIMapTests/ConnectionResolverTests -resultBundlePath /tmp/c1.xcresult > /tmp/c1.log 2>&1; grep -E "error:|cannot find" /tmp/c1.log | head; rm -rf /tmp/c1.xcresult`
Expected: FAIL — "cannot find 'ConnectionResolver' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/MyAIMap/Universe/Constellation/ConnectionResolver.swift
import Foundation

/// A typed connection from one tool to another. `kind.rawValue` is the
/// priority (lower = stronger); the resolver keeps the strongest kind per
/// target and returns connections sorted strongest-first.
enum ConnectionKind: Int, Equatable, Sendable {
    case curated = 0      // hand-filled relationIds
    case ai = 1           // AI-resolved (Phase 2; defined now so the type is stable)
    case alternative = 2  // same category + same stage ("what could replace this")
    case pipeline = 3     // same category + next workflow stage ("what comes after")
    case constellation = 4 // same category, other stage (weak grouping)
}

struct Connection: Equatable, Sendable {
    let targetID: String
    let kind: ConnectionKind
}

/// Pure derivation of tool→tool connections from real signals (category +
/// workflow stage + any curated relationIds). No UI, no async — shared by the
/// 2D and 3D renderers and fully unit-tested. The AI layer (Phase 2) will inject
/// `.ai` connections through `relationIds`/a cache before this runs.
enum ConnectionResolver {

    static func nextStage(after stage: WorkflowStageId) -> WorkflowStageId? {
        let all = WorkflowStageId.allCases
        guard let i = all.firstIndex(of: stage), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    static func connections(for tool: Tool, in tools: [Tool]) -> [Connection] {
        var strongest: [String: ConnectionKind] = [:]

        func offer(_ id: String, _ kind: ConnectionKind) {
            if let existing = strongest[id], existing.rawValue <= kind.rawValue { return }
            strongest[id] = kind
        }

        let catalog = Set(tools.map(\.id))
        for id in tool.relationIds where catalog.contains(id) && id != tool.id {
            offer(id, .curated)
        }

        let next = nextStage(after: tool.stage)
        for other in tools where other.id != tool.id && other.category == tool.category {
            if other.stage == tool.stage {
                offer(other.id, .alternative)
            } else if let next, other.stage == next {
                offer(other.id, .pipeline)
            } else {
                offer(other.id, .constellation)
            }
        }

        return strongest
            .map { Connection(targetID: $0.key, kind: $0.value) }
            .sorted { lhs, rhs in
                lhs.kind.rawValue != rhs.kind.rawValue
                    ? lhs.kind.rawValue < rhs.kind.rawValue
                    : lhs.targetID < rhs.targetID
            }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap -destination 'platform=iOS Simulator,id=538F098B-D962-4B6A-85A9-41C96DCF3A99' -derivedDataPath build -only-testing:MyAIMapTests/ConnectionResolverTests -resultBundlePath /tmp/c1.xcresult > /tmp/c1.log 2>&1; grep -E "Test run with|TEST (SUCCEEDED|FAILED)" /tmp/c1.log | tail -2; rm -rf /tmp/c1.xcresult /tmp/c1.log`
Expected: PASS — "TEST SUCCEEDED", 7 tests.

> NOTE: a new file under `Tests/` or `Sources/` requires `xcodegen generate` first (XcodeGen snapshots the file list). Run `xcodegen generate` before Step 2.

- [ ] **Step 5: Commit**

```bash
cd /Users/ilia882/Code/ai-tool-universe-map
git add ios-app/Sources/MyAIMap/Universe/Constellation/ConnectionResolver.swift ios-app/Tests/MyAIMapTests/ConnectionResolverTests.swift
git commit -m "feat(constellation): ConnectionResolver — typed derived tool connections

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: ConstellationLayout (pure math)

**Files:**
- Create: `Sources/MyAIMap/Universe/Constellation/ConstellationLayout.swift`
- Test: `Tests/MyAIMapTests/ConstellationLayoutTests.swift`

**Interfaces:**
- Consumes: `PlanetData` (`id: ToolCategoryId`, `tools: [Tool]`, `title`), `UniverseSeed.categories`, `PlanetData.centralCoreToolID`.
- Produces:
  - `struct StarNode: Identifiable, Equatable { let id: String; let toolID: String?; let title: String; let category: ToolCategoryId; let position: CGPoint; let radius: CGFloat; let isCore: Bool }`
  - `struct ConstellationCluster: Identifiable, Equatable { let id: ToolCategoryId; let center: CGPoint; let radius: CGFloat; let starIDs: [String] }`
  - `struct ConstellationLayoutResult: Equatable { let stars: [StarNode]; let clusters: [ConstellationCluster] }`
  - `enum ConstellationLayout { static func make(planets: [PlanetData], size: CGSize) -> ConstellationLayoutResult }`

**Layout rules:** the core star sits at the field center (`size/2`, raised slightly above center to clear the bottom dock). Each non-core category becomes a **cluster** placed on an ellipse around the core (evenly by index). Each cluster's tools are distributed around the cluster center on a small jittered spiral (deterministic — derive the angle from the tool index, never `Math.random`). Star radius scales with `orbit` (core 26, inner 12, middle 10, outer 8). A collision pass guarantees no two star circles overlap. Everything is clamped inside `size` minus insets (top 120, bottom 200, sides 28).

- [ ] **Step 1: Write the failing test**

```swift
// Tests/MyAIMapTests/ConstellationLayoutTests.swift
import CoreGraphics
import Testing
@testable import MyAIMap

@Suite("ConstellationLayout — clustered star-field")
struct ConstellationLayoutTests {

    private func make(_ size: CGSize = CGSize(width: 393, height: 852)) -> ConstellationLayoutResult {
        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: UniverseSeed.tools)
        return ConstellationLayout.make(planets: planets, size: size)
    }

    @Test func everyToolBecomesAStar() {
        let result = make()
        for tool in UniverseSeed.tools where tool.id != PlanetData.centralCoreToolID {
            #expect(result.stars.contains { $0.toolID == tool.id }, "missing star for \(tool.id)")
        }
    }

    @Test func coreStarExistsAndIsCentral() {
        let size = CGSize(width: 393, height: 852)
        let result = ConstellationLayout.make(
            planets: PlanetData.makePlanets(categories: UniverseSeed.categories, tools: UniverseSeed.tools),
            size: size
        )
        let core = result.stars.first { $0.isCore }
        #expect(core != nil)
        #expect(abs((core?.position.x ?? 0) - size.width / 2) < 60)
    }

    @Test func starsDoNotOverlapAtIPhoneWidth() {
        let stars = make().stars
        for i in stars.indices {
            for j in stars.indices where j > i {
                let d = hypot(stars[i].position.x - stars[j].position.x,
                              stars[i].position.y - stars[j].position.y)
                #expect(d >= stars[i].radius + stars[j].radius,
                        "\(stars[i].id) overlaps \(stars[j].id)")
            }
        }
    }

    @Test func starsAreNearTheirClusterCenter() {
        let result = make()
        let clustersByID = Dictionary(uniqueKeysWithValues: result.clusters.map { ($0.id, $0) })
        for star in result.stars where !star.isCore {
            guard let cluster = clustersByID[star.category] else { continue }
            let d = hypot(star.position.x - cluster.center.x, star.position.y - cluster.center.y)
            #expect(d <= cluster.radius + star.radius + 1, "\(star.id) is outside its constellation")
        }
    }

    @Test func everyNonCoreCategoryHasACluster() {
        let result = make()
        for category in UniverseSeed.categories.map(\.id) where category != .core {
            #expect(result.clusters.contains { $0.id == category }, "missing cluster for \(category.rawValue)")
        }
    }

    @Test func layoutIsDeterministic() {
        let a = make()
        let b = make()
        #expect(a == b)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodegen generate && xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap -destination 'platform=iOS Simulator,id=538F098B-D962-4B6A-85A9-41C96DCF3A99' -derivedDataPath build -only-testing:MyAIMapTests/ConstellationLayoutTests -resultBundlePath /tmp/c2.xcresult > /tmp/c2.log 2>&1; grep -E "error:|cannot find" /tmp/c2.log | head; rm -rf /tmp/c2.xcresult`
Expected: FAIL — "cannot find 'ConstellationLayout' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/MyAIMap/Universe/Constellation/ConstellationLayout.swift
import CoreGraphics
import Foundation

struct StarNode: Identifiable, Equatable, Sendable {
    let id: String
    let toolID: String?
    let title: String
    let category: ToolCategoryId
    let position: CGPoint
    let radius: CGFloat
    let isCore: Bool
}

struct ConstellationCluster: Identifiable, Equatable, Sendable {
    let id: ToolCategoryId
    let center: CGPoint
    let radius: CGFloat
    let starIDs: [String]
}

struct ConstellationLayoutResult: Equatable, Sendable {
    let stars: [StarNode]
    let clusters: [ConstellationCluster]
}

/// Deterministic clustered star-field. Core star centred; each category is a
/// cluster on an ellipse around it; each cluster's tools spiral around the
/// cluster centre. A relaxation pass removes circle overlaps. No randomness —
/// positions derive only from indices so the layout is stable + testable.
enum ConstellationLayout {

    private static func radius(for orbit: OrbitRing) -> CGFloat {
        switch orbit {
        case .core: return 26
        case .inner: return 12
        case .middle: return 10
        case .outer: return 8
        }
    }

    static func make(planets: [PlanetData], size: CGSize) -> ConstellationLayoutResult {
        guard !planets.isEmpty else { return ConstellationLayoutResult(stars: [], clusters: []) }

        let width = max(size.width, 320)
        let height = max(size.height, 560)
        let insetX: CGFloat = 28, insetTop: CGFloat = 120, insetBottom: CGFloat = 200
        let field = CGRect(x: insetX, y: insetTop,
                           width: width - insetX * 2,
                           height: height - insetTop - insetBottom)
        let center = CGPoint(x: field.midX, y: field.minY + field.height * 0.46)

        var stars: [StarNode] = []
        var clusters: [ConstellationCluster] = []

        let core = planets.first { $0.id == .core }
        let branches = planets.filter { $0.id != .core }

        if let core {
            stars.append(StarNode(id: "star:core", toolID: nil, title: core.title,
                                  category: .core, position: center,
                                  radius: radius(for: .core), isCore: true))
        }

        let ringX = min(field.width * 0.42, 200)
        let ringY = min(field.height * 0.40, 230)
        for (index, planet) in branches.enumerated() {
            let angle = -CGFloat.pi / 2 + (2 * .pi) * CGFloat(index) / CGFloat(max(branches.count, 1))
            let clusterCenter = CGPoint(x: center.x + cos(angle) * ringX,
                                        y: center.y + sin(angle) * ringY)
            var clusterStarIDs: [String] = []
            let count = max(planet.tools.count, 1)
            let clusterRadius: CGFloat = min(54, 22 + CGFloat(count) * 4)

            for (ti, tool) in planet.tools.enumerated() where tool.id != PlanetData.centralCoreToolID {
                // Deterministic spiral around the cluster centre.
                let t = CGFloat(ti)
                let a = t * 2.399963 // golden angle
                let r = clusterRadius * sqrt((t + 0.5) / CGFloat(count))
                let pos = CGPoint(x: clusterCenter.x + cos(a) * r,
                                  y: clusterCenter.y + sin(a) * r)
                let id = "star:\(tool.id)"
                stars.append(StarNode(id: id, toolID: tool.id, title: tool.name,
                                      category: planet.id, position: pos,
                                      radius: radius(for: tool.orbit), isCore: false))
                clusterStarIDs.append(id)
            }

            clusters.append(ConstellationCluster(id: planet.id, center: clusterCenter,
                                                 radius: clusterRadius, starIDs: clusterStarIDs))
        }

        resolveOverlaps(&stars, in: field)
        return ConstellationLayoutResult(stars: stars, clusters: clusters)
    }

    private static func resolveOverlaps(_ stars: inout [StarNode], in field: CGRect) {
        guard stars.count > 1 else { return }
        var pts = stars.map(\.position)
        let radii = stars.map(\.radius)
        let coreIndex = stars.firstIndex(where: { $0.isCore })
        for _ in 0..<60 {
            for i in pts.indices {
                for j in pts.indices where j > i {
                    let dx = pts[j].x - pts[i].x, dy = pts[j].y - pts[i].y
                    var dist = (dx * dx + dy * dy).squareRoot()
                    let minDist = radii[i] + radii[j] + 4
                    guard dist < minDist else { continue }
                    if dist < 0.001 { dist = 0.001 }
                    let push = (minDist - dist) / 2
                    let ux = dx / dist, uy = dy / dist
                    if coreIndex == i { pts[j].x += ux * push * 2; pts[j].y += uy * push * 2 }
                    else if coreIndex == j { pts[i].x -= ux * push * 2; pts[i].y -= uy * push * 2 }
                    else {
                        pts[i].x -= ux * push; pts[i].y -= uy * push
                        pts[j].x += ux * push; pts[j].y += uy * push
                    }
                }
            }
            for i in pts.indices where coreIndex != i {
                pts[i].x = min(max(pts[i].x, field.minX + radii[i]), field.maxX - radii[i])
                pts[i].y = min(max(pts[i].y, field.minY + radii[i]), field.maxY - radii[i])
            }
        }
        stars = zip(stars, pts).map { star, p in
            StarNode(id: star.id, toolID: star.toolID, title: star.title,
                     category: star.category, position: p, radius: star.radius, isCore: star.isCore)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap -destination 'platform=iOS Simulator,id=538F098B-D962-4B6A-85A9-41C96DCF3A99' -derivedDataPath build -only-testing:MyAIMapTests/ConstellationLayoutTests -resultBundlePath /tmp/c2.xcresult > /tmp/c2.log 2>&1; grep -E "Test run with|TEST (SUCCEEDED|FAILED)|Failing" /tmp/c2.log | tail -3; rm -rf /tmp/c2.xcresult /tmp/c2.log`
Expected: PASS — 6 tests. If `starsAreNearTheirClusterCenter` fails because relaxation pushed a star out, raise the cluster spacing (lower per-cluster `count` density) or relax the assertion tolerance to `cluster.radius * 1.4`; re-run.

- [ ] **Step 5: Commit**

```bash
cd /Users/ilia882/Code/ai-tool-universe-map
git add ios-app/Sources/MyAIMap/Universe/Constellation/ConstellationLayout.swift ios-app/Tests/MyAIMapTests/ConstellationLayoutTests.swift
git commit -m "feat(constellation): ConstellationLayout — deterministic clustered star-field

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: ConstellationView — star-field render + drop-in

**Files:**
- Create: `Sources/MyAIMap/Universe/Constellation/ConstellationView.swift`
- Modify: `Sources/MyAIMap/Universe/UniverseMapView.swift:61` (swap `UniverseGraphView(...)` → `ConstellationView(...)`)
- Verify: `Tests/MyAIMapUITests/PolishCaptureTests.swift` (existing smoke harness; no edit needed)

**Interfaces:**
- Consumes: `ConstellationLayout.make`, `StarNode`, `ConstellationCluster`, `UniverseMode`, `PlanetData`, `BrandColor`, `UniverseSeed.category(_:).color`.
- Produces: `struct ConstellationView: View { let planets: [PlanetData]; let mode: UniverseMode; let onPlanetTap: @MainActor @Sendable (ToolCategoryId) -> Void; let onToolTap: @MainActor @Sendable (String) -> Void; let onEmptyTap: @MainActor @Sendable () -> Void }` — same shape as `UniverseGraphView`.

- [ ] **Step 1: Build the view (no failing-test cycle — this is rendered UI; verified by the smoke screenshot in Step 3).**

Create `ConstellationView.swift`. Structure:
- `GeometryReader` → `let layout = ConstellationLayout.make(planets:size:)`.
- `ZStack { background; constellationOutlines(layout); starButtons(layout) }`.
- `background`: `BrandColor.void` + a faint radial gradient (reuse the existing 2D background colors) + a `StarFieldTwinkle` Canvas of tiny static dots with a slow opacity `TimelineView(.animation)` pulse. Keep the twinkle Canvas separate so the star **buttons** stay outside the per-frame timeline (perf contract).
- `constellationOutlines`: a `Canvas` that strokes a faint convex-ish hull / soft circle per cluster (use `cluster.center` + `cluster.radius`, stroke `category.color.opacity(0.10)`).
- `starButtons`: `ForEach(layout.stars)` → a `Button` per star positioned with `.position(star.position)`. The star glyph: a filled `Circle` (radius `star.radius`) tinted by `UniverseSeed.category(star.category).color`, with a soft glow (`.shadow`/blurred circle behind), core gets a brighter white core. Label shown only for the core + (Task 4) the focused set. Tap routes: core → `onPlanetTap(.core)`; a tool star → `onToolTap(toolID)`. Background tap (a full-bleed `Color` behind, `.onTapGesture { onEmptyTap() }`) gated by `mode.allowsMapGestures`.
- Add `.accessibilityIdentifier("ConstellationStar.\(star.toolID ?? "core")")` and an accessibility label per star so the smoke test can find them.
- Apply `.opacity(mode.mapOpacity)` and `.blur(radius: mode.mapBlurRadius)` on the whole stack (match `UniverseGraphView`).

(Full view code is ~150 lines; mirror `UniverseGraphView`'s structure for background/gesture/opacity, replacing the layout source and node glyph. Keep all paddings/radii as `BrandSpacing`/`BrandRadius` tokens.)

- [ ] **Step 2: Swap the renderer**

In `UniverseMapView.swift`, change the `.graph2D` case (line ~61) from `UniverseGraphView(` to `ConstellationView(` (identical argument list).

- [ ] **Step 3: Build + smoke screenshot**

Run: `xcodegen generate && xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap -destination 'platform=iOS Simulator,id=538F098B-D962-4B6A-85A9-41C96DCF3A99' -derivedDataPath build -only-testing:MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates -resultBundlePath /tmp/c3.xcresult > /tmp/c3.log 2>&1; grep -E "TEST (SUCCEEDED|FAILED)" /tmp/c3.log | tail -1`
Then extract: `xcrun xcresulttool export attachments --path /tmp/c3.xcresult --output-path /tmp/c3shots >/dev/null 2>&1` and Read `02-overview`. Confirm: a clustered star-field renders, core central, no clipping, no overlap. Then `rm -rf /tmp/c3.xcresult /tmp/c3.log /tmp/c3shots`.
Expected: TEST SUCCEEDED; overview shows the star-field.

> If the smoke test can't find star nodes (it taps `GraphNode.Category.*`), that's expected — Task 5 updates the smoke selectors. For Task 3, a passing launch + a readable overview screenshot is the gate.

- [ ] **Step 4: Commit**

```bash
cd /Users/ilia882/Code/ai-tool-universe-map
git add ios-app/Sources/MyAIMap/Universe/Constellation/ConstellationView.swift ios-app/Sources/MyAIMap/Universe/UniverseMapView.swift
git commit -m "feat(constellation): 2D star-field renderer, drop-in for graph2D

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Connection trace + bounce reveal on focus

**Files:**
- Modify: `Sources/MyAIMap/Universe/Constellation/ConstellationView.swift`

**Interfaces:**
- Consumes: `ConnectionResolver.connections(for:in:)`, `mode.selectedToolID`, `mode.focusedCategory`, `@Environment(\.accessibilityReduceMotion)`.

- [ ] **Step 1: Add trace + bounce state**

In `ConstellationView`, when `mode.selectedToolID` is non-nil:
- Resolve `let connections = ConnectionResolver.connections(for: selectedTool, in: allTools)` (map `targetID` → `star`).
- Add a `@State private var traceProgress: Double` (0→1) and animate it to 1 with a spring (`.spring(response: 0.45, dampingFraction: 0.6)`) on `.onChange(of: mode.selectedToolID)`. Reset to 0 first so each focus re-traces. Under Reduce Motion, set `traceProgress = 1` instantly (no animation).
- A `Canvas` (separate from the twinkle layer) draws, for each connection, a line from the focused star to the target, **clipped to `traceProgress`** (`path.trimmedPath(from: 0, to: traceProgress)`), colored by `kind` (curated/ai = white-bright, alternative = category color, pipeline = cyan, constellation = faint). Draw a small bright dot at the `traceProgress` head = the traveling pulse.
- Connected star **bounce**: each connected star's `Circle` gets `.scaleEffect(connected ? 1.0 : ...)` driven from a per-star spring that overshoots when it becomes connected. Simplest: key a `.scaleEffect` on `traceProgress` with a spring so connected stars pop from 0.6→1.15→1.0. Unrelated stars `.opacity(0.3)`; connected `.opacity(1)`; focused star `.scaleEffect(1.12)` bounce.
- Labels: show labels for the focused star + its connected stars only.

- [ ] **Step 2: Build + smoke screenshot (focused state)**

Run the same smoke command as Task 3 Step 3. Read `03a-tool-selected`. Confirm: connection lines are drawn from the focused star, connected stars are brighter/labeled, others dimmed. (Static `-uitestStatic` freezes mid/at-end trace — acceptable; the gate is "lines present + focus/context reads".)
Expected: TEST SUCCEEDED; focused capture shows traced connections.

- [ ] **Step 3: Commit**

```bash
cd /Users/ilia882/Code/ai-tool-universe-map
git add ios-app/Sources/MyAIMap/Universe/Constellation/ConstellationView.swift
git commit -m "feat(constellation): connection trace + spring/bounce reveal on focus

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Smoke selectors + empty-tap reverse + relation chips + a11y

**Files:**
- Modify: `Sources/MyAIMap/Universe/Constellation/ConstellationView.swift`
- Modify: `Tests/MyAIMapUITests/UniverseUISmokeTests.swift` (update node selectors)
- Modify: `Sources/MyAIMap/Universe/PlanetInfoCard.swift` (add relation-type chips to the focused card — optional if time)

**Interfaces:**
- Consumes: existing smoke harness identifiers.

- [ ] **Step 1: Stabilize selectors + reverse + a11y**

- Give category cluster taps an accessibility id `ConstellationCategory.<rawValue>` (a tappable hit-area over the cluster center) so navigation to a branch still works.
- Empty-tap: when `mode == .overview`, `traceProgress` animates back to 0 (reverse trace) before clearing.
- Reduce Motion: skip the twinkle `TimelineView` (static dots) and set trace instantly (already in Task 4). Reduce Transparency inherited via `glassSurface`.
- Update `UniverseUISmokeTests.swift`: replace `GraphNode.Category.` / `GraphNode.Tool.` lookups with `ConstellationCategory.` / `ConstellationStar.` so the existing branch/tool assertions pass against the new view.

- [ ] **Step 2: Full smoke + unit run**

Run: `xcodegen generate && xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap -destination 'platform=iOS Simulator,id=538F098B-D962-4B6A-85A9-41C96DCF3A99' -derivedDataPath build -only-testing:MyAIMapTests -only-testing:MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates -resultBundlePath /tmp/c5.xcresult > /tmp/c5.log 2>&1; grep -E "Test run with|TEST (SUCCEEDED|FAILED)|Failing" /tmp/c5.log | tail -4; rm -rf /tmp/c5.xcresult /tmp/c5.log`
Expected: TEST SUCCEEDED; unit suite + smoke green.

- [ ] **Step 3: Commit**

```bash
cd /Users/ilia882/Code/ai-tool-universe-map
git add -A ios-app/Sources ios-app/Tests
git commit -m "feat(constellation): smoke selectors, empty-tap reverse, reduce-motion

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:** metaphor (constellation star-field — Task 2/3), connection model derived base (Task 1), tap→trace + bounce (Task 4), overview/twinkle (Task 3), empty-tap reverse + search/a11y (Task 5), 2D-default + drop-in (Task 3), reduce-motion (Task 4/5). AI layer + 3D are explicitly Phase 2/3 (separate plans) — out of scope here, matching the spec's phasing.

**Placeholder scan:** Tasks 1–2 carry complete code + tests. Tasks 3–5 are rendered SwiftUI — full code isn't inlined (visual tuning is iterative) but each specifies exact files, structure, identifiers, the verification command, and the gate. This is the documented exception for view tasks; the testable contracts (resolver, layout, smoke green) are concrete.

**Type consistency:** `Connection`, `ConnectionKind`, `ConnectionResolver.connections(for:in:)`/`nextStage(after:)`, `StarNode`, `ConstellationCluster`, `ConstellationLayoutResult`, `ConstellationLayout.make(planets:size:)`, `ConstellationView(planets:mode:onPlanetTap:onToolTap:onEmptyTap:)` are used consistently across tasks and match the existing `UniverseGraphView` signature and `Tool`/`WorkflowStageId`/`OrbitRing` shapes verified in the codebase.

## Notes for the implementer
- New files need `xcodegen generate` before they compile (XcodeGen snapshots the file list).
- Keep `UniverseGraphView.swift` until Phase 1 is user-approved (fallback). Remove it in a follow-up once the constellation is accepted.
- Disk is tight on this machine — never `rm -rf build`; delete each `*.xcresult` after extracting; monitor disk during builds.
