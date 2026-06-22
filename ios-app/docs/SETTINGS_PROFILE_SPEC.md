# SETTINGS_PROFILE_SPEC

Owner domain: the Account / Settings sheet and the settings-backed model fields.

Primary file: `UI/Settings/AccountSettingsSheet.swift`.
Backing state: `State/UniverseViewModel.swift`, `State/UniverseSelection.swift`,
`State/UniverseStore.swift`.
Related services: `Services/DeepSeekClient.swift`, `Services/KeychainStore.swift`,
`UI/Haptics/BrandHaptics.swift`, the assistant seam in
`State/UniverseViewModel.askAssistant`.

Do not use this spec to edit chat/input, tool detail, Add Tool, or universe
renderer internals beyond wiring settings to real state. Sibling specs own
those domains — see `INPUT_CHAT_SPEC.md`, `CHAT_AI_SPEC.md`, `ADD_TOOL_SPEC.md`,
`VISUALIZATION_SPEC.md`, `TOOL_DETAIL_SPEC.md`, `DETAIL_SCREEN_SPEC.md`,
`RIGHT_RAIL_SPEC.md`.

## Prime directive

**Every enabled control in Settings does something the user can perceive.** A
toggle that flips nothing, a picker that is read-only, or a field that exposes
plumbing the user shouldn't see is a bug. If a setting is not functional yet,
it is either removed or visibly disabled with copy that says why — never left
looking live.

---

## 1. AI assistant — API key is NOT user-facing

### Current state (main, `AccountSettingsSheet.swift:113-155`)

The "AI assistant" settings group shows the user a `SecureField` for a DeepSeek
API key, a "DeepSeek key set / not set" status row, **Save key** / **Clear**
buttons, and explanatory copy. `saveDeepSeekKey()` / `clearDeepSeekKey()`
(`:361-373`) write to / delete from `KeychainStore`
(`KeychainStore.deepSeekAPIKeyAccount`). At ask time,
`UniverseViewModel.askAssistant` (`:281-294`) calls `DeepSeekClient().reply(...)`
when `assistantUsesDeepSeek` (a key is present), otherwise falls back to the
local `UniverseAssistantCore`.

This makes the assistant backend a user-managed secret pasted into the UI. That
is a developer affordance leaking into the consumer surface.

### Required

- **Remove the DeepSeek API-key UI from normal user Settings.** Delete the
  `SecureField`, the key-status row, and the Save/Clear buttons from the default
  "AI assistant" settings group. Normal users never see or manage a raw API key.
- **Conceptual routing:** AI requests should route through an app-owned backend /
  service layer, so the app holds credentials and enforces quota — not the user.
  **No backend exists yet.** This spec defines the *seam*, not the backend:
  - Introduce an `AssistantBackend` abstraction (protocol or enum) with the
    intended cases `.local` (rule-based `UniverseAssistantCore`, the default and
    only offline path) and `.hosted` (future app-owned service — **not built**).
    `DeepSeekClient` becomes one concrete implementation behind that seam, never
    referenced directly from the UI.
  - `UniverseViewModel.askAssistant` keeps its current shape: compute the local
    reply first; only call a remote backend when one is configured; on any error
    or missing config, fall back to the local reply. This contract is already
    correct (`:268-296`) — only the *source* of the credential changes.
- **Interim behavior (until a backend exists):**
  - Default and shipping behavior is **local assistant** for every user.
  - DeepSeek remains reachable **only via a debug/developer key path**, gated so
    it cannot appear in a normal build's Settings.
- **Debug-only key path (if kept):** gate the DeepSeek key entry behind a
  developer/debug mode. Acceptable gates: compile out of release with
  `#if DEBUG`, and/or hide behind a hidden developer-mode flag
  (`UserDefaults` key, e.g. `developer.modeEnabled`) that is off by default and
  not toggleable from the consumer Settings UI. The Keychain plumbing
  (`KeychainStore`, `DeepSeekClient`) stays — it is sound — but its only entry
  point is the debug surface.

