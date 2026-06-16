# P7 Apple Interactions Polish Implementation Plan

> Part of the **2026-06-16 product-v2** set. Cross-cutting (both lanes: web R3F playground + iOS SwiftUI/RealityKit).

## Goal

Make every P1–P6 surface feel like a first-party Apple app: **pure liquid glass** (no
`bg-black/*` tint glass on web, no double-blurred sheets on iOS), and the full interaction
kit on every tappable/draggable element — **tap**, **long-press peek**, **swipe to
dismiss/navigate**, **press feedback** (scale 0.96 + spring), **micro-animations** (stagger,
spring entrance/exit), **tactile clicks/haptics** (`navigator.vibrate` on web,
`UIImpactFeedbackGenerator`/`sensoryFeedback` on iOS), and a **reduce-motion fallback**
everywhere. P7 ships the shared tokens/utilities those surfaces import, an audit checklist
mapping each new surface to its required interactions, and lint-style tests that fail when a
surface drifts from the contract.

This part adds **no new product features**. It only (a) extends the shared token/util layer
where a gap exists, and (b) records a binding checklist so P1–P6 reviewers can verify
compliance. Where a surface already complies (e.g. `CategoryRail`, `SearchDock`), the
checklist marks it ✅ and nothing changes.

## Architecture

The two lanes already have parallel design-system layers; P7 treats them as the source of
truth and only fills gaps:

- **Web** — `src/playground/designSystem.ts` holds `GLASS`, `ACCENT`, `DURATION`, `STAGGER`,
  `EASE`, `DISMISS`, `LONG_PRESS_MS`, `LONG_PRESS_SLOP_PX`, `FOCUS_RING`, `HOVER_LIFT`.
  Three interaction helpers are currently **copy-pasted** into `FindBar.tsx`,
  `ToolDetail.tsx`, and `AddToolModal.tsx`: a `prefers-reduced-motion` hook, a `haptic()`
  wrapper around `navigator.vibrate`, and the long-press / drag-dismiss pointer math. P7
  extracts these into one importable module (`src/playground/interactions.ts`) so every
  P1–P6 web surface uses the same code path (DRY; matches the "never re-hand-code" rule in
  `designSystem.ts`).

- **iOS** — `UI/Theme/BrandMotion.swift` (curves + `resolved`/`brandAnimation` reduce-motion
  gate), `UI/Haptics/BrandHaptics.swift` (`fire`/`prepare`), `UI/Effects/PressBounce.swift`
  (`PressableButtonStyle`, `BouncyIconButtonStyle`), `UI/Effects/LiquidGlass.swift`
  (`.liquidGlass(...)`), plus `ScrollEffects`, `ParallaxTilt`, `ShimmerLoader`. The two
  missing primitives every P-plan sheet needs are a **long-press peek** modifier and a
  **swipe-to-dismiss** drag modifier honoring the same `DISMISS` numbers the web uses. P7
  adds both as `UI/Effects/PeekPreview.swift` and `UI/Effects/SwipeToDismiss.swift`, plus a
  single `InteractionTokens.swift` mirroring the web `DISMISS`/`LONG_PRESS_*` constants so
  both lanes share literal values.

The audit checklist lives in this file (Task 5) and is enforced by two cheap tests:
`interactions.test.ts` (web, asserts the shared module exports the contract) and
`InteractionTokensTests.swift` (iOS, asserts token parity + reduce-motion behavior).

## Tech Stack

- **Web**: React 18 + Vite + R3F, Vitest (`npm test` → `vitest run src`), Tailwind utility
  strings composed via `cx(...)`, pointer events, `navigator.vibrate`, `matchMedia`.
- **iOS**: SwiftUI + Observation, RealityKit, Swift Testing (`@Test`/`@Suite`), XcodeGen
  target `MyAIMap` / test target `MyAIMapTests`, `UIImpactFeedbackGenerator` +
  `.sensoryFeedback`, `@Environment(\.accessibilityReduceMotion)`.
- **Build/test commands** (canonical, same as P0/P2/P4):
  - Web: `npm test`
  - iOS: `xcodegen generate` then
    `xcodebuild test -scheme MyAIMap -destination 'platform=iOS Simulator,name=iPhone 16'`

---

## Task 1 — Web: extract the shared interaction module

