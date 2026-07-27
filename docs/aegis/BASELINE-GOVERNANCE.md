# Baseline governance

## Authority order

1. The user's explicit request and scoped approval.
2. Current source under `ios-app/` and the checked-in `project.yml` build
   definition.
3. `ios-app/docs/PROJECT_CONTEXT.md`, `UI_STATE_MACHINE.md`,
   `ARCHITECTURE.md`, `QA_REGRESSION_CHECKLIST.md`, and
   `TECHNICAL_DEBT.md`.
4. Apple platform documentation for submission and privacy requirements.
5. Historical plans and release notes, used as context only.

## Change rules

- Do not edit the user's dirty `polish/day-sprint` worktree.
- Treat generated `MyAIMap.xcodeproj` and build outputs as disposable evidence,
  not source of truth.
- Any release claim requires fresh, scoped evidence. Simulator tests, an
  unsigned archive, signing, TestFlight, and physical-device validation are
  distinct gates.
- New persistence, provider, account, or cloud owners require a separate
  approved plan and security review.
