# P5 iOS Rich Tool Detail Implementation Plan

> Part of the **2026-06-16 product-v2** set. iOS-only. Branch: `feat/product-v2`.

## Goal

Promote the iOS tool detail from a thin card (`ToolDetailSection.swift`: eyebrow,
name, summary, stage badge, visible-tool rail, connection dots, single Open
button) into the rich "brand window" that the web playground already ships in
`/tmp/wt-ios/src/playground/ToolDetail.tsx`:

- **What it does** (clamped, expandable),
- **Killer features** (staggered bulleted list),
- **Strengths / Watch-outs** (two-column),
- **Who uses it**,
- **Pricing** (model eyebrow + summary card),
- **Connected to · N** (tappable chips that re-focus the linked tool),
- **In-app Open** via the existing `SFSafariViewController` wrapper
  (`InAppBrowserSheet.swift`).

Data comes from the **P0 knowledge layer** (`ToolKnowledge` mirror of the web
`ToolKnowledge` type). Every section honours Reduce Motion, fires brand haptics
on interaction, presses to `scale 0.96`, and the whole sheet keeps its native
swipe-to-dismiss. Pure liquid glass throughout.

## Architecture

```
RootSheet (existing presenting sheet, swipe-dismiss via presentationDetents)
└─ ToolDetailSection (rewritten — the rich brand window)
   ├─ DetailHero            (plate + name + category pill + stage)
   ├─ DetailKnowledgeBody   (sections, only when knowledge.enriched)
   │   ├─ ClampText                "What it does"
   │   ├─ KillerFeaturesList       "Killer features"   (staggered)
   │   ├─ StrengthsWatchouts       "Strengths" / "Watch-outs"
   │   ├─ WhoUsesBlock             "Who uses it"
   │   ├─ PricingCard              "Pricing"
   │   └─ ConnectionsRow           "Connected to · N"  (tappable → focusTool)
   └─ OpenButton            (InAppBrowserSheet, derived URL fallback)
```

- **Knowledge source (P0 dependency):** this plan assumes P0 lands a Swift
  `ToolKnowledge` value type and a `knowledgeFor(_:) -> ToolKnowledge?` lookup,
  mirroring `src/playground/knowledge.ts`. P5 **defines that contract here** (Task 1)
  as a self-contained file so P5 can be built and tested independently; if P0
  already provides an identical type, this file is deleted in favour of P0's.
- **No new presenter:** `ToolDetailSection` stays the content view inside
  `RootSheet`; the sheet already provides glass background, drag indicator and
  swipe-dismiss (`presentationDetents`/`presentationDragIndicator`). We do **not**
  re-implement a custom drag gesture — that is the web's job because the web has
  no system sheet. The native sheet *is* the swipe-dismiss.
- **Reduce Motion:** read `@Environment(\.accessibilityReduceMotion)`; collapse
  per-row stagger/offset to zero and use `.opacity` content transitions only.
- **Haptics:** `BrandHaptics.fire(.light)` on every tap; `PressableButtonStyle`
  already wires press-down haptic + `scale 0.96`.

## Tech Stack

- SwiftUI (deployment target iOS 18, `SWIFT_VERSION 6.0`, strict concurrency).
- `swift-testing` (`import Testing`, `@Suite`/`@Test`/`#expect`) — matches
  `Tests/MyAIMapTests/SearchCoreTests.swift`.
- Liquid glass via the existing `.liquidGlass(in:tint:)` modifier.
- Brand tokens: `BrandColor`, `BrandMotion`, `BrandTypography`, `BrandSpacing`,
  `BrandRadius`, `BrandHaptics`, `PressableButtonStyle`.
- `SFSafariViewController` via existing `InAppBrowserSheet` / `BrowserSheetItem`.
- XcodeGen: sources are folder-globbed, so new files under
  `ios-app/Sources/MyAIMap/...` are picked up after `xcodegen generate`.

**Verify commands (run from `/tmp/wt-ios`):**

```bash
# regenerate project after adding files, then build-for-testing + unit tests
cd ios-app && xcodegen generate
npm run ios:verify        # generic build + build-for-testing
# full unit tests on a booted sim (foreground only — see docs/ios/RUNBOOK.md):
npm run ios:verify -- --full-test --device-id <booted-sim-id>
```

