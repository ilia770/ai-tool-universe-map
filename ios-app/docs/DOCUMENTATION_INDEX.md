# DOCUMENTATION_INDEX — Where to find current truth

Start with the repository-root `AGENTS.md`, then `ios-app/AGENTS.md`, and read:

1. `SPEC_INDEX.md` — authority map and conflict register.
2. `PRODUCT_SPEC.md` — current product behavior and acceptance boundary.
3. `UI_APPLE_NATIVE_SPEC.md` — permanent implementation architecture.
4. `UI_COMPONENT_IDENTITY.md` and `UI_TRANSITION_CATALOG.md` for UI work.
5. `PROJECT_CONTEXT.md`, `ARCHITECTURE.md`, `STATE_OWNERSHIP.md`, the relevant
   feature document, and the actual cited source/tests.

## Canonical current documents

| Need | Read |
| --- | --- |
| UI architecture authority / conflicts | `SPEC_INDEX.md`, `SPEC_CONFLICTS.md`, `UI_APPLE_NATIVE_SPEC.md` |
| Component identity / lifecycle | `UI_COMPONENT_IDENTITY.md`, `UI_COMPONENT_LIFECYCLE.md` |
| Motion, layout, type, accessibility | `UI_MOTION_TOKENS.md`, `UI_LAYOUT_SYSTEM.md`, `UI_TYPOGRAPHY.md`, `UI_ACCESSIBILITY.md` |
| Transition recording and visual QA | `UI_TRANSITION_CATALOG.md`, `UI_QA_CHECKLIST.md`, `UI_IMPLEMENTATION_REPORT.md` |
| What is actually implemented | `PRODUCT_SPEC.md`, `PROJECT_CONTEXT.md` addendum |
| Bootstrap/module boundary | `ARCHITECTURE.md`, `REPOSITORY_MAP.md` |
| State/navigation | `STATE_OWNERSHIP.md`, `NAVIGATION_SPEC.md`, `UI_STATE_MACHINE.md` addendum |
| Map | `UNIVERSE_MAP_SPEC.md` current-renderer addendum |
| Rail | `RIGHT_RAIL_SPEC.md` current-baseline status |
| Chat/input | `INPUT_CHAT_SPEC.md` current-baseline status, `INTERACTION_SPEC.md` |
| Visual primitives/morphs | `DESIGN_SYSTEM.md`, `LIQUID_GLASS_TRANSITIONS.md` |
| Data/storage/network | `DATA_AND_PERSISTENCE.md` |
| Tests/manual checks | `TESTING_STRATEGY.md`, `QA_REGRESSION_CHECKLIST.md` baseline |
| Risks/unknowns | `TECHNICAL_DEBT.md`, `OPEN_QUESTIONS.md` |
| How to make/delegate a change | `ENGINEERING_WORKFLOW.md`, `SUBAGENT_GUIDE.md` |

## Historical or narrow-scope documents

Never use a historical document as current behavior evidence, even if its title
contains “spec”, “landed”, or “QA”. Compare its paths with source and then use
the following current owner instead:

| Historical/mixed document | Current owner(s) |
| --- | --- |
| `ADD_TOOL_SPEC.md`, `FIRST_RUN_SPEC.md`, `SETTINGS_PROFILE_SPEC.md` | `PRODUCT_SPEC.md`, `INTERACTION_SPEC.md`, `DATA_AND_PERSISTENCE.md` |
| `CHAT_AI_SPEC.md`, `CHAT_INPUT_SPEC.md` | `INPUT_CHAT_SPEC.md`, `INTERACTION_SPEC.md`, `STATE_OWNERSHIP.md` |
| `DETAIL_SCREEN_SPEC.md`, `TOOL_DETAIL_SPEC.md` | `INTERACTION_SPEC.md`, `NAVIGATION_SPEC.md`, `STATE_OWNERSHIP.md` |
| `LAYERING_AND_NAVIGATION_SPEC.md` | `ARCHITECTURE.md`, `NAVIGATION_SPEC.md`, `DESIGN_SYSTEM.md` |
| `VISUALIZATION_SPEC.md`, `UNIVERSE_STATE_MACHINE.md`, all RealityKit audit/architecture/camera/implementation/visual-system docs | `PROJECT_CONTEXT.md` addendum, `ARCHITECTURE.md`, `UNIVERSE_MAP_SPEC.md` current renderer baseline, `UI_STATE_MACHINE.md` baseline |
| `UNIVERSE_QA_CHECKLIST.md`, `LOOP_*`, `POLISH_SPRINT_PLAN.md`, `IMPLEMENTATION_ROADMAP.md`, audit/rubric/digest documents and `superpowers/` plans | Current QA/test/architecture docs above; historical evidence only. |

`CHANGELOG_DOCUMENTATION.md` defines how to supersede rather than erase these
records.
