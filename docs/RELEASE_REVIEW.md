# Release Review Checklist

Last updated: 2026-06-10

Use this before every Vercel production deploy, TestFlight build, or App Store/TestFlight release candidate.

## Required Web Checks

Run from repo root:

```bash
npm run typecheck
npm run lint
npm test
npm run build
```

Expected:
- all commands exit 0
- no TypeScript errors
- no ESLint errors
- no failed Vitest tests
- Vite production build completes

## Required Visual Review

Review these screens at minimum:

| View | What to Check |
| --- | --- |
| Desktop overview | galaxy visible, labels readable, no panel overlap, Founder OS central node clear |
| Desktop hover | hovered tool is obvious, nearby labels appear smoothly, background nodes de-emphasize |
| Desktop selected tool | details panel opens, title/logo/category/summary visible, connections readable |
| Category pocket world | category opens into a larger world, nodes have breathing room, exit is clear |
| Search/filter | search result filters correctly, enter/focus behavior works |
| New tool input | liquid glass input accepts name/URL and classifier assigns category |
| Mobile overview | canvas is usable, bottom controls do not hide content |
| Mobile selected tool | bottom sheet is readable and scrollable |

Save screenshots to `screenshots/` when visual behavior changes. Use descriptive names:

```text
screenshots/<scope>-<viewport>-<state>.png
```

## Required Interaction Review

- Hover animation is smooth, not abrupt.
- Click opens correct tool details.
- Category switching is clear.
- Zoom into category does not trap the user.
- Escape exits pocket/detail states where supported.
- Camera dragging remains available after selection.
- Text does not overlap or become unreadable.
- Logos do not dominate or disappear.

## Required Data Review

- New tools have stable ids.
- Category ids match existing category definitions.
- Relation ids point to existing tools.
- Classifier tests cover new classification rules.
- Logo behavior is graceful if external logo service fails.

## Required iOS Checks

For simulator sanity:

```bash
cd ios-app
xcodegen generate
open MyAIMap.xcodeproj
```

Then in Xcode 26.5:

- Select the `My AI Map` scheme.
- Select an available iPhone simulator.
- Run the app.
- Confirm dark launch, visible 3D universe, category switching, selected-tool
  bottom sheet, and no major overlap.

For device/TestFlight:

- Apple Developer account active.
- Team ID known and selected on the `MyAIMap` target.
- Bundle id: `com.iliaturilia.myaimap`.
- App display name: `My AI Map`.
- SKU in App Store Connect: `myaimap-ios`.
- Signing works on a real device before Archive.
- Xcode Product -> Archive succeeds with a non-simulator destination.
- Distribute App -> App Store Connect -> Upload succeeds.
- App Store Connect processing completes.
- Internal tester receives and installs the build through TestFlight.

Required iOS screenshots/evidence:

- Overview with 3D universe visible.
- Focused category pocket world.
- Selected tool bottom sheet.
- Any permission prompts or onboarding if added.
- App Store screenshots for every device class App Store Connect requires at
  submission time.

Known iOS release risks:

- Developer account, Team ID, certificates, profiles, bundle registration, and
  TestFlight tester access are external Apple account state.
- The project currently targets iPhone and iPad, so public App Store submission
  may require iPad review coverage and screenshots.
- Personal TestFlight readiness is not the same as public App Store polish.

## Release PR Requirements

Every release PR must include:

- Summary of changes.
- Validation commands and results.
- Screenshots or visual notes for UI changes.
- Known risks.
- Rollback plan.
- Link to relevant plan/issue.

## Stop-Ship Conditions

Do not release when:

- Build/typecheck/lint/tests fail.
- Main 3D canvas is blank.
- Text overlaps major UI.
- Selected tool details can disappear.
- User cannot exit a focused category.
- Mobile view is unusable.
- App crashes on launch.
- Data relations point to missing ids.
