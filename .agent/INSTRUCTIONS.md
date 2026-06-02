# Shared Agent Instructions

This file is the canonical project context for both Claude Code and Codex.

## Coordination

- Treat the working tree as shared with the user and possibly another agent.
- Start every task by checking `git status --short --branch`.
- Never overwrite, revert, delete, or reformat changes you did not make unless the user explicitly asks.
- If another agent or the user changed a file you need, read the current file and work with the new state.
- For large or risky tasks, use a separate git branch or worktree instead of editing directly on the same branch.
- For small tasks in the same folder, avoid editing the same file concurrently. Claim the task in `.agent/status/` when useful.
- Keep generated scratch files, local locks, and temporary notes under `.agent/status/` or `.agent/tmp/`; these are local-only and should not be committed.

## Execution

- Prefer small, incremental changes.
- Read the project structure before editing.
- Use existing project patterns before adding new abstractions.
- Add or update tests when behavior changes.
- Run the narrowest relevant checks first, then broader checks when risk is higher.
- Commit only your own completed changes, and do not stage unrelated files.

## Documentation

- Keep `AGENTS.md` and `CLAUDE.md` aligned through this shared file.
- Add project-specific commands, invariants, and architecture notes below.
- Update this context when project rules change.

## Project Context

Replace this section with project-specific context.
