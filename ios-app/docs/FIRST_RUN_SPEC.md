# FIRST_RUN_SPEC

First-launch and empty-universe experience for the iOS app (SwiftUI, iOS 26).

This spec defines what a brand-new user sees on cold start, how the
lightweight onboarding overlay behaves, and how the empty-universe state
must read as clear and actionable. It is implementation-pointed: it names
the real files and symbols that must change.

---

## 1. Implemented state

### Cold start lands on the map, not an open question
- `MyAIMapApp` (`Sources/MyAIMap/MyAIMapApp.swift`) mounts `RootShell` with
  the app's root shell. Sample/seed loading remains behind UI-test launch
  arguments (`-uitestSampleUniverse`, `-uitestSeedChat`).
- `RootShell` (`Sources/MyAIMap/RootShell.swift`) opens the first-run and
  empty-state experience on the universe/map surface. Returning users can
  still switch directly between Map and Ask AI using the top route pills.

### The chat starter is no longer the first-run surface
- `ChatScreen` (`Sources/MyAIMap/UI/Search/ChatScreen.swift`): when
  `model.assistantMessages.isEmpty`, the transcript shows `ChatStarterPanel`,
  a large hero reading **"What are you trying to build?"** plus the subtitle
  *"Ask for a workflow or a tool recommendation. Your answers can become a
  living map of the stack."* and three starter prompt chips
  (`Design an app`, `Build an MVP`, `Track growth`).
- This remains valid once the user intentionally chooses **Ask AI**, but it is
  no longer the cold-start explanation for a new user.

### The Map is always reachable
- `RootShell.RootSurfaceSwitch`: the **Map** pill is always enabled. Empty and
  low-tool universes are valid map destinations and show the empty-state card
  instead of trapping the user in chat.
- `UniverseOverlayView.emptyStateCard`
  (`Sources/MyAIMap/Universe/UniverseOverlayView.swift`) already implements a
  good empty-universe card: a `sparkles` glyph, **"Your universe is empty"**,
  *"Add the AI tools you use — each one becomes a planet you can fly
  between."*, an **Add your first tool** button, and a **Load a sample
  universe** link (calls `model.loadSampleUniverse()`). It is reachable from
  first launch via the map surface.

### No onboarding persistence exists
- `UniverseStore` (`Sources/MyAIMap/State/UniverseStore.swift`) persists only
  `customTools`, `hiddenToolIDs`, `renderMode`, `hapticsEnabled`. There is
  **no** `hasSeenOnboarding` / first-run flag anywhere. There is therefore no
  way today to distinguish a true first run from a returning empty user.
- `UniverseViewModel.isUniverseEmpty` returns `visibleAllTools.isEmpty`;
  `loadSampleUniverse()` populates from `UniverseSeed.tools` and persists.

### Summary of the gap
This spec is retained as the contract for the first-run experience: the app
must start with map-first clarity, keep the map reachable, and avoid making
the chat starter the product explanation.

---

## 2. Required behavior

### 2.1 First launch opens to the MAP (or a clear map preview)
- On true first run, `RootShell` must open on the **universe** surface
  (`surface = .universe`), not chat — OR render a non-interactive map preview
  behind the onboarding overlay. The map (even empty) communicates the
  product ("your tools become planets") far better than an open question.
- The map surface must be reachable regardless of tool count. Empty and
  low-tool universes should show the `emptyStateCard` or the current map
  state, never a disabled route.

### 2.2 Lightweight one-screen onboarding overlay
A single, dismissible overlay shown **only on true first run** (see 2.4),
layered above the map/preview. It is one screen — no carousel, no paging.

**Exact copy:**

- Title: **AI Universe**
- Body: **AI Universe maps your tools into branches. Add tools, ask AI what
  to use, and explore your stack visually.**

**Three clear actions** (primary stacked buttons, top to bottom):

1. **Ask AI** — opens the chat surface focused on the composer.
2. **Add Tool** — opens the Add Tool sheet.
3. **Explore Map** — dismisses the overlay onto the (empty) map surface.

Each action also dismisses the overlay and sets the first-run flag (2.4).
A subtle "Skip" / tap-the-scrim affordance behaves identically to
**Explore Map** (lands on the map, flag set).

### 2.3 Action targets (exact wiring)
The overlay is owned by `RootShell` (it owns the surface switch and already
owns the Add Tool and Account sheets), so the three actions reuse existing
`RootShell` intents:

| Action | Target | Implementation hook |
| --- | --- | --- |
| Ask AI | Chat surface, composer focusable | set `surface = .chat`; reuse the existing `showChat()` path. Optionally pre-focus the `SearchDock` composer. |
| Add Tool | Add Tool sheet | call `presentAddTool(draft: nil)` (existing in `RootShell`). |
| Explore Map | Empty map surface | set `surface = .universe` through the existing `showUniverse()` path. |

