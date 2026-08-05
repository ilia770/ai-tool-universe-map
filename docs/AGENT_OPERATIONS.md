# AI Map daily agent operations

This is the project-local entry point for Codex and Claude Code. It is a
concise mirror of the team-wide
[Daily Agent Operating System](https://linear.app/ilia770/document/daily-agent-operating-system-b5924d2ae766),
and the counterpart of `docs/AGENT_OPERATIONS.md` in the Mult repository.

## Source of truth

- **Active work and delivery state:** the `AI Map Daily Development` project in
  Linear (workspace `ilia770`).
- **Product and architecture:** `docs/PRODUCT_CTO.md`, `docs/APP_STRUCTURE.md`,
  and the relevant specification under `docs/superpowers/specs/`.
- **Collaboration and file ownership:** `docs/AGENT_OPERATING_MODEL.md`.
- **Release and stop-ship rules:** `docs/RELEASE_REVIEW.md`.
- **Design system:** `docs/DESIGN_TOKENS.md`, `docs/DESIGN_PATTERNS.md`.

Linear decides **what is next**. Repository documents decide **how it must
behave**. Do not let an old TODO, a chat message, or an uncommitted diff become
new product scope by itself.

## Every session

1. Read the Linear project and one selected issue. If Linear is unavailable, ask
   the owner for an issue link or identifier; do not invent a task.
2. Read the specification and QA documents named by the issue.
3. Run `git status --short --branch` before edits. The working tree is shared:
   never overwrite, revert, delete, stage, or reformat changes you did not create.
4. Claim only one unblocked issue by moving it to **In Progress** and adding a
   comment with agent, branch/worktree, intended files, and verification plan.
5. Keep the implementation within the issue's scope. Turn discoveries into a
   separate issue instead of silently expanding the current one.

## Ownership and shared-machine safety

Role split, effective 2026-08-05. The file ownership matrix in
`docs/AGENT_OPERATING_MODEL.md` still decides which areas may run in parallel;
this decides who implements and who reviews.

- **Codex implements.** Web, data, and `ios-app/` code comes from Codex. It never
  commits, pushes, or merges — changes are left in the working tree for review.
- **Claude Code plans and reviews.** It grooms the Linear board, turns issues
  into executable specs, reviews every diff, runs verification, commits what
  passes, and posts the `## Handoff` evidence.
- Claude implements only when Codex is unavailable — dead auth, usage limit, or
  two failed rounds on the same issue — and records that on the issue.
- Two agents must not edit the same files concurrently. iOS build/test work must
  use a clear simulator window; do not interfere with a running `xcodebuild` or
  another agent's simulator destination.
- The day is driven by the `daily-ops`, `day-plan`, `day-run`, and `day-wrap`
  skills in `~/.claude/skills/`.

## Verification

- Fast: `npm run typecheck && npm run lint`
- Full: `npm run typecheck && npm run lint && npm test && npm run build && npm run smoke:visual:fast`
- iOS: `npm run ios:verify`
- Release gate: `npm run release:check`, plus `docs/RELEASE_REVIEW.md`

Run the narrowest relevant check first; widen when the change touches data,
release configuration, the 3D scene, or the design tokens.

## Definition of done

Do not mark an issue Done because code was written or a build was launched.
The issue acceptance criteria must be met and its final Linear comment must
contain:

```markdown
## Handoff
- Outcome: …
- Changed: …
- Verification: `<command>` → result; manual/visual evidence: …
- Commit / PR: …
- Docs updated: …
- Risks / follow-up: …
```

If a decision, device check, external access, or another actor's changes block
the work, state exactly what is needed in Linear. Use `needs:decision` or
`needs:device-qa` where applicable, and keep the issue out of the active queue
until it can move forward.

## Human control points

Stop and ask before: merging to `main`, any push beyond the working branch,
Vercel production deploy, App Store submission, data-source migration,
dependency bumps, and secrets. Also stop when review finds a BLOCKER.

## Deprecated

Superseded by Linear; kept for history, do not add to them:
`docs/CLAUDE_BACKLOG.md`, `docs/CLAUDE_PARALLEL_TASKS.md`,
`docs/NIGHT_CYCLE_BOARD.md`, `docs/LOOP_PLAN.md`.
`docs/LOOP_LOG.md` remains append-only history.
