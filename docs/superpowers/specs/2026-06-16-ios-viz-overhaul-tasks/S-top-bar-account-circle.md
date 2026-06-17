# Top bar — single account circle

**Phase:** S · **Lens:** shell

## Goal (1-2 lines)
Strip the home top bar to nothing but a single account-circle avatar top-right that opens the Account/Settings screen. Remove the sparkles tile, the "N tools" pill, and any "Research → …" text so the universe owns the screen.

## Files (create / modify — REAL paths under ios-app/Sources/MyAIMap)
- modify `Universe/UniverseScreen.swift` — gut `header` (L141-168); keep only the trailing `Spacer()` + `AccountButton`. `AccountButton` (L206-226) already exists and already opens `settingsPresented` — reuse as-is.
- modify `State/L10n.swift` — drop any title/"Research" string only if it is now unreferenced (the count pill is hard-coded `"\(...tools.count) tools"`, not L10n — just delete that view).

## Approach (bullet steps)
- Delete the `sparkles` `Image` tile and the `"\(UniverseSeed.tools.count) tools"` capsule from `header`.
- Collapse `header` to `HStack { Spacer(); AccountButton { BrandHaptics.fire(.medium); settingsPresented = true } }`.
- Keep `.brandAnimation(BrandMotion.flow, value: model.selection.activeCategory)` only if the avatar tint still tracks category color; otherwise remove to avoid a dead animation.
- Verify the avatar keeps its 44pt min hit target (frame is 42 + glass padding — confirm ≥44 tappable) and stays clear of the safe-area/notch.

## Interface / contract (Swift signature sketch — signatures only)
```swift
private var header: some View              // now: Spacer + AccountButton only
struct AccountButton: View { let action: () -> Void }   // unchanged
```

## Tests (what to assert; reference real Tests/MyAIMapTests conventions)
- New `ChromeTopBarTests.swift` (mirror `ChromeSnapshotTests`/`SettingsSheetTests` `ImageRenderer` pattern): `UniverseScreen` renders non-nil and ≥0 width with the trimmed header.
- Assert no count/title string is emitted: render `AccountButton` in isolation, confirm non-nil; keep an `accessibilityLabel == L10n.accountAccessibilityLabel(language)` check (already wired) so the avatar stays the only labeled top-bar control.

## Done criteria (checklist)
- [ ] No app icon/title, no "N tools" pill, no "Research" text in the top bar.
- [ ] Account circle is top-right, ≥44pt tappable, opens Settings.
- [ ] `accountAccessibilityLabel` still present; no dead `brandAnimation`.
- [ ] Snapshot test green; existing `ChromeSnapshotTests` still pass.

## Dependencies (other tasks)
- Feeds `S-account-settings-screen` (the sheet it opens). No blocker — `AccountButton` + `settingsPresented` already exist.
