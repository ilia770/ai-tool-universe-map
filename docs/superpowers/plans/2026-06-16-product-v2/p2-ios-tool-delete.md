# P2 iOS Tool Delete Implementation Plan

> Part of the **2026-06-16 product-v2** set. iOS only.

## Goal

Let a user delete a tool/skill from the universe. The delete affordance lives in the
tool-detail sheet (`ToolDetailSection`) — surfaced via **long-press → context menu** on a
rail chip and a dedicated **Delete** action on the selected tool — guarded by a
**confirmation dialog**. On confirm: the view-model removes the tool, the selection moves to
a safe neighbour, the RealityKit scene removes the node + its label + its edge, a
`.heavy`/`.warning` haptic fires, and the removal is recorded for the history store
(coordinated with **P4**) via a lightweight sink the VM exposes.

## Architecture

Today the data layer is read-only: `UniverseSeed.tools` is a `static` immutable list and
`UniverseView` reads it **directly** in both the RealityView `make` and `update` closures
(it does *not* read through `UniverseViewModel`). There is no user-added/mutable-tool concept
on iOS yet. P2 introduces the **minimum** mutable layer needed to hide a tool:

- `UniverseViewModel` gains a `removedToolIDs: Set<String>` and an **effective tool list**
  (`tools`, `tools(in:)`) that filters the seed by that set. All existing derived state
  (`visibleTools`, `selectedTool`, `searchResults`) routes through this filtered list.
- `UniverseView` switches its three `UniverseSeed.tools…` read sites to the VM's filtered
  list, passed in as a plain `[Tool]` value (the scene stays persistent; deleted nodes are
  removed in the `update` closure by diffing entity names against the live id set).
- A `deletionSink: (ToolDeletion) -> Void` closure on the VM is the P4 seam. P2 ships it
  defaulting to a no-op; P4 wires it to the history store. No P4 type is referenced here.

Deletion is **soft** (id added to a set), which is the simplest correct approach: the seed is
shared/immutable, undo stays trivial, and re-adding the same id (future P1) just clears it.

## Tech Stack

SwiftUI + Observation (`@Observable`), RealityKit (`RealityView`), Swift Testing (`@Test`),
XcodeGen target `MyAIMap` / test target `MyAIMapTests`. Reuses `BrandHaptics.fire`,
`BrandMotion`, `PressableButtonStyle`, `liquidGlass`, `@Environment(\.accessibilityReduceMotion)`.

---

## Task 1 — Deletion model + VM mutable tool layer

**Files**
- Create: `ios-app/Sources/MyAIMap/State/ToolDeletion.swift`
- Modify: `ios-app/Sources/MyAIMap/State/UniverseViewModel.swift`
- Modify: `ios-app/Tests/MyAIMapTests/UniverseViewModelTests.swift`

### Steps

1. **Write failing tests** in `UniverseViewModelTests.swift`. Append to the existing suite:

```swift
    // MARK: - Delete (P2)

    @Test func deleteToolHidesItFromAllToolLists() {
        let model = UniverseViewModel()
        guard let victim = UniverseSeed.tools(in: .design).dropFirst().first else {
            Issue.record("seed needs >= 2 design tools")
            return
        }
        model.deleteTool(victim.id)
        #expect(model.tools.contains { $0.id == victim.id } == false)
        #expect(model.tools(in: .design).contains { $0.id == victim.id } == false)
        #expect(model.searchResults.contains { $0.id == victim.id } == false)
    }

    @Test func deletingSelectedToolMovesSelectionToNeighbour() {
        let model = UniverseViewModel()
        model.selectCategory(.design)
        let designTools = UniverseSeed.tools(in: .design)
        guard designTools.count >= 2 else {
            Issue.record("seed needs >= 2 design tools")
            return
        }
        model.selectTool(designTools[0].id)
        model.deleteTool(designTools[0].id)
        // Selection must still be valid and must not be the deleted id.
        #expect(model.selectedTool.id != designTools[0].id)
        #expect(model.tools.contains { $0.id == model.selectedTool.id })
    }

    @Test func deleteToolIsIgnoredForUnknownID() {
        let model = UniverseViewModel()
        let before = model.tools.count
        model.deleteTool("does-not-exist")
        #expect(model.tools.count == before)
    }

    @Test func deleteToolNotifiesDeletionSink() {
        let model = UniverseViewModel()
        var captured: [ToolDeletion] = []
        model.deletionSink = { captured.append($0) }
        guard let victim = UniverseSeed.tools(in: .media).first else {
            Issue.record("seed needs a media tool")
            return
        }
        model.deleteTool(victim.id)
        #expect(captured.count == 1)
        #expect(captured.first?.toolID == victim.id)
        #expect(captured.first?.toolName == victim.name)
        #expect(captured.first?.category == victim.category)
    }

    @Test func deleteFounderCoreIsRejected() {
        let model = UniverseViewModel()
        model.deleteTool("founder-os")
        #expect(model.tools.contains { $0.id == "founder-os" })
    }
```