### Affected files

- `UI/Settings/AccountSettingsSheet.swift` — remove the AI-assistant key group
  from the normal path; if a debug entry is kept, wrap it in `#if DEBUG` /
  developer-mode gate.
- `State/UniverseViewModel.swift` — introduce the `AssistantBackend` seam;
  `askAssistant` selects backend via that seam rather than "key present?".
- `Services/DeepSeekClient.swift`, `Services/KeychainStore.swift` — unchanged
  logic; now only reachable through the debug path / future backend.

### Acceptance

- A release build's Settings shows no API-key field and no key status/Save/Clear.
- A fresh user gets local-assistant answers with zero configuration.
- With no key configured, `askAssistant` produces a local reply and never errors
  to the user.
- In a DEBUG / developer-mode build, the DeepSeek key path is still reachable for
  testing, and a configured key still routes through `DeepSeekClient` with local
  fallback on error.

---

## 2. Plan / subscription / usage (placeholder, no billing)

### Current state

No subscription, plan, or usage surface exists anywhere in Settings. There is no
`SubscriptionState`, no usage counter, and no upgrade affordance.

### Required

Add an **Account / Plan** settings group that a normal user sees, built as
**placeholder UI only — no real billing, no StoreKit, no network.** Spec a
local placeholder model:

- `SubscriptionState` (enum or small struct), e.g. `.free` (default) with room
  for `.pro`. Persisted via `UniverseStore` like `renderMode` / `hapticsEnabled`.
- A usage placeholder: `aiRequestsUsed` / `aiRequestsLimit` (e.g. a free-tier
  monthly cap), with a derived `aiRequestsRemaining`. These are local counters
  for layout only until a backend enforces real quota; increment `aiRequestsUsed`
  on each `askAssistant` send so the number visibly moves.

The group displays:
- **Plan** — current plan name (e.g. "Free").
- **Usage limit** — the cap (e.g. "20 AI requests / month").
- **Remaining AI requests** — `aiRequestsRemaining`, updates as the user asks.
- **Upgrade** — a button styled as a real CTA that, for now, shows a "Coming
  soon" / placeholder state. No purchase, no paywall navigation yet.

Mark the whole group clearly as placeholder in code comments; it must not imply a
working purchase.

### Affected files

- `UI/Settings/AccountSettingsSheet.swift` — new Account/Plan settings group.
- `State/UniverseViewModel.swift` — `subscriptionState`, usage counters,
  `aiRequestsRemaining`; increment usage in `askAssistant`.
- `State/UniverseSelection.swift` — `SubscriptionState` type (and any usage
  value type) alongside the other settings enums.
- `State/UniverseStore.swift` — persist subscription + usage counters.

### Acceptance

- A normal user sees Plan, usage limit, remaining requests, and an Upgrade CTA.
- Remaining requests decrements when the user sends an Ask-AI message.
- Tapping Upgrade does not attempt a purchase; it shows a placeholder state.
- No StoreKit / billing code is introduced.

---

## 3. Visualization — must actually switch 2D Graph ⇄ 3D Spatial

### Current state (main)

The Visualization group (`AccountSettingsSheet.swift:71-84`) renders one row per
`UniverseRenderMode` (`graph2D`, `spatial3D` — `UniverseSelection.swift:24-58`)
and sets `model.renderMode`. `renderMode` persists via `UniverseStore`
(`UniverseViewModel.swift:24-29, 63-69`) and drives the live renderer (see
`VISUALIZATION_SPEC.md`). `3D Spatial` is labelled **Experimental** via
`renderMode.isExperimental` (`AccountSettingsSheet.swift:293-300`). This part is
**already wired correctly** — selecting a row swaps the renderer live and the
choice survives relaunch.

