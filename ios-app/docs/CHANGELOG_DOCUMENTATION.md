# CHANGELOG_DOCUMENTATION — Keep the knowledge system current

## Practical update rules

| Change type | Required documentation update | Owner |
| --- | --- | --- |
| App bootstrap, target, framework, renderer, module boundary | `PROJECT_CONTEXT.md`, `ARCHITECTURE.md`, `REPOSITORY_MAP.md` | task implementing the change. |
| Selection, navigation, sheet, root route, restoration behavior | `STATE_OWNERSHIP.md`, `NAVIGATION_SPEC.md`, `UI_STATE_MACHINE.md` | task implementing the change. |
| Map/rail/chat/detail interaction | relevant feature spec plus `INTERACTION_SPEC.md`, QA checklist | feature task. |
| Model/schema/UserDefaults/Keychain/network | `DATA_AND_PERSISTENCE.md`, tests, technical debt if migration deferred | data/service task. |
| Token/component/motion/glass behavior | `DESIGN_SYSTEM.md`, `LIQUID_GLASS_TRANSITIONS.md`, relevant feature spec | visual-system task. |
| Test coverage or runtime evidence | `TESTING_STRATEGY.md`, QA checklist; append dated result only when fresh | test/verification task. |
| Known limitation or unresolved decision | `TECHNICAL_DEBT.md` or `OPEN_QUESTIONS.md` | discovering task. |

For a UI-architecture change, also update the applicable permanent owner:
`UI_COMPONENT_IDENTITY.md`, `UI_COMPONENT_LIFECYCLE.md`,
`UI_TRANSITION_CATALOG.md`, `UI_MOTION_TOKENS.md`, `UI_LAYOUT_SYSTEM.md`,
`UI_TYPOGRAPHY.md`, `UI_ACCESSIBILITY.md`, or `UI_QA_CHECKLIST.md`. Start with
`SPEC_INDEX.md` and record a real document conflict in `SPEC_CONFLICTS.md`.

## Documentation ownership

- Current factual baseline: `PROJECT_CONTEXT`, `PRODUCT_SPEC`, `ARCHITECTURE`,
  `REPOSITORY_MAP`, `STATE_OWNERSHIP`, `NAVIGATION_SPEC`,
  `DESIGN_SYSTEM`, `INTERACTION_SPEC`, `DATA_AND_PERSISTENCE`,
  `TESTING_STRATEGY`, and this process document.
- Feature behavior: current addenda in `UNIVERSE_MAP_SPEC`, `RIGHT_RAIL_SPEC`,
  `INPUT_CHAT_SPEC`, `UI_STATE_MACHINE`, and
  `LIQUID_GLASS_TRANSITIONS`.
- Historical plans/reports: existing sprint, queue, audit, redesign, and
  implementation-report documents retain their dates/context. They must not
  silently be rewritten as current truth.

## Decision and deprecation format

When a decision changes a durable boundary, add a dated section to the owner
document with:

```markdown
### Decision — YYYY-MM-DD
- Status: CONFIRMED / SUPERSEDED / DEPRECATED CANDIDATE
- Evidence: source paths, tests, and runtime result
- Decision and non-goals
- Migration/retirement trigger, if any
```

Mark a stale feature specification `HISTORICAL` or `SUPERSEDED` at its top
instead of deleting its evidence. Link to the current owner. Do not create a
second competing spec for the same concern.

## Source-of-truth conflict protocol

1. Inspect current source and tests named by the competing documents.
2. Record the conflict in `OPEN_QUESTIONS.md` or `TECHNICAL_DEBT.md` if code
   cannot answer it.
3. Preserve the historic claim with its date; place the factual current
   addendum in the canonical current document.
4. Resolve only with explicit product/architecture evidence and then mark the
   prior claim superseded.

Keep changelog overhead small: document behavior/ownership changes, not every
wording or formatting edit.