Today `useReducedMotion`, `haptic()`, and the long-press/drag math are duplicated across
`FindBar.tsx:58`, `ToolDetail.tsx:30`, and `AddToolModal.tsx:45`. Extract one module so every
P1–P6 web surface imports identical behavior.

**Files**
- Create: `src/playground/interactions.ts`
- Create: `src/playground/interactions.test.ts`

### Steps

1. **Write failing test** `src/playground/interactions.test.ts`:

```ts
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { haptic, fireHaptic, prefersReducedMotion } from './interactions';
import { DISMISS } from './designSystem';

describe('interactions', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('haptic() calls navigator.vibrate with the default 8ms tick', () => {
    const vibrate = vi.fn();
    vi.stubGlobal('navigator', { vibrate });
    haptic();
    expect(vibrate).toHaveBeenCalledWith(8);
  });

  it('fireHaptic(ms) forwards a custom duration', () => {
    const vibrate = vi.fn();
    vi.stubGlobal('navigator', { vibrate });
    fireHaptic(20);
    expect(vibrate).toHaveBeenCalledWith(20);
  });

  it('haptic() is a no-op when navigator.vibrate is missing', () => {
    vi.stubGlobal('navigator', {});
    expect(() => haptic()).not.toThrow();
  });

  it('prefersReducedMotion reads the reduce media query', () => {
    vi.stubGlobal('window', {
      matchMedia: (q: string) => ({ matches: q.includes('reduce') }),
    });
    expect(prefersReducedMotion()).toBe(true);
  });

  it('drag-dismiss commits past distance OR a downward flick over velocity', () => {
    // committed by distance alone (slow drag, zero velocity)
    expect(shouldDismiss(DISMISS.distancePx + 1, 0)).toBe(true);
    // committed by velocity alone (short flick)
    expect(shouldDismiss(10, DISMISS.velocity + 0.1)).toBe(true);
    // neither → springs back
    expect(shouldDismiss(10, 0)).toBe(false);
  });
});

import { shouldDismiss } from './interactions';
```

2. **Run** `npm test` → fails (module missing).

3. **Implement** `src/playground/interactions.ts`, lifting the existing logic verbatim from
   `FindBar.tsx`/`AddToolModal.tsx` so behavior is unchanged:

```ts
/**
 * Shared interaction primitives for the playground shell. Previously these
 * were copy-pasted into FindBar/ToolDetail/AddToolModal; this is the single
 * source so every P1–P6 surface gets identical tap/peek/swipe/haptic/reduce-
 * motion behavior. Pair with the tokens in `designSystem.ts`.
 */
import { useEffect, useState } from 'react';
import { DISMISS, LONG_PRESS_MS, LONG_PRESS_SLOP_PX } from './designSystem';

/** True when the user asked for reduced motion (SSR-safe). */
export function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  );
}

/** Reactive reduce-motion hook — re-renders when the OS preference flips. */
export function useReducedMotion(): boolean {
  const [reduced, setReduced] = useState(prefersReducedMotion);
  useEffect(() => {
    if (typeof window === 'undefined') return;
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const onChange = () => setReduced(mq.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);
  return reduced;
}

/** Fire a tactile tick. Default 8ms = the standard "tap landed" cue. */
export function fireHaptic(ms = 8): void {
  if (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function') {
    navigator.vibrate(ms);
  }
}

/** Convenience alias for the default tick (matches existing call sites). */
export function haptic(): void {
  fireHaptic(8);
}

/** Unified dismiss contract: past distance OR a downward flick over velocity. */
export function shouldDismiss(dy: number, velocity: number): boolean {
  return dy > DISMISS.distancePx || velocity > DISMISS.velocity;
}

/** Rubber-band an over-drag past the dismiss axis (follow 1:1 downward). */
export function rubberBand(dy: number): number {
  return dy > 0 ? dy : dy * DISMISS.resistance;
}

export { LONG_PRESS_MS, LONG_PRESS_SLOP_PX };
```

4. **Run** `npm test` → passes.

5. **Commit**: `feat(web): extract shared playground interaction module`.

---

## Task 2 — Web: migrate existing surfaces onto the shared module

