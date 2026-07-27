# Initial baseline — iOS release-readiness

Date: 2026-07-27

Worktree: `/private/tmp/aimap-privacy-manifest`
Starting source: `c287268` (`codex/ios-localfirst-architecture`)

## Product / requirement baseline

My AI Map is a native, local-first iOS application. The immediate release
requirement is to make its use of `UserDefaults` explicit in a bundled privacy
manifest without changing user-visible behaviour or claiming a completed App
Store submission. The user asked to continue the decomposed iOS architecture
and release plan.

## Architecture / runtime boundary baseline

- `ios-app/project.yml` is the checked-in XcodeGen source of truth.
- `Sources/MyAIMap/Resources/` is the resource boundary; generated
  `MyAIMap.xcodeproj` is ignored.
- The release renderer is the 2D constellation; legacy RealityKit sources are
  retained but are not mounted by the release map.
- Local catalog durability, release assistant/provider boundary, device QA,
  and delivery are documented stop-ship gates in `ios-app/docs/TECHNICAL_DEBT.md`.

## Evidence baseline

- Foundation simulator evidence: 71 passed, 0 failed in
  `/tmp/aimap-foundation-route-fix9-clean-token.xcresult` at commit `6896759`.
- The prior unsigned Release archive demonstrated that `PrivacyInfo.xcprivacy`
  was absent at `c287268`.
- Commit `b238c47` adds the required-reason manifest. `plutil -lint` passed,
  and an intermediate archive build logged `CpResource PrivacyInfo.xcprivacy`.
- A fresh full archive remains blocked by the local Xcode/CoreSimulator
  platform service and must be re-run before an archive-complete claim.

## Non-goals

- No signing, App Store Connect upload, TestFlight distribution, physical
  device approval, privacy-label submission, cloud sync, or catalog migration
  is authorized by this release-evidence slice.
