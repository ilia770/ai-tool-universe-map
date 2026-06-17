# Chat auto-scroll to newest turn

**Phase:** A · **Lens:** app-quality

## Goal (1-2 lines)
On send/answer, the ChatDock thread reliably pins to the newest turn's bottom — like Messages — including the very first ask from an empty thread.

## Repro / symptom (grounded in real code)
- `ChatDock.swift:55-83` wires a `ScrollViewReader` + `.onChange(of: thread.turns.map(\.id))` → `scroller.scrollTo(last, anchor: .bottom)`. But `threadScroll` only mounts when `showThread == !collapsed && !thread.turns.isEmpty` (`:31, 37`). On the **first** ask, `thread.turns` goes 0→1 in the same render pass the `ScrollView` is inserted, so SwiftUI does not deliver `onChange` for the just-mounted reader → first turn never scrolls (QA #1).
- A turn row (`turnRow`, `:85-108`) grows **after** layout: the answer `Text` + N `matchCard`s inflate height after `scrollTo` resolves, so even later asks anchor to a stale height and the newest content sits below the fold (HIG §7.1).
- `.onChange` keys on `turns.map(\.id)` only — it does not re-fire when a row's content height settles.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- Modify `UI/Chat/ChatDock.swift` (`threadScroll`, add a bottom anchor + post-layout scroll).

## Approach (bullet steps)
- Append a zero-height bottom anchor view `Color.clear.frame(height: 1).id(Self.bottomAnchorID)` after the `ForEach` (`:62-65`); scroll to that id, not `turn.id`, so anchoring works even when the last row is taller than the viewport.
- Add a reusable `scrollToBottom(_ scroller:)` that hops post-layout: `Task { @MainActor in withAnimation(BrandMotion.resolved(BrandMotion.flow, reduceMotion: reduceMotion)) { scroller.scrollTo(bottomAnchorID, anchor: .bottom) } }`.
- Trigger it from BOTH `.onChange(of: thread.turns.map(\.id))` AND `.onAppear` of the `ScrollView` (covers the first-ask mount race), plus `.onChange(of: thread.turns.last?.answer)` so a growing answer re-pins.
- Keep the existing single non-destructive collapse behavior untouched.

## Interface / contract
```swift
extension ChatDock { static var bottomAnchorID: String { "chatdock.bottom" } }
```

## Tests (Tests/MyAIMapTests conventions)
- Pure-store coverage already in `ChatThreadStoreTests.swift` (append assigns ids, caps turns) — reuse for the data invariant the scroll depends on (`turns.last` is the newest).
- Add `ChatDockScrollTests` (ImageRenderer style like `SettingsSheetTests.swift`): assert `ChatDock` renders non-nil with a seeded multi-turn `ChatThreadStore(defaults: isolated, liveToolIds:)` and that `bottomAnchorID` is stable. (View scroll position itself is verified by simulator screenshot per design Testing section, not unit-asserted.)

## Done criteria (checklist)
- [ ] First ask from an empty thread scrolls newest into view.
- [ ] 5+ asks: newest turn fully visible, anchored bottom.
- [ ] Growing answer/match cards re-pin to bottom (no content below fold).
- [ ] Reduce Motion: jump is instant (no spring) via `BrandMotion.resolved`.
- [ ] No regression to swipe-down collapse.

## Dependencies (other tasks)
- A-composer-persistence (shares the `showThread`/mount-gating logic; coordinate edits to `threadScroll`).