2. **Run** — fails to compile (`deleteTool`, `tools`, `deletionSink`, `ToolDeletion` missing):
   `xcodebuild test -scheme MyAIMap -destination 'platform=iOS Simulator,name=iPhone 16'`

3. **Create** `ToolDeletion.swift` — the value the P4 history store will consume:

```swift
import Foundation

/// A record that a tool was removed from the universe. P2 emits this through
/// `UniverseViewModel.deletionSink`; P4's history store is the eventual consumer.
/// Kept deliberately self-contained (no P4 type) so the two parts merge cleanly.
struct ToolDeletion: Equatable, Sendable {
    let toolID: String
    let toolName: String
    let category: ToolCategoryId
    let date: Date

    init(tool: Tool, date: Date = Date()) {
        self.toolID = tool.id
        self.toolName = tool.name
        self.category = tool.category
        self.date = date
    }
}
```

4. **Modify** `UniverseViewModel.swift`. Add the mutable layer + intent. Insert after the
   `searchQuery` stored property:

```swift
    /// Ids the user has deleted. Soft-delete: the seed stays immutable and the
    /// effective `tools` list filters these out. Re-adding the same id (future
    /// add-tool flow) simply clears it from this set.
    private(set) var removedToolIDs: Set<String> = []

    /// P4 seam. Every confirmed deletion is handed to this sink so the history
    /// store can log it. Defaults to a no-op so P2 stands alone; P4 assigns it.
    var deletionSink: (ToolDeletion) -> Void = { _ in }
```

   Add the filtered list just below the `// MARK: - Derived state` line, and route the
   existing derived state through it:

```swift
    /// Seed minus anything the user deleted — the single list every other
    /// derived property and the renderer read from.
    var tools: [Tool] {
        UniverseSeed.tools.filter { !removedToolIDs.contains($0.id) }
    }

    func tools(in category: ToolCategoryId) -> [Tool] {
        tools.filter { $0.category == category }
    }
```

   Change `visibleTools`, `selectedTool`, and `searchResults` to read the filtered list:

```swift
    var visibleTools: [Tool] {
        let categoryTools = tools(in: selection.activeCategory)
        return categoryTools.isEmpty ? tools.filter { $0.category == .core } : categoryTools
    }

    var selectedTool: Tool {
        tools.first { $0.id == selection.selectedToolID }
            ?? visibleTools.first
            ?? UniverseSeed.tools[0]
    }

    var searchResults: [Tool] {
        SearchCore.results(for: searchQuery, in: tools) { UniverseSeed.category($0).shortName }
    }
```

   Add the intent in the `// MARK: - Intents` section:

```swift
    /// Removes a user tool. Rejects the founder core (the hero node is never
    /// deletable) and unknown ids. When the deleted tool is selected, selection
    /// falls back to its category neighbour, else the founder core. Emits a
    /// `ToolDeletion` to `deletionSink` for the history store (P4).
    func deleteTool(_ id: String) {
        guard id != "founder-os",
              let tool = UniverseSeed.tools.first(where: { $0.id == id }),
              !removedToolIDs.contains(id) else { return }

        let wasSelected = selection.selectedToolID == id
        removedToolIDs.insert(id)

        if wasSelected {
            let neighbour = tools(in: tool.category).first ?? tools.first { $0.id == "founder-os" }
            selection.selectedToolID = neighbour?.id ?? "founder-os"
            if neighbour == nil || neighbour?.id == "founder-os" {
                selection.activeCategory = .core
            }
        }

        deletionSink(ToolDeletion(tool: tool))
    }
```

