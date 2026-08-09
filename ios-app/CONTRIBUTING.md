# Contributing to the native iOS app

This is the contributor entry point for `ios-app/`. Read it with
`ios-app/AGENTS.md` before changing code or documentation.

## Required UI pre-read

Before creating or modifying UI, read in order:

1. [Product specification](docs/PRODUCT_SPEC.md)
2. [Permanent Apple-native UI architecture](docs/UI_APPLE_NATIVE_SPEC.md)
3. [Component identity catalog](docs/UI_COMPONENT_IDENTITY.md)
4. [Transition catalog](docs/UI_TRANSITION_CATALOG.md)
5. The relevant feature specification

Then inspect cited source/tests, name the authoritative state owner, define
scope and acceptance criteria, and use the verification plan in
[UI_QA_CHECKLIST.md](docs/UI_QA_CHECKLIST.md). Start with the full document map
in [SPEC_INDEX.md](docs/SPEC_INDEX.md); use
[ENGINEERING_WORKFLOW.md](docs/ENGINEERING_WORKFLOW.md) for the broader change
protocol.

Do not alter production UI as part of an audit-only task. Record conflicts in
`SPEC_CONFLICTS.md` rather than silently choosing between historical and
current documents.