Remove the three duplicated helpers from `FindBar.tsx`, `ToolDetail.tsx`, `AddToolModal.tsx`
and import from `interactions.ts`. This is a surgical refactor — behavior must not change.

**Files**
- Modify: `src/playground/FindBar.tsx`
- Modify: `src/playground/ToolDetail.tsx`
- Modify: `src/playground/AddToolModal.tsx`

### Steps

1. **Run** `npm test` first → record the green baseline (existing `query.test.ts` +
   `interactions.test.ts`).

2. In each file, delete the local `reduced`/`useReducedMotion`, the local `haptic`/`vibrate`
   helper, and the inline `shouldDismiss`/rubber-band math, replacing them with:

```ts
import { useReducedMotion, haptic, fireHaptic, shouldDismiss, rubberBand } from './interactions';
```

   Example — `AddToolModal.tsx` currently has (around line 45–50):

```ts
function prefersReducedMotion() {
  return typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}
function haptic() {
  if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(8);
}
```

   Delete both and import `haptic` + `useReducedMotion` from `./interactions`. Replace the
   inline commit check in `onHandlePointerUp` (around line 353):

```ts
if (dy > DISMISS.distancePx || velocity > DISMISS.velocity) {
```

   with:

```ts
if (shouldDismiss(dy, velocity)) {
```

   and the follow/rubber-band line (`setDrag(dy > 0 ? dy : dy * DISMISS.resistance)`,
   line 341) with `setDrag(rubberBand(dy))`.

3. Repeat for `ToolDetail.tsx` (drag math at lines 271–313) and `FindBar.tsx`
   (reduce-motion hook lines 64–77, `vibrate` lines 58–59, long-press lines 295–305 use the
   re-exported `LONG_PRESS_MS`/`LONG_PRESS_SLOP_PX` from `interactions.ts`).

4. **Run** `npm test` → still green (no behavior change). Grep to confirm the orphans are
   gone: `grep -rn "navigator.vibrate\|prefers-reduced-motion" src/playground/*.tsx` returns
   nothing.

5. **Commit**: `refactor(web): route playground surfaces through shared interactions`.

---

## Task 3 — iOS: interaction tokens parity + long-press peek modifier

iOS lacks a single home for the `DISMISS`/`LONG_PRESS_*` literals (currently they live only
on web) and has no reusable long-press peek. Add both. The peek mirrors the web
`FindBar` quick-peek (`peekId` + `findbar-peek` animation, `DURATION.peek = 400`).

**Files**
- Create: `ios-app/Sources/MyAIMap/UI/Theme/InteractionTokens.swift`
- Create: `ios-app/Sources/MyAIMap/UI/Effects/PeekPreview.swift`
- Create: `ios-app/Tests/MyAIMapTests/InteractionTokensTests.swift`
- Modify: `ios-app/project.yml` is **not** touched (sources are globbed from `Sources/MyAIMap`).

### Steps

1. **Write failing tests** `ios-app/Tests/MyAIMapTests/InteractionTokensTests.swift`:

```swift
import Testing
import SwiftUI
@testable import MyAIMap

@Suite("Interaction tokens")
struct InteractionTokensTests {

    @Test func tokensMatchWebContract() {
        // Literal parity with src/playground/designSystem.ts so both lanes
        // dismiss/peek at the same thresholds.
        #expect(InteractionTokens.longPressSeconds == 0.42)
        #expect(InteractionTokens.dismissDistance == 100)
        #expect(InteractionTokens.dismissVelocity == 0.5)
        #expect(InteractionTokens.dismissResistance == 0.25)
        #expect(InteractionTokens.peekSeconds == 0.40)
    }

    @Test func dismissCommitsPastDistanceOrFlick() {
        #expect(InteractionTokens.shouldDismiss(translation: 101, velocity: 0))
        #expect(InteractionTokens.shouldDismiss(translation: 10, velocity: 0.6))
        #expect(!InteractionTokens.shouldDismiss(translation: 10, velocity: 0))
    }

    @Test func rubberBandFollowsDownOnlyAndResistsUp() {
        #expect(InteractionTokens.rubberBand(50) == 50)            // down: 1:1
        #expect(InteractionTokens.rubberBand(-100) == -25)         // up: resisted
    }
}
```