Each task below: write failing test → run → minimal impl → run → commit.
Commit messages end with the `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` trailer.

---

## Task 1 — iOS knowledge model + lookup (`ToolKnowledge`)

Mirror the web `ToolKnowledge` shape so the detail view binds to real types.
This is the P0 contract, declared locally so P5 is self-contained and testable.

**Files**
- Create: `ios-app/Sources/MyAIMap/Data/ToolKnowledge.swift`
- Create: `ios-app/Sources/MyAIMap/Data/ToolKnowledge+Interim.swift`
- Create: `ios-app/Tests/MyAIMapTests/ToolKnowledgeTests.swift`

### Steps

1. **Write failing test** `ios-app/Tests/MyAIMapTests/ToolKnowledgeTests.swift`:

```swift
import Testing
@testable import MyAIMap

@Suite("ToolKnowledge — model + interim derivation")
struct ToolKnowledgeTests {

    private func makeTool(id: String = "t", summary: String = "Does the thing") -> Tool {
        Tool(
            id: id, name: "Tool", category: .coding, summary: summary,
            stage: .execution, orbit: .inner, angle: 0,
            url: nil, logoDomain: nil, relationIds: [], classification: nil
        )
    }

    @Test func interimIsNotEnrichedAndUsesSummaryAsWhatFor() {
        let k = ToolKnowledge.interim(for: makeTool(summary: "Summary text"))
        #expect(k.enriched == false)
        #expect(k.whatFor == "Summary text")
        #expect(k.killerFeatures.isEmpty)
        #expect(k.advantages.isEmpty)
        #expect(k.weaknesses.isEmpty)
        #expect(k.whoUses.isEmpty)
        #expect(k.pricing.model == .unknown)
    }

    @Test func enrichedFlagIsTrueForFullRecord() {
        let k = ToolKnowledge(
            killerFeatures: ["A"], whatFor: "For X", advantages: ["+"],
            weaknesses: ["-"], whoUses: "Devs",
            pricing: .init(model: .freemium, summary: "Free tier + paid"),
            enriched: true
        )
        #expect(k.enriched)
        #expect(k.pricing.model == .freemium)
    }

    @Test func pricingModelDecodesFromWebStringValues() throws {
        // Parity with web PricingModel raw values (hyphenated cases).
        let json = #"{"model":"open-source","summary":"MIT licensed"}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(ToolPricing.self, from: json)
        #expect(p.model == .openSource)
    }
}
```

