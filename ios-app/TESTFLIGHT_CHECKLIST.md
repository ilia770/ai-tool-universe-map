# My AI Map - personal TestFlight checklist

This is the shortest path from the native iOS project to a private build
on your own iPhone, then later to an App Store release. The project is
configured for:

- App name: `My AI Map`
- Bundle id: `com.ilyatur.myaimap`
- SKU: `myaimap-ios`
- Minimum iOS: 18.0
- Xcode target: Xcode 26.5 installed locally

## Local machine

- Install full Xcode 26.5 from the App Store or Apple Developer downloads.
- Select it:

  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```

- Generate the project:

  ```bash
  cd ios-app
  xcodegen generate
  open MyAIMap.xcodeproj
  ```

Do not edit `MyAIMap.xcodeproj` directly; it is generated from
`ios-app/project.yml`.

## Apple account

- Enroll in the Apple Developer Program with the Apple ID that will own the app.
- In Xcode, sign in with that Apple ID.
- Record the Team ID from Apple Developer account membership.
- In the `MyAIMap` target, set Team to that account/team.
- Keep bundle id as `com.ilyatur.myaimap`.
- Let Xcode manage signing for the first personal TestFlight build unless
  manual signing is specifically needed later.
- If App Store Connect says the bundle id is unavailable, stop and choose a
  new reverse-DNS id before archiving.

Blocker until done: no Developer Program team means no real TestFlight upload.

## Simulator sanity check

Before a personal device/TestFlight attempt, run a simulator build from Xcode:

- Select the `My AI Map` scheme.
- Select an iPhone simulator available in Xcode 26.5.
- Press Cmd+R.
- Verify:
  - app launches in dark mode
  - 3D universe appears
  - category chips switch pocket worlds
  - bottom sheet updates selected tool
  - no obvious text overlap or blank 3D scene

## First device run

- Connect a trusted iPhone or select a device registered to the team.
- Select the `My AI Map` scheme and the device.
- Confirm Signing & Capabilities shows:
  - Team: your Apple Developer team
  - Bundle Identifier: `com.ilyatur.myaimap`
  - Signing Certificate: Apple Development
- Run `My AI Map`.
- Verify:
  - app launches in dark mode
  - 3D universe appears
  - category chips switch pocket worlds
  - bottom sheet updates selected tool
  - haptics fire on category/tool taps on device

If device signing fails, fix Team ID, bundle id registration, provisioning
profile, or device registration before attempting Archive.

## TestFlight upload

- In App Store Connect, create app:
  - Name: `My AI Map`
  - Bundle ID: `com.ilyatur.myaimap`
  - SKU: `myaimap-ios`
- In Xcode, select `Any iOS Device` or a real device, not a simulator.
- Product -> Archive.
- Organizer opens after archive.
- Distribute App -> App Store Connect -> Upload.
- Use automatic signing unless the account requires manual profiles.
- Wait for App Store Connect processing.
- Add yourself as an internal tester.
- Install from the TestFlight app on your iPhone.

## Screenshots for review

Capture enough screenshots to prove the build is real and reviewable:

- Simulator or device launch screen / overview.
- 3D universe overview with visible nodes.
- Focused category pocket world.
- Selected tool bottom sheet.
- Any settings, onboarding, or permission prompts if added later.

For a later public App Store submission, prepare App Store Connect screenshots
for the required device classes shown in App Store Connect at submission time.

## Before public App Store

- Confirm the app icon is final enough for review.
- Add privacy nutrition labels. If the app remains fully local and no tracking
  SDK is added, document that clearly during App Store Connect setup.
- Add support URL and marketing URL.
- Add app description, keywords, age rating, category, copyright, and review
  notes.
- Confirm whether iPad support should remain enabled (`TARGETED_DEVICE_FAMILY`
  is currently `1,2`) or become iPhone-only before submission.
- Run the release review checklist in `docs/RELEASE_REVIEW.md`.

## Known risks

- App Store Connect account/team, signing certificates, provisioning profiles,
  and tester setup are external account state and cannot be solved in code.
- `project.yml` currently targets iPhone and iPad; that increases screenshot and
  review coverage for a public release.
- Native iOS visuals are still in active development; a build can be personal
  TestFlight-ready before it is public App Store-polished.
- App Store screenshot requirements can change. Treat App Store Connect's
  current submission UI as the final source of truth.