2. **Run** `xcodegen generate && xcodebuild test -scheme MyAIMap -destination 'platform=iOS Simulator,name=iPhone 16'`
   → fails (type missing).

3. **Implement** `ios-app/Sources/MyAIMap/UI/Theme/InteractionTokens.swift`:

```swift
import CoreGraphics

/// Cross-lane interaction constants. Literal mirror of the web build's
/// `DISMISS`, `LONG_PRESS_MS`, and `DURATION.peek` (src/playground/
/// designSystem.ts) so an iOS sheet and a web sheet dismiss and peek at
/// exactly the same thresholds. Keep these two files in lockstep.
enum InteractionTokens {
    /// Long-press threshold. Web: LONG_PRESS_MS = 420.
    static let longPressSeconds: Double = 0.42
    /// Peek present duration. Web: DURATION.peek = 400.
    static let peekSeconds: Double = 0.40
    /// Downward drag (pt) that commits a dismiss. Web: DISMISS.distancePx.
    static let dismissDistance: CGFloat = 100
    /// Release velocity (pt/ms) that commits a short flick. Web: DISMISS.velocity.
    static let dismissVelocity: CGFloat = 0.5
    /// Over-drag resistance past the axis. Web: DISMISS.resistance.
    static let dismissResistance: CGFloat = 0.25

    /// Unified dismiss contract: past distance OR a downward flick.
    static func shouldDismiss(translation: CGFloat, velocity: CGFloat) -> Bool {
        translation > dismissDistance || velocity > dismissVelocity
    }

    /// Follow downward 1:1; rubber-band any upward over-drag.
    static func rubberBand(_ dy: CGFloat) -> CGFloat {
        dy > 0 ? dy : dy * dismissResistance
    }
}
```

4. **Implement** `ios-app/Sources/MyAIMap/UI/Effects/PeekPreview.swift` — a long-press peek
   that fires a `.medium` haptic on commit, scales/blur-springs in via `BrandMotion`, and
   collapses to no animation under reduce-motion:

```swift
import SwiftUI

/// Long-press "quick peek" — the iOS twin of the web FindBar peek bubble.
/// Hold a chip past `InteractionTokens.longPressSeconds` to reveal a glass
/// preview card; release (or tap elsewhere) to dismiss. Fires `.medium`
/// on present. Honors reduce motion by skipping the scale/blur spring.
///
/// Usage:
///
/// ```swift
/// ChipView(tool)
///   .peekPreview { PeekCard(tool: tool) }
/// ```
extension View {
    func peekPreview<Peek: View>(@ViewBuilder _ content: @escaping () -> Peek) -> some View {
        modifier(PeekPreviewModifier(peek: content))
    }
}

private struct PeekPreviewModifier<Peek: View>: ViewModifier {
    @ViewBuilder let peek: () -> Peek
    @State private var showing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(
                minimumDuration: InteractionTokens.longPressSeconds,
                maximumDistance: 10
            ) {
                BrandHaptics.fire(.medium)
                showing = true
            }
            .overlay(alignment: .top) {
                if showing {
                    peek()
                        .padding(12)
                        .liquidGlass(in: RoundedRectangle(cornerRadius: BrandRadius.card.value))
                        .scaleEffect(reduceMotion ? 1 : 0.98)
                        .opacity(showing ? 1 : 0)
                        .offset(y: -64)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
                        .onTapGesture { showing = false }
                        .accessibilityAddTraits(.isModal)
                }
            }
            .brandAnimation(BrandMotion.entry, value: showing)
    }
}
```

5. **Run** the iOS test command → passes.

6. **Commit**: `feat(ios): interaction tokens parity + long-press peek modifier`.

---

## Task 4 — iOS: swipe-to-dismiss modifier

Sheets on iOS use the native drag indicator + detents (`RootSheet`), but the P3 chat sheet
and P5 rich-detail card need an explicit downward swipe-to-dismiss honoring the shared
`DISMISS` numbers (so an over-pull rubber-bands and a flick commits like on web). Add a
reusable modifier; do not retrofit `RootSheet` (its detent behavior is intentional).

**Files**
- Create: `ios-app/Sources/MyAIMap/UI/Effects/SwipeToDismiss.swift`
- Modify: `ios-app/Tests/MyAIMapTests/InteractionTokensTests.swift`

### Steps

1. **Append failing test** to `InteractionTokensTests.swift`:

```swift
    @Test func swipeProgressIsClampedAndUsesRubberBand() {
        // Downward drag follows 1:1.
        #expect(SwipeDismissModel.offset(for: 80) == 80)
        // Upward drag is resisted (rubber-banded), never positive past 0.
        #expect(SwipeDismissModel.offset(for: -40) == -10)
    }

    @Test func swipeCommitMatchesContract() {
        #expect(SwipeDismissModel.commits(translation: 120, velocity: 0))
        #expect(SwipeDismissModel.commits(translation: 5, velocity: 0.7))
        #expect(!SwipeDismissModel.commits(translation: 5, velocity: 0.1))
    }