2. **Run** (expect compile failure — types don't exist):
   `npm run ios:verify -- --full-test --device-id <id>`

3. **Minimal impl** `ios-app/Sources/MyAIMap/Data/ToolKnowledge.swift`:

```swift
import Foundation

/// Pricing model, raw values matching the web `PricingModel` union in
/// `src/playground/knowledge.ts` so the shared JSON payload round-trips.
enum PricingModel: String, Codable, Sendable {
    case free
    case openSource = "open-source"
    case freemium
    case subscription
    case usageBased = "usage-based"
    case enterprise
    case mixed
    case unknown
}

/// One pricing fact: a model bucket plus a human summary line.
struct ToolPricing: Codable, Sendable {
    let model: PricingModel
    let summary: String
}

/// Hyperbrain knowledge for a tool — direct mirror of the web
/// `ToolKnowledge` interface (`src/playground/knowledge.ts`). Populated by
/// the P0 enrichment data; falls back to `interim` when un-researched.
struct ToolKnowledge: Codable, Sendable {
    let killerFeatures: [String]
    let whatFor: String
    let advantages: [String]
    let weaknesses: [String]
    let whoUses: String
    let pricing: ToolPricing
    /// True when deep-researched, false when interim-derived.
    let enriched: Bool
}
```

4. **Minimal impl** `ios-app/Sources/MyAIMap/Data/ToolKnowledge+Interim.swift`:

```swift
import Foundation

extension ToolKnowledge {
    /// Best-effort record for an un-enriched tool — mirrors the web
    /// `interim()` so the detail panel always has *something* to show.
    static func interim(for tool: Tool) -> ToolKnowledge {
        ToolKnowledge(
            killerFeatures: [],
            whatFor: tool.summary,
            advantages: [],
            weaknesses: [],
            whoUses: "",
            pricing: ToolPricing(model: .unknown, summary: "Pricing not yet researched."),
            enriched: false
        )
    }

    /// Best available knowledge for a tool id: enriched record if P0 has one,
    /// else interim-derived. P0 replaces `ENRICHED` with the real data map.
    static func best(for tool: Tool) -> ToolKnowledge {
        if let rich = ToolKnowledgeStore.enriched[tool.id] {
            return rich
        }
        return interim(for: tool)
    }
}

/// P0 knowledge data store. Empty here (P5 contract stub); P0 fills
/// `enriched` from the migrated `knowledge.data.ts` payload. Kept as a
/// separate symbol so the data drop is a one-file change.
enum ToolKnowledgeStore {
    static let enriched: [String: ToolKnowledge] = [:]
}
```

5. **Run** (expect pass). 

6. **Commit:** `feat(ios): add ToolKnowledge model + interim derivation (P5/P0 contract)`

---

## Task 2 — Detail subviews (pure, previewable, testable bits)

Build the section subviews as small files. The only *logic* worth a unit test is
the connections resolver and the derived-URL fallback, so extract those as pure
functions.

**Files**
- Create: `ios-app/Sources/MyAIMap/UI/Sheets/Detail/ToolDetailModel.swift`
- Create: `ios-app/Sources/MyAIMap/UI/Sheets/Detail/DetailSections.swift`
- Create: `ios-app/Tests/MyAIMapTests/ToolDetailModelTests.swift`

### Steps

1. **Write failing test** `ios-app/Tests/MyAIMapTests/ToolDetailModelTests.swift`:

```swift
import Foundation
import Testing
@testable import MyAIMap

@Suite("ToolDetailModel — pure resolvers")
struct ToolDetailModelTests {

    private func tool(
        id: String, url: URL? = nil, logoDomain: String? = nil, relationIds: [String] = []
    ) -> Tool {
        Tool(
            id: id, name: id.capitalized, category: .coding, summary: "—",
            stage: .execution, orbit: .inner, angle: 0,
            url: url, logoDomain: logoDomain, relationIds: relationIds, classification: nil
        )
    }

    @Test func derivedURLPrefersExplicitURL() {
        let t = tool(id: "a", url: URL(string: "https://a.com"), logoDomain: "b.com")
        #expect(ToolDetailModel.derivedURL(for: t)?.absoluteString == "https://a.com")
    }

    @Test func derivedURLFallsBackToLogoDomain() {
        let t = tool(id: "a", url: nil, logoDomain: "figma.com")
        #expect(ToolDetailModel.derivedURL(for: t)?.absoluteString == "https://figma.com")
    }

    @Test func derivedURLIsNilWhenNothingToOpen() {
        #expect(ToolDetailModel.derivedURL(for: tool(id: "a")) == nil)
    }

    @Test func connectionsResolveAndSkipMissingIDs() {
        let library = [tool(id: "a"), tool(id: "b")]
        let subject = tool(id: "s", relationIds: ["b", "ghost", "a"])
        let resolved = ToolDetailModel.connections(for: subject, in: library)
        #expect(resolved.map(\.id) == ["b", "a"])  // order preserved, ghost dropped
    }
}
```

2. **Run** (expect compile failure).

3. **Minimal impl** `ios-app/Sources/MyAIMap/UI/Sheets/Detail/ToolDetailModel.swift`:

```swift
import Foundation

/// Pure helpers behind the rich detail view — kept free of SwiftUI so they
/// are unit-testable and mirror the web `derivedUrl` / connection resolve.
enum ToolDetailModel {

    /// Best-effort destination for url-less seed tools: explicit `url`, else
    /// `https://<logoDomain>`, else nil. Mirrors `derivedUrl` in ToolDetail.tsx.
    static func derivedURL(for tool: Tool) -> URL? {
        if let url = tool.url { return url }
        if let domain = tool.logoDomain, !domain.isEmpty {
            return URL(string: "https://\(domain)")
        }
        return nil
    }

    /// Resolves `relationIds` against a library, preserving order and skipping
    /// ids that don't resolve (defensive — stale refs must never crash).
    static func connections(for tool: Tool, in library: [Tool]) -> [Tool] {
        let byID = Dictionary(library.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return tool.relationIds.compactMap { byID[$0] }
    }
}
```

4. **Minimal impl** `ios-app/Sources/MyAIMap/UI/Sheets/Detail/DetailSections.swift`
   — the presentation building blocks. Reduce-Motion-aware, glass, haptic.

```swift
import SwiftUI

/// Eyebrow + content wrapper, matching the web `Section` (uppercase label).
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            Text(title.uppercased())
                .font(BrandTypography.eyebrow)
                .tracking(1.4)
                .foregroundStyle(BrandColor.textMuted)
            content
        }
    }
}

