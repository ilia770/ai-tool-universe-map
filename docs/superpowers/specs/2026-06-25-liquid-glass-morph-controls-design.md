# Liquid Glass Morph Controls — Design

Date: 2026-06-25
Status: Approved (brainstorming) — pending spec review
Branch (PR #1): `feat/liquid-glass-design-system`

## Goal

Restyle every interactive control in the iOS app onto a coherent iOS 26
Liquid Glass system, governed by one principle:

> When a control cluster changes state, **one glass element morphs** — it
> changes place / shape / size / text — instead of separate elements
> appearing and disappearing.

Plus a consistent spacing scale, a rounded-SF typography base, and
correct ≥44pt hit areas on every control. The 2D graph map stays the
default render mode and must not regress (Track A).

This is large, so it is decomposed: a **design-system foundation PR
first**, then one **surface (screen) per PR** built on that base.

## Core principle: the morph

iOS 26 gives us matched-geometry morphing of glass:

```swift
GlassEffectContainer(spacing: <matches layout spacing>) {
    // each state's element carries the SAME glassEffectID
    SomeState()
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("cluster.active", in: namespace)
}
.animation(.smooth, value: state)
```

Same `glassEffectID` across two states ⇒ SwiftUI animates ONE glass
shape between them (the segmented-control / Flighty tab-bar / Sky Guide
toolbar pattern in the references). A cluster therefore has exactly one
"live" glass element that travels and reshapes; option backdrops are
secondary.

Reference cues (from the supplied screenshots): floating glass tab bars
with a single travelling selection capsule; glass circular toolbar
buttons; a morphing Style/segment pill; capsule chips. The 3D-globe
shots are visual-feel references only, not control patterns.

## PR #1 — Design system (foundation)

A single PR establishing tokens + the morph primitive + the hit-area
helper + the verification harness. No screen is fully migrated here
beyond a demo; this PR is the base every later surface PR builds on.

### 1. Spacing scale — `BrandSpacing`

An 8pt-grid token set used for control padding and inter-control gaps:
`xxs=2, xs=4, sm=8, md=12, lg=16, xl=20, xxl=24`. Replaces ad-hoc
literal paddings on controls as surfaces are migrated. A
`GlassEffectContainer`'s `spacing` must equal the cluster's layout
spacing (Apple requirement), so clusters read their gap from this scale.

### 2. Typography — `BrandFont`

A role-based token layer mapping to rounded vs regular SF:

- **Rounded** (`design: .rounded`): titles, body, primary control
  labels (buttons/pills/tabs), large numerics/badges.
- **Regular** (default SF): captions, footnotes, secondary/muted
  labels, metadata, timestamps.

Tokens (names illustrative): `.titleRounded`, `.bodyRounded`,
`.controlLabel` (rounded); `.caption`, `.secondaryLabel`, `.metadata`
(regular). Each maps to a SwiftUI `Font` at a fixed size/weight so call
sites stop hand-rolling `.system(...)`. Dynamic Type respected (relative
text styles where the existing code already uses them).

### 3. Morph primitive — `GlassMorphCluster`

A reusable wrapper capturing the principle so surfaces don't re-derive
it. Shape of the API (final names settled in the plan):

```swift
GlassMorphCluster(spacing: BrandSpacing.xs, namespace: ns) {
    // option content + one element tagged as the active/selected glass
}
```

Internally, 3-tier (extends the existing `glassSurface` tiering):

- **iOS 26+**: `GlassEffectContainer` + `.glassEffect(.regular[.tint]
  .interactive(), in: shape)` + `.glassEffectID(id, in: ns)`; selection
  change driven by `withAnimation(.smooth)`.
- **iOS 18–25**: `matchedGeometryEffect(id:in:)` fallback approximating
  the travelling selection (already the codebase's fallback pattern via
  `navigationGlassMorphID`).
- **Reduce Transparency**: opaque `BrandColor.glassSolid` fill, no
  blur; selection still moves but without glass.

`.interactive()` only on genuinely tappable elements. Tint opacity (not
deprecated modifiers) conveys emphasis.

### 4. Hit-area helper — `.hitArea(min: 44)`

A modifier guaranteeing a ≥44×44pt tappable region (HIG minimum) around
a control regardless of its visual size, plus an
`accessibilityIdentifier` convention (`"<surface>.<control>"`) so
XCUITests can address every control deterministically.

### 5. Verification harness

- Unit tests pinning token values (`BrandSpacing`, `BrandFont` sizes)
  and the cluster's selection-state logic (which is the pure, testable
  part — the visual glass is not unit-testable).
- A **demo XCUITest** driving a sample `GlassMorphCluster`: taps each
  option by identifier, asserts the selection state changes and the hit
  frame is ≥44pt. This proves the pattern + the XCUITest plumbing that
  later surface PRs reuse.

## Per-surface pipeline (PR #2 onward)

Each surface PR follows the same loop:

1. **Reference study** — a subagent extracts the relevant Liquid Glass
   control patterns (from the screenshots + Apple HIG) for that
   surface's control types, into a short note.
2. **Branch** off latest main.
3. **Implement** — convert the surface's controls to
   `GlassMorphCluster` / glass tokens; apply `BrandSpacing`,
   `BrandFont`, `.hitArea`. Touch only that surface.
4. **Auto-verify** — code-review pass + run unit + XCUITest suites.
5. **Build + sim screenshots** (2D default path, simctl).
6. **XCUITest autotaps** — tap every control on the surface by
   identifier; assert reaction + hit frame ≥44pt.
7. **PR** → user device-tests the morph feel → merge.

### Surface order

1. **chat** — SearchDock composer, chat chrome, tool/suggestion chips.
2. **universe-overlay** — right rail, chrome buttons, mode toggle,
   center pill (Map↔AskAI), labels.
3. **sheets** — AddTool, Detail/RootSheet, Account.
4. **settings**.
5. **onboarding**.

## Constraints

- **Track A**: only `.spatial3D` visuals may change freely; the 2D
  graph stays the default and its behavior must not regress.
- iOS 26 morph always behind `#available(iOS 26, *)` with the iOS
  18–25 + reduce-transparency fallbacks intact.
- Every PR green (unit + XCUITest + existing CI gates) before merge.
- Morph = one element changes; never separate appear/disappear.
- Surgical: each PR touches only its surface (PR #1 only adds tokens +
  primitive + harness, migrates nothing beyond the demo).

## Testing strategy

- **Unit** (Swift Testing): token values, cluster selection-state logic,
  hit-area frame math.
- **XCUITest**: per-surface autotap of every control (identifier →
  reaction + ≥44pt frame); reused across surface PRs.
- **Sim screenshots**: visual layout/spacing check per surface (2D
  default is sim-visible).
- **Device** (user): final morph-feel sign-off per surface (the glass
  motion can't be judged in the simulator).

## Out of scope

- The 3D RealityKit scene visuals (separate track; references are
  feel-only here).
- Flipping 3D to default (unrelated Track A decision).
- New product features — this is a restyle + correctness pass only.
