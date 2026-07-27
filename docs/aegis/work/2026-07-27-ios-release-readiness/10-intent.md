# Task intent — iOS release-readiness

## TaskIntentDraft

- Goal: turn the existing privacy-manifest fix into independently reviewed,
  precise Release-archive evidence and create the next catalog-durability plan.
- Success evidence: reviewer findings resolved; manifest parses and XcodeGen
  includes it; a Release archive either contains the manifest or the host
  blocker is reproducibly documented; debt/docs and the follow-on plan are
  updated.
- Stop states: `done`, `needs-verification` if CoreSimulator/Xcode remains
  unavailable, `blocked` only for repeated external infrastructure failure, or
  `scope-exceeded` if a new persistence/provider/account boundary appears.
- Non-goals: signing, TestFlight, App Store upload, privacy-label declaration,
  physical device performance, cloud scale, or user data migration.

## BaselineReadSetHint / BaselineUsageDraft

Required and acknowledged: root/iOS agent instructions; project context, UI
state, architecture, QA checklist, technical debt; `project.yml`; current
manifest; local-first foundation design; Apple required-reason documentation.

Missing external baseline: Apple account configuration, certificates/profiles,
App Store Connect access, and physical devices.

## ImpactStatementDraft

The only app bundle change is a declarative privacy resource. It must not alter
catalog persistence or send content anywhere. The significant risk is an
unsupported release claim from incomplete archive evidence, not a behavior
change.