```

2. **Run** iOS test command → fails.

3. **Implement** `ios-app/Sources/MyAIMap/UI/Effects/SwipeToDismiss.swift`. The pure model is
   split out so it is unit-testable without a running view (same pattern as `SearchCore`):

```swift
import SwiftUI

/// Pure, testable swipe math — mirrors the web drag-dismiss contract.
enum SwipeDismissModel {
    static func offset(for translation: CGFloat) -> CGFloat {
        InteractionTokens.rubberBand(translation)
    }
    static func commits(translation: CGFloat, velocity: CGFloat) -> Bool {
        // velocity arrives as pt/s from SwiftUI; convert to pt/ms.
        InteractionTokens.shouldDismiss(translation: translation, velocity: velocity)
    }
}

/// Downward swipe-to-dismiss for a presented card/sheet. Follows the finger
/// 1:1 down, rubber-bands an upward over-drag, and commits `onDismiss` past
/// the shared distance OR on a downward flick. Fires `.light` on commit.
/// Under reduce motion the spring-back is instantaneous.
///
/// Usage:
///
/// ```swift
/// ChatCard()
///   .swipeToDismiss { store.closeChat() }
/// ```
extension View {
    func swipeToDismiss(onDismiss: @escaping () -> Void) -> some View {
        modifier(SwipeToDismissModifier(onDismiss: onDismiss))
    }
}

