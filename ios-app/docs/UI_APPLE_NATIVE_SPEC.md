# UI_APPLE_NATIVE_SPEC — Permanent iOS UI architecture

**Status:** normative project-level specification, adopted 2026-07-17.  
**Scope:** every native iOS screen, reusable component, UI-related test, refactor,
SwiftUI/UIKit integration, and subagent task under `ios-app/`.

This specification governs **how** the interface is structured and verified.
`PRODUCT_SPEC.md` governs **what** the product does. It does not retroactively
claim that the current baseline already meets every rule; gaps are recorded in
`UI_APPLE_NATIVE_AUDIT.md` and resolved through approved, scoped work.

The user-supplied specification requested a `Docs/` directory. This repository
already uses the lowercase, canonical `ios-app/docs/` convention, so all
required documents live here to avoid a parallel documentation tree.

## Authority and references

Resolve UI decisions in this order:

1. explicit current product requirements;
2. current project-specific product/design specification;
3. this document;
4. current, runtime-verified implementation behavior;
5. [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/);
6. current [SwiftUI documentation](https://developer.apple.com/documentation/swiftui/);
7. official Apple Design Resources; and
8. clearly labelled assumptions.

Do not silently resolve a contradiction. Record it in `SPEC_CONFLICTS.md`,
choose the smallest safe interpretation that preserves product intent, and
update the relevant source-of-truth document with the decision.

## Core contract

### Identity and lifecycle

- Same conceptual object means the same stable semantic identity. Use domain
  IDs such as `Tool.id`, `ToolCategoryId.rawValue`, typed route IDs, or a
  documented control role. Never use an array offset, a `UUID()` made in
  `body`, a timestamp, or an appearance count as persistent UI identity.
- Before adding a component, search `UI_COMPONENT_IDENTITY.md`,
  `UI_TRANSITION_CATALOG.md`, the layout/type catalogs, and the relevant
  feature spec. Prefer a state, variant, or composition of an existing
  semantic component over a replacement tree.
- Each transitioning component has a documented creation point, owner, stable
  ID, source/destination state, interruption behavior, removal point,
  restoration path, and accessibility-focus result in
  `UI_COMPONENT_LIFECYCLE.md`.
- Do not create names such as `Button2`, `CardV2`, `NewNavigationBar`, or
  `DetailPosterCopy` without a documented migration that removes the old
  implementation in the same controlled change.

### State and navigation

- Every item of UI state has one authoritative owner. A view may keep local
  gesture/focus implementation state, but it must not mirror selected item,
  route, active sheet, transition progress, or dismissal progress without an
  explicit derived-binding contract.
- Prefer typed, item-driven routes and system navigation where they express
  the product interaction: `NavigationStack` for hierarchy, system sheets for
  genuinely modal tasks, and one route owner per navigation domain.
- Mutually dependent presentation booleans are a signal to introduce an
  explicit state model; do not combine unrelated `isPresented` flags to model
  a single transition.
- Root Map/Ask AI and map-level navigation are distinct domains today. Their
  relationship and restoration behavior must be explicit rather than merged
  accidentally during a UI refactor.

### Continuity, transitions, and dismissal

- A transition must explain what persists, what is new, what moves/resizes,
  who owns progress, what happens on interruption, and where accessibility
  focus moves. Catalog it before implementation in `UI_TRANSITION_CATALOG.md`.
- Use the simplest native mechanism that visibly meets the contract. On the
  iOS 18 deployment target, evaluate
  [`matchedTransitionSource`](https://developer.apple.com/documentation/swiftui/view/matchedtransitionsource%28id%3Ain%3A%29)
  together with
  [`navigationTransition(.zoom)`](https://developer.apple.com/documentation/swiftui/navigationtransition/zoom%28sourceid%3Ain%3A%29)
  for true hierarchical routes. Use `matchedGeometryEffect` only when source
  and destination can coexist safely. Use a persistent custom hero host when
  system navigation cannot provide required source reservation or continuous
  interactive return.
- Presence of a modifier is not proof of continuity. Simulator evidence is
  required before a transition is accepted as Apple-native.
- An interactive dismissal must be progress-driven when the intended behavior
  follows the finger. Distance and velocity decide completion; cancel settles
  smoothly; system back, custom close, VoiceOver escape, and the gesture
  converge through the same state transition.

### Materials and motion

- Liquid Glass is a functional control/navigation layer, not the default
  content background. Use native `glassEffect`/`GlassEffectContainer`/
  `glassEffectID` where supported and documented; use the project fallback on
  earlier systems. Do not stack unrelated custom blur below native glass.
- Long reading surfaces, list rows, content cards, and backgrounds use normal
  content surfaces/materials unless their functional-control role is explicit.
- Use semantic motion roles from `UI_MOTION_TOKENS.md`, not scattered raw
  durations. Motion must preserve cause and effect, remain interruptible where
  appropriate, and retain meaning under Reduce Motion.

### Layout, type, accessibility, and performance

- Respect safe areas; background/media may extend full bleed, but controls and
  readable content must remain reachable across supported size classes,
  orientation, keyboard states, and Dynamic Type sizes.
- Prefer system/adaptive layout mechanisms over device bounds, permanent
  negative offsets, or geometry feedback loops. Repeated spacing is semantic,
  not merely numerical. See `UI_LAYOUT_SYSTEM.md`.
- Use semantic system typography and Dynamic Type unless a documented
  product constraint says otherwise. See `UI_TYPOGRAPHY.md`.
- Each component and transition supports VoiceOver, meaningful focus order,
  sufficient hit targets, Reduce Motion, Reduce Transparency, and appropriate
  contrast. See `UI_ACCESSIBILITY.md`.
- Avoid unstable `ForEach` identity, wide observation, heavy work in `body`,
  per-frame SwiftUI state updates, duplicate async work, and redundant
  material stacks.

## Mandatory pre-read for UI work

Before creating or modifying any UI, an agent must read, in this order:

1. `PRODUCT_SPEC.md`;
2. this `UI_APPLE_NATIVE_SPEC.md`;
3. `UI_COMPONENT_IDENTITY.md`;
4. `UI_TRANSITION_CATALOG.md`; and
5. the relevant feature specification.

Then the agent must inspect the cited source/tests, state the edit boundary,
name the authoritative state owner, identify protected files, set acceptance
criteria, and describe the verification plan. `AGENTS.md` and
`ENGINEERING_WORKFLOW.md` enforce this rule.

## Change control and verification

For each meaningful UI change, update the component/transition catalog and
the relevant feature spec, then run proportionate tests and a simulator path.
For a transition, capture opening, closing, partial interactive dismissal,
cancel, complete dismissal, rapid repetition, Reduce Motion, and the defined
reference comparison. `UI_QA_CHECKLIST.md` is the executable acceptance list.

The initial baseline and its known limits are in
`UI_IMPLEMENTATION_REPORT.md`. The next allowed production change is the
approved pilot described there; broad UI refactoring is explicitly out of
scope until that audit is reviewed.