5. **Run** — tests pass.

6. **Commit**: `feat(ios): mutable tool layer + deleteTool intent with P4 deletion sink`

---

## Task 2 — Scene removes deleted nodes (RealityKit)

**Files**
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseView.swift`
- Modify: `ios-app/Sources/MyAIMap/Universe/UniverseScreen.swift`
- Create: `ios-app/Tests/MyAIMapTests/ToolDeletionSceneTests.swift`

The scene is persistent and currently iterates `UniverseSeed.tools` directly. We pass the
VM's live id set into `UniverseView` and (a) skip building deleted nodes in `make`,
(b) prune their entities in `update`. The pruning logic is extracted to a pure, testable
helper so the test target never has to spin up a `RealityView`.

### Steps

1. **Write failing test** `ToolDeletionSceneTests.swift`:

```swift
import Testing
@testable import MyAIMap

@Suite("Tool deletion — scene node pruning")
@MainActor
struct ToolDeletionSceneTests {

    @Test func prunedNamesAreEntitiesWhoseToolIsNoLongerLive() {
        let liveIDs: Set<String> = ["founder-os", "figma"]
        let entityNames = [
            "tool:founder-os", "tool:figma", "tool:midjourney",
            "tool-label:midjourney", "link:design-midjourney",
            "link:core-design", "cat:design", "ring:design", "universe"
        ]
        let toPrune = UniverseView.entitiesToPrune(entityNames: entityNames, liveToolIDs: liveIDs)
        #expect(Set(toPrune) == ["tool:midjourney", "tool-label:midjourney", "link:design-midjourney"])
    }

    @Test func nothingPrunedWhenAllToolsLive() {
        let liveIDs: Set<String> = ["founder-os", "figma"]
        let names = ["tool:founder-os", "tool:figma", "cat:design", "link:core-design"]
        #expect(UniverseView.entitiesToPrune(entityNames: names, liveToolIDs: liveIDs).isEmpty)
    }
}
```

2. **Run** — fails (`entitiesToPrune` missing).

3. **Add** the pure helper to `UniverseView` (place it in the `// MARK: - Persistent-scene
   layout` section). It maps every per-tool entity name family back to a tool id and selects
   the ones whose tool is gone. The three name families a tool owns are `tool:<id>`,
   `tool-label:<id>`, and `link:<category>-<id>`:

```swift
    /// Names of entities that belong to a deleted tool, given the set of live
    /// tool ids. Pure (no RealityKit) so it is unit-testable. Covers the three
    /// per-tool entity families built in `make`: the orb (`tool:<id>`), its
    /// pocket label (`tool-label:<id>`), and its inbound edge
    /// (`link:<category>-<id>`). Founder/category/ring/skybox entities are never
    /// matched because their suffix is not a tool id.
    static func entitiesToPrune(entityNames: [String], liveToolIDs: Set<String>) -> [String] {
        entityNames.filter { name in
            if name.hasPrefix("tool:") {
                return !liveToolIDs.contains(String(name.dropFirst("tool:".count)))
            }
            if name.hasPrefix("tool-label:") {
                return !liveToolIDs.contains(String(name.dropFirst("tool-label:".count)))
            }
            if name.hasPrefix("link:") {
                // link:<categoryRaw>-<toolId>; the tool id is the part after the
                // last '-'. Core→category links (link:core-<cat>) never match a
                // tool id, so they are left intact.
                guard let dash = name.lastIndex(of: "-") else { return false }
                let suffix = String(name[name.index(after: dash)...])
                let liveAndIsToolLink = liveToolIDs.contains(suffix)
                let isAnyToolLink = UniverseSeed.tools.contains { $0.id == suffix }
                return isAnyToolLink && !liveAndIsToolLink
            }
            return false
        }
    }
```

4. **Run** — scene-pruning tests pass.

5. **Wire the live list into the scene.** In `UniverseView`, add a stored property and use it
   instead of the static seed at the three read sites. Add to the property block:

```swift
    /// Live tool list from the view-model (seed minus deletions). The scene is
    /// persistent, so deletions are applied by pruning entities in `update`.
    let tools: [Tool]
```

   In the `make` closure, replace the category-tool loop source
   `let categoryTools = UniverseSeed.tools(in: category.id)` with the filtered live list:

```swift
                let categoryTools = tools.filter { $0.category == category.id }