private struct SwipeToDismissModifier: ViewModifier {
    let onDismiss: () -> Void
    @State private var translation: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: SwipeDismissModel.offset(for: translation))
            .gesture(
                DragGesture()
                    .onChanged { translation = $0.translation.height }
                    .onEnded { value in
                        let vPerMs = value.predictedEndTranslation.height / 1000
                        if SwipeDismissModel.commits(translation: value.translation.height, velocity: vPerMs) {
                            BrandHaptics.fire(.light)
                            onDismiss()
                        }
                        withAnimation(BrandMotion.resolved(BrandMotion.nudge, reduceMotion: reduceMotion)) {
                            translation = 0
                        }
                    }
            )
    }
}
```

4. **Run** iOS test command → passes.

5. **Commit**: `feat(ios): swipe-to-dismiss modifier honoring shared dismiss contract`.

---

## Task 5 — The P1–P6 interaction audit checklist

This is the binding deliverable: every new surface from P1–P6 maps to its required
interactions and the **exact** shared token/util to use. Reviewers paste the relevant rows
into each PR. The legend: ✅ already complies, ⬜ to wire when that part lands.

**Files**
- Modify: this file only (the checklist below is the artifact).

### Shared utilities to reach for (never re-hand-code)

| Interaction | Web util/token | iOS util/token |
| --- | --- | --- |
| Glass surface | `GLASS.panel`/`.floating`/`.bar`/`.chip` (`designSystem.ts`) | `.liquidGlass(in:tint:strokeStrength:)` (`LiquidGlass.swift`) |
| Press feedback (0.96 + spring) | `active:scale-[0.96]` + `transition DURATION.press`/`EASE.out` | `PressableButtonStyle()` / `BouncyIconButtonStyle()` (`PressBounce.swift`) |
| Tap haptic | `haptic()` / `fireHaptic(ms)` (`interactions.ts`) | `BrandHaptics.fire(.light)` (`BrandHaptics.swift`) |
| Long-press peek | `peekId` state + `LONG_PRESS_MS`/`_SLOP_PX`, `DURATION.peek` | `.peekPreview { … }` (`PeekPreview.swift`) |
| Swipe dismiss | `shouldDismiss`/`rubberBand` + `DISMISS` (`interactions.ts`) | `.swipeToDismiss { … }` (`SwipeToDismiss.swift`) |
| Spring entrance/exit | `EASE.out`/`EASE.sheet` + `DURATION.turn`/`.sheet`/`.exit` | `BrandMotion.entry`/`.nudge`/`.flow` via `.brandAnimation(_:value:)` |
| Stagger reveal | `STAGGER.chip`/`.section`, `animationDelay` | `.scrollDepth()`/`.scrollLift()` (`ScrollEffects.swift`) + per-index delay |
| Focus ring (web a11y) | `FOCUS_RING` | n/a (system focus) |
| Reduce motion | `useReducedMotion()` (`interactions.ts`) | `@Environment(\.accessibilityReduceMotion)` + `BrandMotion.resolved` |

### Per-surface checklist

> **Audit status (2026-06-16, final P7 pass).** All P1–P9 lanes are merged on
> `feat/product-v2`; this pass audited every new surface against the live code
> and fixed the drifts called out below. `✅` = verified compliant in code (with
> file:line); `✅(fixed)` = was drifting, corrected in this pass.

#### P1 — iOS Top Bar / chrome (`UniverseScreen.swift`, `AccountButton`)
- ✅ Glass: `AccountButton` uses `.liquidGlass(in: Circle())` (UniverseScreen.swift:217); category pill/header tiles use `.liquidGlass` (147,160) — no opaque fill.
- ✅ Bar button: `AccountButton` uses `BouncyIconButtonStyle()` (UniverseScreen.swift:223) → `.light` haptic auto-fires.
- ✅ Reduce motion: press scale gated inside `BouncyIconButtonStyle`/`PressableButtonStyle`; no ambient loops added.
- ✅ Entrance: panel/chrome fades in with `.brandAnimation(BrandMotion.entry, value:)` (UniverseScreen.swift:134) and `BrandMotion.flow` (167).

#### P2 — iOS Tool Delete (`ToolDetailSection.swift`, rail `contextMenu`)
- ✅ Long-press → `contextMenu` (the destructive menu stays a menu, not a peek; matches the P2 note). `HistoryStrip` rows also use `contextMenu` (HistoryStrip.swift:76).
- ✅ Confirm button: `PressableButtonStyle(pressedScale: 0.95, …)` (ToolDetailSection.swift:255,273); `.heavy` on confirm (372), `.warning` on guarded dialog (365).

#### P3 — iOS Chat (`ChatDock.swift`)
- ✅ Chat card present: `BrandMotion.entry` spring (ChatDock.swift:48); **swipe-down** dismiss (non-destructive collapse) now commits via the shared `SwipeDismissModel.commits(...)` contract — **✅(fixed)** replaced the hardcoded `> 80` threshold (ChatDock.swift:253) with distance/flick parity.
- ✅(fixed) Send: `.light` on tap (216) + `.success` on turn completion (added at submit) — was missing the success tick.
- ✅ Turn-in: `.brandAnimation(BrandMotion.nudge, value: thread.turns.map(\.id))` (49) gates the insert under reduce motion.
- ✅ Glass: composer `.liquidGlass(in: Capsule(), …)` (93), bubbles `.liquidGlass(…)` (70,141) — no opaque-only fill.
- ✅(fixed) `BrandHaptics.prepare(.light, .medium, .success)` in `onAppear` (50) — added `.success`.

#### P4 — iOS History (`HistoryStrip.swift`)
- ✅ Row tap: `PressableButtonStyle()` (HistoryStrip.swift:74), `.light`/`.medium` haptic (103,106), animates via `BrandMotion.flow`.
- ✅ Row reveal: chip row animates via `.brandAnimation(BrandMotion.flow, value: chips.map(\.id))` (51), reduce-motion gated; chips are capped upstream at 6 (`HistoryStripModel`).
- ✅ Long-press a row → `contextMenu` Open/Restore/Remove (76). Native context-menu preview supersedes a separate `.peekPreview` (would conflict on the same long-press); `.peekPreview` ships for surfaces that want a *preview* without a menu.
- ✅ Empty state: shimmer handled by `ShimmerModifier` (reduce-motion gated upstream).

#### P5 — iOS Rich Tool Detail (`ToolDetailSection.swift` in `RootSheet`)
- ✅ Present + dismiss: hosted in `RootSheet` with native drag-indicator + detents (intentional — not retrofitted); settle via `.brandAnimation(BrandMotion.flow, …)` (298) and `BrandMotion.nudge` (299).
- ✅ Section reveal: rich detail sections animate via `.brandAnimation` (reduce-motion gated); "Connected because" caption uses `.move/.opacity` transition gated on `reduceMotion` (231).
- ✅ Pills/links: `PressableButtonStyle(pressedScale: 0.95, haptic: nil)` (162,209,255,273) + explicit `BrandHaptics.fire(.light)` in actions (240,327,330).
- ✅(fixed) Inferred-edge "Connected because" long-press now uses `InteractionTokens.longPressSeconds` (was a hardcoded `0.3`) — ToolDetailSection.swift:214, for cross-lane parity.
- ✅ Glass everywhere: `.liquidGlass`; `RootSheet` is single-material `.ultraThinMaterial` (RootSheet.swift:24) — no clear sheet wrapping a glass card.

#### P6 — web shell (`SettingsPanel`, `PlaygroundApp`, `FindBar`, `ToolDetail`, `AddToolModal`)
- ✅ Sheets/modals: `SettingsPanel`/`AddToolModal`/`ToolDetail` compose `GLASS.panel`, present with `DURATION.sheet`/`EASE.sheet`, dismiss with `DURATION.exit`; drag-dismiss routed through shared `shouldDismiss`/`rubberBand`.
- ✅ Chips/lists: `active:scale-[0.96/0.97]`, `FOCUS_RING`, `HOVER_LIFT`, `haptic()`/`fireHaptic()` on `onPointerDown`, stagger via `STAGGER.*` + `animationDelay`.
- ✅ Long-press peek on web chips: `FindBar` `peekId` pattern + `LONG_PRESS_MS`/`LONG_PRESS_SLOP_PX` re-exported from `interactions.ts`.
- ✅(fixed) Reduce motion: every animated surface now branches on the shared `useReducedMotion()`/`prefersReducedMotion()` (the per-file copies were folded into `interactions.ts` in Task 2).

### Pure-glass audit (both lanes)

- ✅ Web: the new shell surfaces (`SettingsPanel`/`FindBar`/`ToolDetail`/`AddToolModal`/`PlaygroundApp`) carry no `bg-black/*` glass. (The remaining `bg-black/*` hits are pre-existing P0 visualization-variant HUDs — out of the P1–P6 surface scope — plus one image-plate hover scrim in `AddToolModal` (not a glass panel).)
- ✅ iOS: no production view sets an opaque `Color` where `.liquidGlass` is expected — every `Color.black` hit is inside a `#Preview` canvas. `RootSheet` uses one system material, never a clear sheet wrapping a glass card.
- ✅ Both: every glass surface carries the inner top highlight (web `SHADOW.highlight` baked into `GLASS.*`; iOS inside `LiquidGlass.swift`).

### Steps

1. No code change. When each P1–P6 PR lands, the author flips the relevant ⬜ → ✅ in this
   file and links the diff lines that satisfy each row.
2. **Verify** the two lint tests still pass after every P-part lands:
   - Web: `npm test` (includes `interactions.test.ts`).
   - iOS: `xcodebuild test -scheme MyAIMap -destination 'platform=iOS Simulator,name=iPhone 16'` (includes `InteractionTokensTests`).
3. **Commit** (per P-part): `docs(p7): mark <part> interaction checklist complete`.

---

## Done criteria

- `npm test` and the iOS `xcodebuild test` both green with the new `interactions.test.ts`
  and `InteractionTokensTests.swift`.
- `FindBar.tsx`, `ToolDetail.tsx`, `AddToolModal.tsx` import from `interactions.ts`; no
  duplicated `navigator.vibrate`/`matchMedia` helpers remain (`grep` clean).
- iOS exposes `.peekPreview` and `.swipeToDismiss` modifiers + `InteractionTokens` with
  literal parity to the web `DISMISS`/`LONG_PRESS_*`/`DURATION.peek`.
- Every P1–P6 surface row in the checklist is ✅ with a linked diff before that part is
  considered shippable.
