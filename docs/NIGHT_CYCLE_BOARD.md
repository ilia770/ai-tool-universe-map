# Night Cycle Board

Last updated: 2026-06-11

Canonical roadmap:
`docs/superpowers/plans/2026-06-11-50-task-master-roadmap.md`.

## Now

| Task | Owner | Branch | Files | Status |
| --- | --- | --- | --- | --- |
| 1 — iOS verify commands | Codex | `codex/50-task-roadmap-and-release-slice` | `scripts/ios-verify.sh`, `package.json`, `docs/RELEASE_REVIEW.md`, `ios-app/README.md` | done |
| 2 — iOS runbook | Codex | `codex/50-task-roadmap-and-release-slice` | `docs/ios/RUNBOOK.md`, `docs/AGENT_STATUS.md` | done |
| 40 — release review automation | Codex | `codex/50-task-roadmap-and-release-slice` | `scripts/release-check.sh`, `package.json`, `docs/RELEASE_REVIEW.md` | done |
| 43 — dependency migration plan | Codex | `codex/50-task-roadmap-and-release-slice` | `docs/DEPENDENCY_MIGRATION.md`, `docs/AGENT_STATUS.md` | done |
| 50 — night-cycle board | Codex | `codex/50-task-roadmap-and-release-slice` | `docs/NIGHT_CYCLE_BOARD.md` | done |

## Next

| Task | Recommended Owner | Why |
| --- | --- | --- |
| 4 — iOS SearchDock | Claude Code | Continues Phase 2 iOS after PocketShell/RealityKit merge |
| 6 — Drag-orbit gesture tuning | Claude Code | Touches active iOS camera/gesture code |
| 16 — Hover focus de-cluttering | Codex or Claude Code | High visible impact on web map readability |
| 21 — Logo scale and fallback polish | Codex | Data/UI bounded; low conflict with iOS |
| 26 — Tool schema hardening | Codex | Protects data before adding more tools |
| 35 — Playwright visual smoke hardening | Codex | Gives confidence for future visual PRs |

## Later

| Track | Tasks |
| --- | --- |
| iOS TestFlight | 10, 11, 12, 13, 14, 15, 48 |
| Web premium 3D | 17, 18, 19, 20, 22, 23, 24, 25 |
| Data/classifier | 27, 28, 29, 30, 31, 32, 33 |
| Release/QA | 34, 36, 37, 38, 39, 41, 42, 44, 45, 49 |
| Product/design | 46, 47 |

## Parallel Work Rules

- One task per branch.
- Avoid concurrent edits to `UniverseView.swift`, `AIToolUniverseMap.tsx`,
  `Scene.tsx`, `package.json`, and `docs/AGENT_STATUS.md`.
- If a task needs one of those shared files, announce ownership in the PR body
  and keep the PR small.
- After merge, update this board or `docs/AGENT_STATUS.md`.

## Parallel Discovery Notes

- iOS verification should regenerate `MyAIMap.xcodeproj` from
  `ios-app/project.yml` before building. The generated project is ignored by
  git, so stale local projects can miss new files such as `PocketShellEntity`
  or `PocketShellGeometry`.
- Prefer simulator ids over simulator names in docs and scripts. Names collide
  across installed iOS runtimes.
- The next high-leverage iOS work is still gesture/navigation depth:
  drag-orbit, camera damping, accessibility labels, and UI smoke tests.
- The next high-leverage web work is Task 16: add a Playwright label
  legibility guard, then tune hover/focus de-emphasis so the active node is
  obvious and background labels do not visually pile up.
- Follow with Task 21 for logo trust: curated logo domains, stronger fallback
  initials, and bigger but bounded icon presentation.

## Claude Code Prompt

```text
Read .agent/INSTRUCTIONS.md, docs/AGENT_STATUS.md, and
docs/superpowers/plans/2026-06-11-50-task-master-roadmap.md.
Take one Next task from docs/NIGHT_CYCLE_BOARD.md, create a fresh branch or
worktree, and implement only that task. Do not edit files owned by an active
Codex task. Run the task verification and open a PR with changed files, risks,
and validation.
```