/// "What it does": 3-line clamp with an inline More/Less toggle.
struct ClampText: View {
    let text: String
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
            Text(text)
                .font(BrandTypography.body)
                .foregroundStyle(BrandColor.textSecondary)
                .lineSpacing(3)
                .lineLimit(expanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)

            if text.count > 140 {  // cheap clampable heuristic — avoids a measure pass
                Button(expanded ? "Less" : "More") {
                    BrandHaptics.fire(.light)
                    withAnimation(reduceMotion ? nil : BrandMotion.flow) { expanded.toggle() }
                }
                .font(BrandTypography.chip)
                .foregroundStyle(BrandColor.cyan)
                .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
            }
        }
    }
}

/// Killer features: staggered bulleted list with an accent marker.
struct KillerFeaturesList: View {
    let features: [String]
    let accent: Color
    let appeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            ForEach(Array(features.enumerated()), id: \.element) { index, feature in
                HStack(alignment: .top, spacing: BrandSpacing.s.value) {
                    Text("▸").foregroundStyle(accent)
                    Text(feature)
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(x: reduceMotion ? 0 : (appeared ? 0 : -6))
                .animation(
                    reduceMotion ? nil
                        : BrandMotion.flow.delay(0.06 + Double(min(index, 6)) * 0.03),
                    value: appeared
                )
            }
        }
    }
}

/// Strengths / Watch-outs as a two-column block.
struct StrengthsWatchouts: View {
    let advantages: [String]
    let weaknesses: [String]

    var body: some View {
        HStack(alignment: .top, spacing: BrandSpacing.l.value) {
            if !advantages.isEmpty {
                DetailSection(title: "Strengths") {
                    bulletColumn(advantages, marker: "+", color: BrandColor.lime)
                }
            }
            if !weaknesses.isEmpty {
                DetailSection(title: "Watch-outs") {
                    bulletColumn(weaknesses, marker: "–", color: BrandColor.amber)
                }
            }
        }
    }

    private func bulletColumn(_ items: [String], marker: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text(marker).foregroundStyle(color)
                    Text(item)
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Pricing card: model eyebrow + summary, on a faint glass plate.
struct PricingCard: View {
    let pricing: ToolPricing

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
            Text(pricing.model.rawValue.uppercased())
                .font(BrandTypography.eyebrow)
                .foregroundStyle(BrandColor.textMuted)
            Text(pricing.summary)
                .font(BrandTypography.body)
                .foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BrandSpacing.m.value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
    }
}
```

5. **Run** (expect pass).

6. **Commit:** `feat(ios): add rich detail sections + pure resolvers (P5)`

---

## Task 3 — Rewrite `ToolDetailSection` as the rich brand window

Wire Tasks 1–2 into the live view. Keep the hero, the existing visible-tool rail
(it is the section's tool switcher — out of scope to remove), the connections row
(now using `ToolDetailModel.connections`), and the Open button. Insert the
knowledge sections between hero and rail. Drive a one-shot `appeared` flag for the
killer-features stagger, reset on tool change.

**Files**
- Modify: `ios-app/Sources/MyAIMap/UI/Sheets/ToolDetailSection.swift`
- Create: `ios-app/Tests/MyAIMapTests/ToolDetailKnowledgeGatingTests.swift`

### Steps

1. **Write failing test** `ios-app/Tests/MyAIMapTests/ToolDetailKnowledgeGatingTests.swift`
   — assert the gating rules the view relies on (no SwiftUI rendering, just the
   logic that decides which sections show). Add the gating helper to
   `ToolDetailModel` so it is testable:

```swift
import Testing
@testable import MyAIMap

@Suite("ToolDetail — section gating")
struct ToolDetailKnowledgeGatingTests {

