# iOS release evidence and catalog durability plan

## Outcome and scope

Make the existing privacy-manifest correction independently reviewable and
reproducibly verifiable in a Release archive where the host permits it. Record
what the evidence does and does not prove, then prepare the next stop-ship
implementation plan for local catalog durability.

This is a release/distribution boundary, so it is intentionally separate from
the completed local-first rendering foundation. It does **not** authorize a
claim that the application is ready for App Store submission.

## Aegis visibility

The manifest crosses an Apple release boundary while the previous archive
validation is blocked by host infrastructure. The plan keeps the checked-in
resource as the only source change, uses an isolated worktree, and separates
archive evidence from signing, TestFlight, and device evidence.

## Plan basis

- User request: continue the decomposed native iOS architecture/release plan.
- Current requirement authority:
  `ios-app/docs/TECHNICAL_DEBT.md` (release/privacy and delivery gates),
  `ios-app/docs/ARCHITECTURE.md` (release renderer and evidence boundary), and
  `ios-app/docs/QA_REGRESSION_CHECKLIST.md` (device and build matrix).
- Apple documentation: a privacy manifest must declare accessed required-reason
  APIs; `UserDefaults` is one such API, and `CA92.1` permits app-only
  read/write use. See
  <https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api>
  and
  <https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons?language=objc>.

## BaselineUsageDraft

- Required baseline refs: `AGENTS.md`, `.agent/INSTRUCTIONS.md`, iOS project
  context/state/architecture/QA/debt documents, `project.yml`, current source,
  and Apple required-reason documentation.
- Acknowledged before plan refs: all listed local sources and the Apple docs.
- Cited in plan refs: all listed sources.
- Missing refs: App Store Connect account configuration, signing assets, and
  physical devices are intentionally external.
- Decision: continue.

## Requirement Ready Check

- Requirement source refs: user request plus `TECHNICAL_DEBT.md` release gates.
- Goals and scope refs: this plan's Outcome and scope.
- User / scenario refs: a local-first iOS user launches and uses saved catalog
  state without silently sending it to a provider.
- Acceptance / verification criteria refs: valid plist, generated project
  includes it, Release archive contains it, and the risk register is accurate.
- Open blocker questions: host Xcode platform service may prevent archive
  validation; signing and TestFlight credentials are external.
- Decision: ready.

## TDD Route

- Mode: off.
- Decision: skipped.
- Strict authority: not applicable.
- Test posture: configuration parsing, resource-copy inspection, and
  post-change Release archive verification.
- Reason: this slice adds a declarative bundle resource, not executable logic.
- Verification: `plutil`, XcodeGen resource inclusion, and archive inspection.

## Change necessity and architecture integrity

- User-visible need: release builds must honestly declare the app's persisted
  `UserDefaults` use to Apple.
- No-change option: not sufficient; the prior archive contained no privacy
  manifest while the source uses `UserDefaults`.
- Minimum change boundary: one resource at
  `ios-app/Sources/MyAIMap/Resources/PrivacyInfo.xcprivacy`.
- Decision: docs/config-only.
- Canonical owner/contract: the bundled privacy manifest; no runtime fallback,
  new service, or duplicate owner is introduced.
- Compatibility boundary: `UserDefaults` keys and local behavior remain
  unchanged. The generated `.xcodeproj` is regenerated only for validation.
- Retirement boundary: replace the prior “privacy archive evidence deferred”
  statement only after a fresh archive confirms the resource. No source path is
  removed in this slice.

## Files

| File | Change / authority |
| --- | --- |
| `ios-app/Sources/MyAIMap/Resources/PrivacyInfo.xcprivacy` | Existing privacy declaration under review; only runtime-adjacent change. |
| `ios-app/project.yml` | Read-only XcodeGen source confirming automatic resource inclusion. |
| `ios-app/docs/TECHNICAL_DEBT.md` | Update evidence/risk wording only after verification. |
| `ios-app/docs/ARCHITECTURE.md` | Record archive evidence boundary only after verification. |
| `docs/aegis/work/2026-07-27-ios-release-readiness/*` | Checkpoint, evidence, and reflection record. |
| `docs/aegis/plans/2026-07-27-ios-release-evidence-and-catalog-durability.md` | This execution plan. |

## Task batches

### Batch 1 — validate the existing source correction

1. Have a fresh independent reviewer inspect `c287268..b238c47`, the manifest
   schema, app-side `UserDefaults` use, `project.yml`, and the baseline docs.
   The reviewer must report findings first and distinguish code defects from
   evidence gaps.
2. If review finds Critical or Important issues, repair only the manifest or
   its evidence documentation in this worktree, then re-run review. If it
   passes, preserve `b238c47` as the scoped implementation commit.
3. Run `plutil -lint` on the manifest, run `xcodegen generate`, and inspect the
   generated PBX project to prove the resource is copied. Remove only the
   generated ignored project after capturing the result.

Expected result: valid manifest with exactly `UserDefaults` / `CA92.1`, no
tracking or collected-data declaration, and generated resource inclusion.