The legacy `VisualizationStyle` enum (Atlas Overlay / Kinetic Pockets / N Stage /
Orbital Glass — `UniverseSelection.swift:60-128`) still exists on the model
(`UniverseViewModel.swift:30`, `visualizationStyle`). These presets "change
little/nothing" the user can perceive and are the controls the prime directive
forbids.

### Required

- Keep the `UniverseRenderMode` rows as the only enabled visualization control:
  `2D Graph` (default) and `3D Spatial` (Experimental). Verify the wiring above
  on device.
- **Remove or quarantine `VisualizationStyle` as a user setting.** It is not
  exposed in Settings today and must stay that way. The enum may remain as
  internal 3D renderer tuning values only (its `nodeScale` / `motionAmplitude`
  multipliers), clearly marked experimental/internal. Do not add any enabled
  control that selects it.

### Affected files

- `UI/Settings/AccountSettingsSheet.swift` — Visualization group (verify only;
  no preset rows).
- `State/UniverseViewModel.swift` — `renderMode` (keep), `visualizationStyle`
  (mark internal/experimental; remove if unused after audit).
- `State/UniverseSelection.swift` — `UniverseRenderMode` (keep),
  `VisualizationStyle` (internal-only).
- See `VISUALIZATION_SPEC.md` for renderer-side ownership.

### Acceptance

- Tapping `2D Graph` selects the graph renderer; tapping `3D Spatial` selects the
  RealityKit renderer and shows it as Experimental.
- Selection persists across model reloads / app relaunch.
- No enabled visualization control exists that has no visible effect.

---

## 4. Language — label "Follow device language"

### Current state (`AccountSettingsSheet.swift:86-102`, `UniverseSelection.swift:132-146`)

`AppLanguage` has `.system` / `.english` / `.russian`. The Language picker is
**disabled** (`.disabled(true)`, `.opacity(0.58)`) with footnote copy: "System
follows your device language. Manual language selection is coming soon." The
`.system` case's `title` is `"System"`.

### Required

- Relabel the default option from **"System"** to **"Follow device language"**
  (the `AppLanguage.system` `title`).
- Keep the picker disabled until manual language selection is actually
  implemented — it is correctly disabled today, which satisfies the prime
  directive (a non-functional setting is visibly disabled, not fake-live).

### Affected files

- `State/UniverseSelection.swift` — `AppLanguage.system.title` →
  "Follow device language".
- `UI/Settings/AccountSettingsSheet.swift` — Language group copy stays
  consistent with the new label.

### Acceptance

- The default language option reads "Follow device language".
- The picker remains disabled with copy explaining manual selection is coming.

---

## 5. Haptics — must actually enable/disable haptics

### Current state (main)

The Haptics `Toggle` binds to `model.hapticsEnabled`
(`AccountSettingsSheet.swift:104-111`). `hapticsEnabled` persists via
`UniverseStore` (`UniverseViewModel.swift:32-37, 57, 63-69`) and is pushed into
`BrandHaptics.isEnabled` on appear and on change in `RootShell.swift:103-108`
and `UniverseMapView.swift:140-145`. `BrandHaptics.fire/prepare` early-return
when `!isEnabled` (`BrandHaptics.swift:45,65`), and `CoreHapticsEngine` /
`PressBounce` honor the same flag. This is **already wired correctly** end to
end — the toggle genuinely silences all haptics.

> Note: the footnote under the Haptics toggle (`AccountSettingsSheet.swift:107`)
> describes the assistant's missing-tool behavior, not haptics — leftover copy.
> Fix the copy to describe haptics, or move that sentence to the AI-assistant
> context.

### Required

- Keep the toggle bound to `model.hapticsEnabled`; confirm `BrandHaptics.isEnabled`
  tracks it on launch and on change.
- Correct the mismatched footnote copy so it describes the haptics behavior.

### Affected files

- `UI/Settings/AccountSettingsSheet.swift` — toggle (verify), footnote copy fix.
- `UI/Haptics/BrandHaptics.swift`, `State/UniverseViewModel.swift`,
  `State/UniverseStore.swift`, `RootShell.swift`, `Universe/UniverseMapView.swift`
  — wiring (verify only).