    private func k(
        enriched: Bool, killer: [String] = [], adv: [String] = [],
        weak: [String] = [], who: String = "", model: PricingModel = .unknown
    ) -> ToolKnowledge {
        ToolKnowledge(
            killerFeatures: killer, whatFor: "x", advantages: adv, weaknesses: weak,
            whoUses: who, pricing: .init(model: model, summary: "s"), enriched: enriched
        )
    }

    @Test func interimHidesEverythingButWhatItDoes() {
        let g = ToolDetailModel.gating(for: k(enriched: false))
        #expect(g.showsKillerFeatures == false)
        #expect(g.showsStrengthsWatchouts == false)
        #expect(g.showsWhoUses == false)
        #expect(g.showsPricing == false)
    }

    @Test func enrichedShowsSectionsWithContent() {
        let g = ToolDetailModel.gating(for: k(
            enriched: true, killer: ["f"], adv: ["+"], who: "devs", model: .freemium
        ))
        #expect(g.showsKillerFeatures)
        #expect(g.showsStrengthsWatchouts)   // advantages non-empty
        #expect(g.showsWhoUses)
        #expect(g.showsPricing)              // model != .unknown
    }

    @Test func pricingHiddenWhenModelUnknownEvenIfEnriched() {
        let g = ToolDetailModel.gating(for: k(enriched: true, killer: ["f"], model: .unknown))
        #expect(g.showsPricing == false)
    }
}
```

2. **Run** (expect compile failure — `gating` missing).

3. **Minimal impl** — add to `ToolDetailModel.swift` (Task 2 file):

```swift
extension ToolDetailModel {
    /// Which knowledge sections render, mirroring the `k?.enriched && …`
    /// guards in ToolDetail.tsx.
    struct Gating {
        let showsKillerFeatures: Bool
        let showsStrengthsWatchouts: Bool
        let showsWhoUses: Bool
        let showsPricing: Bool
    }

    static func gating(for k: ToolKnowledge) -> Gating {
        Gating(
            showsKillerFeatures: k.enriched && !k.killerFeatures.isEmpty,
            showsStrengthsWatchouts: k.enriched && (!k.advantages.isEmpty || !k.weaknesses.isEmpty),
            showsWhoUses: k.enriched && !k.whoUses.isEmpty,
            showsPricing: k.enriched && k.pricing.model != .unknown
        )
    }
}
```

4. **Run** (expect pass).

5. **Rewrite the view body** in `ToolDetailSection.swift`. Add the knowledge
   plumbing and an `appeared` flag; keep the existing rail, connections, Open
   button. Replace the existing computed `relatedTools` with the pure resolver,
   and insert the knowledge block after the hero/divider:

   Add state + derived knowledge near the top of the struct:

```swift
    @State private var browserSheet: BrowserSheetItem?
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var knowledge: ToolKnowledge {
        ToolKnowledge.best(for: selectedTool)
    }

    private var connections: [Tool] {
        ToolDetailModel.connections(for: selectedTool, in: UniverseSeed.tools)
    }

    private var gating: ToolDetailModel.Gating {
        ToolDetailModel.gating(for: knowledge)
    }
```

   Replace the body's middle (between the hero `Divider()` and the visible-tool
   `ScrollView`) with the knowledge block:

```swift
            // ── Knowledge sections (parity with web ToolDetail.tsx) ──
            DetailSection(title: "What it does") {
                ClampText(text: knowledge.whatFor.isEmpty ? selectedTool.summary : knowledge.whatFor)
            }

            if gating.showsKillerFeatures {
                DetailSection(title: "Killer features") {
                    KillerFeaturesList(
                        features: knowledge.killerFeatures,
                        accent: selectedCategoryModel.color.swiftUIColor,
                        appeared: appeared
                    )
                }
            }

            if gating.showsStrengthsWatchouts {
                StrengthsWatchouts(
                    advantages: knowledge.advantages,
                    weaknesses: knowledge.weaknesses
                )
            }