### Batch 2 — restore and use the archive gate

1. Diagnose the host without modifying application source: check the Xcode
   platform/runtime list and CoreSimulator service state. Record exact failure
   if unavailable; do not convert an infrastructure error into an app defect.
2. Once the platform service is healthy, create a fresh generated project and
   perform an unsigned `Release` archive to a unique `/private/tmp` path using
   `CODE_SIGNING_ALLOWED=NO`.
3. Inspect the archive's app bundle for `PrivacyInfo.xcprivacy`, parse it with
   `plutil`, inspect its `Info.plist`, and retain concise command output or an
   xcresult/log reference. Delete disposable derived data/archive only after
   extracting the evidence needed for the work record.

Expected result: archive contains the same manifest source; otherwise retain
the stop-ship gate and report the exact blocker.

### Batch 3 — evidence and next stop-ship plan

1. Update `TECHNICAL_DEBT.md` and `ARCHITECTURE.md` only with the precise
   result: validation passed, blocked by host infrastructure, or manifest
   defect found. Do not claim signing, TestFlight, physical-device, or privacy
   label completion.
2. Write the follow-on catalog durability implementation plan from the existing
   local-first platform design: versioned Application Support document,
   atomic migration, recovery backup, export/import, reset, relaunch tests,
   and a user-visible recovery choice. It is planning only; it must not alter
   persisted user data.
3. Review documentation changes, update the Aegis checkpoint/evidence record,
   run `git diff --check`, and commit the scoped evidence docs separately from
   `b238c47`.

## Verification commands

```bash
plutil -lint ios-app/Sources/MyAIMap/Resources/PrivacyInfo.xcprivacy
xcodegen generate
rg -n 'PrivacyInfo\.xcprivacy' ios-app/MyAIMap.xcodeproj/project.pbxproj
xcrun simctl list devices available
xcodebuild -project ios-app/MyAIMap.xcodeproj -scheme MyAIMap \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/aimap-release-dd \
  -archivePath /private/tmp/aimap-release-audit.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
plutil -p '/private/tmp/aimap-release-audit.xcarchive/Products/Applications/My AI Map.app/PrivacyInfo.xcprivacy'
git diff --check
```

## Review gates and drift / rewind rules

- Independent spec review before treating the existing manifest commit as
  integrated; code-quality review follows if the spec review is clean.
- Critical or Important finding: stop the next batch, repair the minimal owner,
  and repeat the applicable review/verification.
- If a proposed change adds provider traffic, modifies catalog data, changes
  signing/account state, or creates a new runtime owner, stop and open a
  separate plan.
- If the host blocks archive validation, record `needs-verification`; do not
  retry indefinitely or claim an application build failure.

## Risks and non-goals

- A valid manifest does not prove App Store privacy-label accuracy or review
  acceptance.
- An unsigned archive proves resource bundling, not signing, entitlements,
  provisioning, upload, TestFlight processing, or device performance.
- Catalog durability remains a stop-ship item until its separate implementation
  and migration/relaunch evidence exist.

## Plan pressure and complexity check

- Owner / contract / retirement: one declarative resource owns this change;
  no duplicate runtime logic or retirement is introduced.
- Verification scope: config syntax plus resource-in-archive inspection; wider
  release gates remain explicit.
- Task executability: each batch can stop independently with a recorded result.
- Pressure result: proceed.
- Artifact class: declarative plist and release documentation.
- Current/projected pressure: low; no maintained runtime source file grows.
- Recommendation: edit-in-place only if review identifies an incorrect
  declaration; otherwise no additional code surface.

## Execution Readiness View

- Intent Lock: validate privacy declaration and archive evidence; plan, but do
  not implement, catalog durability.
- Scope Fence: no user-data migration, provider changes, signing, upload, or
  external account operations.
- Baseline Lock: `project.yml` and checked-in resources are authoritative;
  generated Xcode files and prior historical archive are evidence only.
- Approved Behavior: local `UserDefaults` remains local; no runtime behavior
  changes.
- Owner / Contract Constraints: exactly one `PrivacyInfo.xcprivacy` resource,
  no duplicate manifests or runtime workarounds.
- Compatibility Boundary: preserve bundle id, deployment target, target
  families, storage keys, and release renderer.
- Retirement Boundary: the previous deferred-privacy evidence is retired only
  by fresh archive evidence, never by assertion.
- Test Obligations: plist parse, XcodeGen inclusion, archive resource parse,
  plus targeted regression only if a reviewer identifies code impact.
- Review Gates: independent spec then code-quality review; no unresolved
  Critical/Important findings before advancing.
- Drift / Rewind Rules: stop for a new owner/data/signing boundary or host
  blocker; record rather than scope-creep.
- Evidence Required Before Completion: reviewed manifest, validation results,
  archive outcome or reproducible infrastructure blocker, documentation
  updates, and catalog plan.
- Advisory Boundary: method-pack execution guidance only; not an Apple
  GateDecision, PolicySnapshot, or completion authority.