### Acceptance

- Turning Haptics off silences taps, selections, pocket-open, and success/error
  feedback app-wide; turning it on restores them.
- The setting persists across relaunch.
- Footnote copy describes haptics, not the assistant.

---

## 6. Per-row settings table (current state → required → acceptance)

| Row | Current state | Required | Affected files | Acceptance |
| --- | --- | --- | --- | --- |
| DeepSeek API key field | Live `SecureField` + Save/Clear in normal Settings | Remove from normal UI; debug/developer-gated only; route AI via backend seam | `AccountSettingsSheet.swift`, `UniverseViewModel.swift`, `DeepSeekClient.swift`, `KeychainStore.swift` | No key field in release Settings; local default; DeepSeek only via DEBUG/dev mode |
| Plan / subscription | Does not exist | Add placeholder `SubscriptionState` (`.free` default) | `AccountSettingsSheet.swift`, `UniverseViewModel.swift`, `UniverseSelection.swift`, `UniverseStore.swift` | Plan name visible; no billing |
| Usage limit / remaining requests | Does not exist | Local usage placeholder; decrement on Ask-AI | same as above | Remaining count shows and decrements on send |
| Upgrade | Does not exist | Placeholder CTA, "Coming soon" | `AccountSettingsSheet.swift` | Tapping does not purchase |
| Visualization (2D/3D) | Wired to `renderMode`; persists; 3D = Experimental | Keep; verify; no `VisualizationStyle` control | `AccountSettingsSheet.swift`, `UniverseViewModel.swift`, `UniverseSelection.swift` | Switches renderer live + persists; no dead preset control |
| Language | Disabled picker; `.system` title = "System" | Relabel `.system` → "Follow device language"; stays disabled | `UniverseSelection.swift`, `AccountSettingsSheet.swift` | Default reads "Follow device language"; picker disabled w/ copy |
| Haptics | Toggle → `hapticsEnabled` → `BrandHaptics.isEnabled`; persists | Keep; fix mismatched footnote copy | `AccountSettingsSheet.swift` (+ wiring files) | Toggle silences/restores all haptics; persists |
| Load sample universe | Live (`loadSampleUniverse()`) | Keep | `AccountSettingsSheet.swift` | Loads sample tools |
| Reset universe | Live; gated on `hasStoredData` | Keep | `AccountSettingsSheet.swift` | Confirm dialog; clears added tools |
| Hidden tools restore | Live; shown when `removedTools` non-empty | Keep | `AccountSettingsSheet.swift` | Restores hidden tool |
| History tab | Live activity log | Keep | `AccountSettingsSheet.swift` | Shows/opens recent activity |

---

## 7. Settings QA (run on simulator + a small device)

- [ ] Release build: no DeepSeek API-key field anywhere in Settings.
- [ ] Fresh install: assistant answers locally with no configuration; no error.
- [ ] DEBUG/dev build: DeepSeek key path reachable; configured key routes through
      `DeepSeekClient` with local fallback on error.
- [ ] Plan group shows Plan, usage limit, remaining requests, Upgrade CTA.
- [ ] Remaining AI requests decrements after sending an Ask-AI message.
- [ ] Upgrade tap shows placeholder; no purchase attempt.
- [ ] `2D Graph` switches to graph renderer; `3D Spatial` switches to spatial and
      shows Experimental.
- [ ] Renderer selection survives app relaunch.
- [ ] No enabled visualization control without a visible effect (no
      `VisualizationStyle` preset rows).
- [ ] Default language option reads "Follow device language"; picker disabled.
- [ ] Haptics OFF silences all feedback; ON restores it; survives relaunch.
- [ ] Haptics footnote describes haptics, not the assistant.
- [ ] Build green; xcresult `failedTests == 0`, `passedTests` ≥ prior count.
