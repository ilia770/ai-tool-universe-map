# UI_QA_CHECKLIST — Architecture and visual verification

**Status:** normative for future UI changes, initialized 2026-07-17.  
**Important:** a successful build is necessary but never sufficient visual
verification. Historical screenshots/runs are evidence only, not current
acceptance.

## Required preflight

- [ ] Read the five mandatory documents from `UI_APPLE_NATIVE_SPEC.md`.
- [ ] Name source/destination identities and one authoritative state owner.
- [ ] Inspect current source/tests; record dirty-worktree overlap.
- [ ] Build the actual target and run the narrowest relevant tests.
- [ ] State device, OS, appearance, Dynamic Type, Reduce Motion, and Reduce
      Transparency conditions for visual evidence.

## Component and layout checks

- [ ] No new array-index/random/timestamp identity for a persistent component.
- [ ] No duplicate replacement tree for a component that should transform.
- [ ] Correct semantic role for Liquid Glass; no unnecessary blur stack.
- [ ] Controls respect safe areas, keyboard, compact/regular width, and
      orientation.
- [ ] Text supports its documented Dynamic Type/localization behavior.
- [ ] VoiceOver labels, traits, focus order, and hit targets are verified.

## Transition recording matrix

For every significant transition, use deterministic data and capture:

- [ ] source baseline;
- [ ] opening;
- [ ] closing;
- [ ] partial interactive dismissal at approximately 25%, 50%, and 75%; 
- [ ] cancellation and completion;
- [ ] rapid repeat/reopen;
- [ ] after-scroll or keyboard state where relevant;
- [ ] Reduce Motion variant; and
- [ ] key-frame images showing source continuity, z-order, geometry, safe
      areas, and focus outcome.

Inspect for dead time, blank frames, source disappearance, duplicate content,
clipping jumps, corner-radius/material snapping, safe-area shifts, late
destination mount, wrong return point, gesture lag, and competing animations.

## Pilot execution recipe — tool node to detail

1. Launch a clean simulator with `-uitestSampleUniverse -uitestFocusTool figma`
   and motion enabled; record device/OS/appearance in the artifact manifest.
2. Begin the recording before tapping `ConstellationStar.figma`.
3. Capture opening, present state, 25/50/75% downward dismissal, cancel,
   full dismissal, and rapid reopen. Repeat after detail scrolling.
4. Use UI assertions/keyframes to prove the same `ConstellationStar.figma`
   returns after cancel/finish, and VoiceOver focus restores after finish.
5. Repeat with Reduce Motion enabled. Verify the state path survives even if
   spatial motion is simplified.
6. Compare recordings/key frames with the named supplied visual reference on
   the same simulator/device/OS/appearance. Record deviations and disposition.

`Tests/MyAIMapUITests/ToolDetailTransitionUITests.swift` will own the pilot
automation and its attachments. Store its video/key-frame manifest under
`screenshots/ui-architecture/pilot-tool-detail/` with device, OS, appearance,
launch flags, commit/worktree identity, and timestamps. A video alone is not
acceptance: it must include source, 25/50/75% partial drag, cancel, finish,
rapid reopen, after-scroll, focus return, and Reduce Motion evidence.

## Visual-reference manifest

Final visual acceptance requires all fields:

| Field | Current value |
| --- | --- |
| Reference asset/path/version | **Missing:** the supplied attachment contains text only. |
| Reference device / OS / appearance | **Missing.** |
| Reference states and timestamps | **Missing.** |
| Comparison owner and acceptance tolerance | **Missing.** |
| Replacement artifacts | Existing repository screenshots are baseline evidence only; not a substitute. |

Until this manifest is complete, mark the final visual-comparison gate
**blocked**, not passed. The pilot can still be designed and implemented in a
later approved task.

## First-execution evidence

- Build on 2026-07-17: `xcodebuild build -project MyAIMap.xcodeproj -scheme
  MyAIMap -destination 'platform=iOS Simulator,id=B9323BE8-06B1-4F86-BE32-B4943196D22D'
  -derivedDataPath /tmp/aimap-ui-architecture-dd CODE_SIGNING_ALLOWED=NO` →
  **BUILD SUCCEEDED**.
- No fresh full test-suite result is claimed for this dirty snapshot.
- A generic `build-for-testing` attempt was stopped during Xcode's dual-architecture
  module compilation; it is not treated as a pass or failure result.
- Simulator visual capture was retried after removing only this task's
  disposable DerivedData (free space recovered from about 108 MB to more than
  4 GB). The iOS 18 runtime shut down during install; iOS 26.5 can enumerate
  and boot but runtime IPC (`install`, `launch`, screenshot) hangs while
  `CoreSimulatorService` intermittently disconnects. This is an
  environment-evidence limitation, not a conclusion that the app is blank.
  A host-level CoreSimulator/Xcode restart (or macOS restart) and a fresh
  stable simulator recording remain required before visual acceptance.