### 2.4 Dismissal and persistence
- Add a persisted first-run flag. Extend `UniverseStore` with a
  `hasCompletedOnboarding` boolean (key e.g. `universe.hasSeenOnboarding.v1`)
  and surface it on `UniverseViewModel` (e.g. `hasSeenOnboarding` +
  `func markOnboardingSeen()` that persists). Follow the existing
  `hapticsEnabled` load/save pattern in `UniverseStore.load()/save()`.
- The overlay shows when `!model.hasSeenOnboarding`. **Any** of the three
  actions, the Skip control, or a scrim tap calls `markOnboardingSeen()` so
  it never shows again on subsequent launches.
- The flag is independent of `isUniverseEmpty`: a user who completes
  onboarding but adds nothing must NOT see the overlay again — they see the
  empty-universe state (2.5) instead.

### 2.5 Empty-universe state must be clear + actionable
After onboarding (or for any returning user with an empty universe), the map
surface must show a clear empty state — reuse and elevate the existing
`UniverseOverlayView.emptyStateCard`:

- Keep the central **Founder OS** core node visible as the anchor of the
  empty universe (the core node is the product's spine — invariant: Founder OS
  is the central core). The card should make clear the user is building
  *around* that core.
- Card copy (current copy is acceptable; keep or refine):
  - Title: **Your universe is empty**
  - Body: **Add the AI tools you use — each one becomes a planet you can fly
    between.**
- Two actions, already implemented, must remain:
  - Primary: **Add your first tool** → Add Tool sheet.
  - Secondary: **Load a sample universe** → `model.loadSampleUniverse()`
    (loads the Founder OS sample stack so the user can explore immediately).
- This card must be reachable on first run (per 2.1) — today the 3-tool gate
  hides it from new users.

### 2.6 First run vs returning user (decision table)

| Condition | What shows |
| --- | --- |
| `!hasSeenOnboarding` (true first run) | Map/preview surface + one-screen onboarding overlay (2.2). |
| `hasSeenOnboarding` && `isUniverseEmpty` | Map surface + `emptyStateCard` (2.5). No overlay. |
| `hasSeenOnboarding` && `!isUniverseEmpty` | Normal app. Last surface/state. No overlay, no empty card. |

---

## 3. Affected files

- `Sources/MyAIMap/RootShell.swift` — change default surface / first-run
  branch; host the onboarding overlay; wire the 3 actions to `showChat()`,
  `presentAddTool(draft:)`, `showUniverse()`; keep the Map route enabled for
  empty and low-tool universes.
- `Sources/MyAIMap/UI/Search/ChatScreen.swift` — `ChatStarterPanel` is no
  longer the first thing a new user sees; its open-ended "What are you trying
  to build?" hero should be demoted to a returning-user chat empty state (it
  stays valid once the user chooses **Ask AI**).
- `Sources/MyAIMap/Universe/UniverseMapView.swift` /
  `Sources/MyAIMap/Universe/UniverseOverlayView.swift` — ensure
  `emptyStateCard` renders for first-run/empty users; keep Founder OS core
  visible behind it.
- `Sources/MyAIMap/State/UniverseStore.swift` — add `hasSeenOnboarding`
  persistence (load/save), mirroring `hapticsEnabled`.
- `Sources/MyAIMap/State/UniverseViewModel.swift` — expose `hasSeenOnboarding`
  + `markOnboardingSeen()`.
- New view (suggested): `Sources/MyAIMap/UI/Onboarding/OnboardingOverlay.swift`
  for the one-screen overlay (presented from `RootShell`).

---

## 4. Acceptance criteria

1. **5-second comprehension.** On true first run, a user who has never seen
   the app reads the overlay and can state, unprompted, that the app "maps my
   AI tools visually and helps me pick tools." No open-ended question is the
   first thing shown.
2. **No locked dead-end.** A first-run user is never trapped on a screen
   where the only forward affordance (the Map pill) is disabled.
3. **Three obvious next steps.** The overlay shows exactly three labelled
   actions — Ask AI, Add Tool, Explore Map — each of which does what it says
   and dismisses the overlay.
4. **Onboarding shows once.** After any dismissal path, force-quitting and
   relaunching the app does NOT show the overlay again
   (`hasSeenOnboarding == true` persisted).
5. **Empty state is actionable.** A returning user with an empty universe
   lands on the map showing the Founder OS core + the empty-state card with
   working **Add your first tool** and **Load a sample universe** actions.
6. **Sample path works.** Tapping **Load a sample universe** populates the
   map with the Founder OS sample stack and the user can immediately explore
   planets.
7. **No regression for established users.** A user with >= 1 tool sees neither
   the overlay nor the empty card and lands in the normal app.