```

   In the `update` closure, after the `guard categoryChanged || toolChanged else { return }`
   guard is **removed for deletions** — deletions change neither category nor tool selection
   id necessarily, so add a deletion check. Replace that guard block with:

```swift
            let categoryChanged = state.activeCategory != selectedCategory
            let toolChanged = state.activeToolId != selectedToolId

            // Prune entities for tools deleted since the last update. Done before
            // the change guard so a delete that doesn't move selection still applies.
            let liveIDs = Set(tools.map(\.id))
            let prune = Self.entitiesToPrune(
                entityNames: universe.children.map(\.name),
                liveToolIDs: liveIDs
            )
            for name in prune {
                universe.findEntity(named: name)?.removeFromParent()
            }

            guard categoryChanged || toolChanged || !prune.isEmpty else { return }
```

   In `applyLayout`, change the per-category tool source the same way (it currently calls
   `UniverseSeed.tools(in: category.id)`); pass `tools` through. Update the `applyLayout`
   signature to accept `tools: [Tool]` and replace its loop source:

```swift
    private static func applyLayout(
        universe: Entity,
        tools: [Tool],
        selectedCategory: ToolCategoryId,
        selectedToolId: String,
        animated: Bool,
        reduceMotion: Bool
    ) {
```
```swift
            let categoryTools = tools.filter { $0.category == category.id }
```
   and update its call site in the `update` closure to pass `tools: tools`. Likewise update
   `refreshToolLabels` to take and iterate the live `tools` list rather than
   `UniverseSeed.tools(in:)`.

6. **Pass the VM list in** from `UniverseScreen.canvas`:

```swift
            UniverseView(
                tools: model.tools,
                selectedCategory: model.selection.activeCategory,
                selectedToolId: selectedTool.id,
                onToolSelect: { toolId in
                    focusToolFromMap(toolId)
                },
                onProximityEvent: { event in
                    switch event {
                    case .enter(let id):
                        selectCategory(id)
                    case .exit:
                        selectCategory(.core)
                    }
                }
            )
```

   Update the `#Preview` in `UniverseView.swift` to pass `tools: UniverseSeed.tools`.

7. **Run** full test suite + build — green.

8. **Commit**: `feat(ios): prune deleted tool nodes/labels/edges from persistent scene`

---

## Task 3 — Delete affordance + confirmation in the detail sheet

**Files**
- Modify: `ios-app/Sources/MyAIMap/UI/Sheets/ToolDetailSection.swift`
- Create: `ios-app/Tests/MyAIMapTests/ToolDeleteFlowTests.swift`

The affordance: every **rail chip** gets a `contextMenu` (long-press) with a destructive
**Delete** item, and the selected tool gets a visible destructive **Delete** capsule next to
**Open**. Both route through one private `requestDelete(_:)` that arms a
`confirmationDialog`. Confirm calls `model.deleteTool` inside `withAnimation` with a
`.warning` haptic; the founder core never shows the affordance.

### Steps

1. **Write failing test** `ToolDeleteFlowTests.swift` (drives the VM exactly as the confirm
   handler will, so the flow is verified without UI snapshotting):

```swift
import Testing
@testable import MyAIMap

@Suite("Tool delete flow — confirm wiring")
@MainActor
struct ToolDeleteFlowTests {

    @Test func confirmDeleteRemovesToolAndLogsIt() {
        let model = UniverseViewModel()
        var logged: [ToolDeletion] = []
        model.deletionSink = { logged.append($0) }
        model.selectCategory(.design)
        guard let victim = UniverseSeed.tools(in: .design).first else {
            Issue.record("seed needs a design tool")
            return
        }
        model.selectTool(victim.id)

        // Mirrors ToolDetailSection.performDelete.
        model.deleteTool(victim.id)

        #expect(model.tools.contains { $0.id == victim.id } == false)
        #expect(logged.first?.toolID == victim.id)
    }

    @Test func founderCoreIsNotDeletable() {
        let model = UniverseViewModel()
        // ToolDetailSection.canDelete mirror: founder-os is excluded.
        #expect(ToolDetailSection.canDelete(toolID: "founder-os") == false)
        #expect(ToolDetailSection.canDelete(toolID: "figma"))
    }
}
```

2. **Run** — fails (`ToolDetailSection.canDelete` missing).

3. **Modify** `ToolDetailSection.swift`. Add state + the deletion guard + handlers, and the
   UI affordances.

   Add stored state next to `browserSheet`:

```swift
    @State private var pendingDeleteID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

   Add the pure guard (static so the test can call it) and the handlers, after `focusRelated`:

```swift
    /// The founder core is the universe's hero and is never deletable; every
    /// other tool is. Pure so the flow test can assert it directly.
    static func canDelete(toolID: String) -> Bool { toolID != "founder-os" }

    private func requestDelete(_ id: String) {
        guard Self.canDelete(toolID: id) else { return }
        BrandHaptics.fire(.warning)
        pendingDeleteID = id
    }

    private func performDelete(_ id: String) {
        BrandHaptics.fire(.heavy)
        withAnimation(BrandMotion.flow) {
            model.deleteTool(id)
        }
    }

    private func toolName(_ id: String) -> String {
        UniverseSeed.tools.first { $0.id == id }?.name ?? "this tool"
    }
```

   Add a `.contextMenu` to the rail chip `Button` (long-press). Attach it to the existing
   chip button, after its `.buttonStyle(...)` line:

```swift
                        .contextMenu {
                            if Self.canDelete(toolID: tool.id) {
                                Button(role: .destructive) {
                                    requestDelete(tool.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
```

   Add a visible **Delete** capsule for the selected tool. Wrap the existing trailing
   `Open` button in an `HStack` so Delete sits beside it, and only show Delete when
   `canDelete`. Replace the `if let url = selectedTool.url { … }` block with:

```swift
            HStack(spacing: 8) {
                if let url = selectedTool.url {
                    Button {
                        BrandHaptics.fire(.light)
                        browserSheet = BrowserSheetItem(url: url)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption.weight(.semibold))
                            Text("Open")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .liquidGlass(in: Capsule(), tint: selectedCategoryModel.color.swiftUIColor)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
                }

                if Self.canDelete(toolID: selectedTool.id) {
                    Button {
                        requestDelete(selectedTool.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.caption.weight(.semibold))
                            Text("Delete")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .liquidGlass(in: Capsule(), tint: .red, strokeStrength: 0.12)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
                    .accessibilityLabel("Delete \(selectedTool.name)")
                }
            }
```

   Add the confirmation dialog as a modifier on the root `VStack` (next to the existing
   `.sheet(item:)`):

```swift
        .confirmationDialog(
            "Delete \(toolName(pendingDeleteID ?? ""))?",
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteID { performDelete(id) }
                pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text("This removes it from your universe. You can add it back later.")
        }
```

4. **Run** — `ToolDeleteFlowTests` pass; build the app target so the SwiftUI changes compile.

5. **Manual smoke (simulator):** long-press a rail chip → context menu shows Delete; tap →
   dialog; confirm → node and chip vanish with the `flow` animation, selection moves to a
   neighbour, heavy haptic fires. Verify Reduce Motion collapses the animation (BrandMotion
   already maps to a 1 ms linear curve) and the founder core shows no Delete control.

6. **Commit**: `feat(ios): delete affordance (context menu + capsule) with confirmation in tool detail`

---

## Verification checklist

- `xcodebuild test -scheme MyAIMap -destination 'platform=iOS Simulator,name=iPhone 16'`
  passes (new suites: VM delete, scene pruning, delete flow).
- Deleting the selected tool never leaves a dangling selection (`selectedTool` always live).
- Founder core is non-deletable from every surface (`deleteTool` guard + `canDelete`).
- Scene removes the orb, its pocket label, and its inbound edge — no orphan entities.
- `deletionSink` fires exactly once per confirmed delete with the right `toolID`/`name`/`category`.
- Haptics: `.warning` on arm, `.heavy` on confirm; Reduce Motion honoured via `BrandMotion`.

## P4 coordination note

P4 (history store) assigns `UniverseViewModel.deletionSink` where the VM is constructed
(`MyAIMapApp` / the screen's environment owner) to append each `ToolDeletion` to the history
store. P2 ships the sink as a no-op default and the `ToolDeletion` value type, so the two
parts merge without either blocking the other. Do **not** import a P4 type in P2 files.
