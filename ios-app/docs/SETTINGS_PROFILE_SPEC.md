# SETTINGS_PROFILE_SPEC

Owner: Codex. File: `UI/Settings/AccountSettingsSheet.swift` (+ the settings
fields on `UniverseViewModel`). Do NOT edit scene/chat/rail rendering here
beyond reading the render-mode setting. **Rule: anything not actually
implemented must be DISABLED or REMOVED, never a dead control.**

## Visualization setting (currently does nothing → wire it)
- Replace the inert control with the **render-mode** segmented control from
  `VISUALIZATION_SPEC.md`: **3D Spatial / 2D Graph**. Changing it swaps the
  renderer live and persists (`UniverseStore`).
- The legacy `VisualizationStyle` presets (Atlas/Overlay/Kinetic/Pockets) that
  "change little or nothing":
  - **Preferred:** retire them — collapse into the 3D/2D mode toggle.
  - **If kept:** each preset must produce a *visibly distinct* scene; otherwise
    DISABLE the ones that don't and label why. No four-identical-looking presets.

## Language setting
- "System" is unclear → label it **"System (follows device language)"** with a
  one-line caption.
- Options: **System · English · Russian.**
- If localization is implemented, selecting English/Russian must actually switch
  UI strings (via a `LocalizationManager` / `environment(\.locale)` override).
- **If localization is NOT yet implemented:** keep only "System", and DISABLE
  English/Russian with a "coming soon" note — do not ship a language picker that
  does nothing.

## Haptics setting
- On/off must be perceptibly different: OFF = `BrandHaptics.isEnabled = false`
  → zero haptics anywhere (verify all fire sites respect the flag).
- The "feels the same" bug = some haptics bypass the flag. Audit every
  `BrandHaptics.fire*` call to gate on `isEnabled`.
- Caption: "Subtle taps on selection and navigation."

## Universe management (existing, keep)
- **Load sample universe** — ok, keep (gated/idempotent).
- **Reset universe** — destructive, confirmation, gated on `hasStoredData`. Keep.
- Saved / switchable universes = **deferred** (note as future, do not build now).

## Disable-if-unimplemented policy (apply across the sheet)
For every control: if it has no real effect today, either make it functional
this pass or render it `.disabled(true)` with a short "not available yet"
caption. A visible control that does nothing is worse than no control.

## Acceptance criteria
- Visualization control actually switches renderer (3D⇄2D) and persists.
- Presets either visibly differ or are removed/disabled.
- Language: "System" explained; EN/RU either localize or are disabled-with-note.
- Haptics OFF → genuinely no haptics anywhere; ON → present. Audited.
- No dead/no-op control remains enabled.

## Manual QA
1. Toggle Visualization 3D⇄2D → scene swaps, persists across relaunch.
2. Each visualization preset (if kept) visibly changes the scene; else gone/disabled.
3. Set Russian → UI localizes (or option is disabled with note).
4. Haptics OFF → no taps on selection/nav; ON → taps return.
5. Reset disabled when empty, enabled with data; confirm dialog works.