            if gating.showsWhoUses {
                DetailSection(title: "Who uses it") {
                    Text(knowledge.whoUses)
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if gating.showsPricing {
                DetailSection(title: "Pricing") { PricingCard(pricing: knowledge.pricing) }
            }
```

   Update the connections block to use `connections` and the eyebrow count, and
   to re-focus via `focusRelated` (unchanged). Change its header to:

```swift
            if !connections.isEmpty {
                DetailSection(title: "Connected to · \(connections.count)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: BrandSpacing.s.value) {
                            ForEach(connections) { related in
                                Button { focusRelated(related.id) } label: {
                                    HStack(spacing: 7) {
                                        Circle()
                                            .fill(UniverseSeed.category(related.category).color.swiftUIColor)
                                            .frame(width: 7, height: 7)
                                        Text(related.name)
                                            .font(BrandTypography.chip)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .liquidGlass(in: Capsule())
                                }
                                .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
                            }
                        }
                    }
                }
            }
```

   Replace the Open button's `if let url = selectedTool.url` with the derived-URL
   fallback so url-less seed tools still open:

```swift
            if let openURL = ToolDetailModel.derivedURL(for: selectedTool),
               let item = BrowserSheetItem(url: openURL) {
                Button {
                    BrandHaptics.fire(.light)
                    browserSheet = item
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square").font(.caption.weight(.semibold))
                        Text("Open \(selectedTool.name)").font(.caption.weight(.semibold)).lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .liquidGlass(in: Capsule(), tint: selectedCategoryModel.color.swiftUIColor)
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
            }
```

   Drive the stagger flag — add to the existing `.brandAnimation` chain at the
   end of `body`:

```swift
        .onAppear {
            BrandHaptics.prepare(.light)
            withAnimation(reduceMotion ? nil : BrandMotion.entry) { appeared = true }
        }
        .onChange(of: model.selection.selectedToolID) { _, _ in
            appeared = false
            withAnimation(reduceMotion ? nil : BrandMotion.entry) { appeared = true }
        }
```

6. **Run** the full suite + build: `npm run ios:verify -- --full-test --device-id <id>`
   (expect all green; existing `ChromeSnapshotTests`/layout tests must still pass —
   if a snapshot baseline shifts, re-record per `docs/ios/RUNBOOK.md`).

7. **Commit:** `feat(ios): rich tool detail brand window — features, pricing, connections (P5)`

---

## Task 4 — Manual verification pass

No code; confirm the experience on a booted simulator. Capture a screenshot for
the PR per `docs/AGENT_STATUS.md`.

**Files** — none.

### Steps

1. Boot a sim and run the app:
   `npm run ios:verify -- --full-test --device-id <id>` then launch via Xcode or
   `xcrun simctl launch <id> com.iliaturilia.MyAIMap`.
2. Verify by observation:
   - Open detail for an **enriched** tool (e.g. `codex`): What it does (with More),
     Killer features (staggered in), Strengths/Watch-outs, Who uses it, Pricing
     card, Connected-to chips, and `Open <name>`.
   - Open detail for an **un-enriched** tool: only What it does + connections +
     Open; no empty pricing/feature stubs.
   - Tap a connection chip → re-focuses that tool, haptic fires, sections refresh.
   - Tap Open → `SFSafariViewController` presents; close returns to the sheet.
   - Swipe the sheet down → dismisses (native detents). 
   - Enable **Reduce Motion** (Settings ▸ Accessibility) → no offset/stagger; only
     opacity/content transitions; presses still scale via system, haptics fire.
3. Confirm 60fps scroll on the detail (Instruments or visual) — no jank from the
   glass plates; the panel uses no full-screen effects.
4. **Commit (docs/screenshot only, if any):**
   `docs(ios): P5 rich detail verification notes`

---

## Done criteria

- All four new test files pass under `swift-testing`; existing suites stay green.
- `ToolDetailSection` renders every web-parity section, gated by `enriched` and
  content presence, from the `ToolKnowledge` layer.
- Connection chips re-focus tools; Open uses derived-URL fallback into
  `InAppBrowserSheet`; swipe-dismiss intact; Reduce Motion honoured; haptics on
  every interaction.
