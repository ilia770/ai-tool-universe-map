# Todo checkpoint — iOS release-readiness

## TodoCheckpointDraft

- Completed: baseline documents reread; isolated worktree confirmed clean;
  existing commit `b238c47` inspected; Release-evidence plan created; two
  independent manifest reviews completed without source findings; plist parsing
  and generated-resource inclusion passed; a clean unsigned archive retry was
  attempted.
- Active slice: record the release evidence precisely and write the next
  catalog-durability plan without changing persistence.
- Next: review the catalog contract/file map, complete its implementation plan,
  then commit scoped evidence and planning documentation.
- Blocked-on: archive evidence is blocked. During the fresh archive retry,
  CoreSimulatorService disconnected and `ibtool`/`actool` reported no runtime /
  `iOS 26.5 Platform Not Installed` (exit 65). No service restart is authorized
  because it would affect the user's running simulators.

## ResumeStateHint

Use `/private/tmp/aimap-privacy-manifest` on branch
`codex/ios-privacy-manifest`. Do not touch
`/Users/ilia882/Code/ai-tool-universe-map` (`polish/day-sprint`), which is the
user's dirty worktree. `b238c47` is the source correction; plan/work records
are uncommitted at this checkpoint.

## DriftCheckDraft

- Task intent / goal: aligned.
- Compatibility: no source behavior or persistent data has changed.
- New owner/fallback/adapter: none.
- Retirement: the old deferred archive evidence remains until fresh proof.
- Evidence: source/configuration evidence is fresh; full archive evidence is
  `needs-verification` because of reproducible host infrastructure failure.
- Decision: continue with catalog planning; do not retry the same archive until
  the host service has been deliberately recovered.
