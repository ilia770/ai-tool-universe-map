# Agent Operating Model

Last updated: 2026-06-10

This file defines how Codex and Claude Code collaborate inside this repository.

## Shared Rule

Both agents must read:

1. `.agent/INSTRUCTIONS.md`
2. `docs/PRODUCT_CTO.md`
3. `docs/APP_STRUCTURE.md`
4. This file
5. The specific plan or issue they are implementing

## Communication Channels

Use GitHub and repo files for durable coordination:

- GitHub PR descriptions: what changed, why, validation, screenshots.
- GitHub PR comments: questions, blockers, review requests.
- `docs/LOOP_LOG.md`: historical execution notes for the web polish sprint.
- `docs/superpowers/plans/*.md`: planned work with task checkboxes.
- `.agent/status/`: local-only scratch status, not committed.

Do not rely on private chat memory as the source of truth.

## File Ownership Matrix

Since 2026-08-05 this matrix decides **which areas may run in parallel**, not who
implements. Implementation and review ownership lives in
`docs/AGENT_OPERATIONS.md`: Codex implements, Claude Code plans and reviews.

| Area | Primary Agent | Backup Agent | Files |
| --- | --- | --- | --- |
| Product/CTO docs | Codex | Claude Code | `docs/PRODUCT_CTO.md`, `docs/APP_STRUCTURE.md` |
| Web 3D scene | Claude Code | Codex | `src/components/AIToolUniverse3D/**` |
| Web shell/panels | Codex | Claude Code | `src/components/AIToolUniverseMap.tsx`, `src/index.css` |
| Data/classification | Codex | Claude Code | `src/data/**`, `src/lib/classify-ai-tool.ts`, `src/lib/tool-logos.ts` |
| Visual QA | Claude Code | Codex | `tests/visual-smoke.spec.ts`, `screenshots/**`, `docs/design/**` |
| iOS app | Claude Code | Codex | `ios-app/**` |
| Release/checklists | Codex | Claude Code | `docs/RELEASE_REVIEW.md`, `.github/PULL_REQUEST_TEMPLATE.md` |

Primary agent means "touch first". Backup agent can edit after checking `git status`, reading the latest file, and confirming the other agent is not actively editing the same area.

## Branch and PR Rules

- Use one branch per coherent change.
- Use prefix `codex/` for Codex branches.
- Claude Code can use `claude/` or feature-specific branches.
- Do not commit unrelated dirty files.
- Prefer small PRs:
  - product docs
  - web interaction
  - web visual polish
  - data model
  - iOS phase
  - release tooling

## Handoff Format

When one agent hands work to another, write this in the PR description or a repo doc:

```markdown
## Agent Handoff

Owner: Codex | Claude Code
Next owner: Codex | Claude Code

### Done
- Exact completed items.

### Blockers
- Exact blocker, command, error, or screenshot.

### Next Files
- `path/to/file`: reason to edit.

### Validation Already Run
- `command` -> result.

### Validation Still Needed
- `command` -> expected result.
```

## Conflict Avoidance

Before editing:

```bash
git status --short --branch
git branch --show-current
```

If a file is dirty and you did not edit it:
- read it
- decide whether your change still applies
- do not revert it
- mention the conflict in your handoff

## Error Tracking

Use this structure in PR comments or `docs/LOOP_LOG.md` when something breaks:

```markdown
## Error
- Area:
- Command:
- Expected:
- Actual:
- Suspected cause:
- Files involved:
- Next action:
```

## Agent Review Checklist

Every non-trivial PR needs a second-agent review:

- Product intent matches `docs/PRODUCT_CTO.md`.
- File ownership was respected or explained.
- Tests/checks were run.
- Screenshots or visual notes were attached for UI work.
- Release checklist impact was considered.

