# Constellation viz — overnight status (2026-06-28)

Branch `polish/day-sprint`. All 3 phases **code-complete + committed**. Pure
logic is unit-tested (374 unit tests green); rendered visuals + live AI call
need a morning pass because the simulator/test-runner was too flaky overnight
for reliable XCUITest (one run hung 67 min). Builds were gated with
`xcodebuild build -destination 'generic/platform=iOS Simulator'` (sim-independent).

## What landed

### Phase 1 — 2D constellation (NEW default map)
Commits `ee5020a` and earlier (T1–T5).
- `Universe/Constellation/ConnectionResolver.swift` — pure typed connections
  (alternative / pipeline / constellation / curated), unit-tested.
- `Universe/Constellation/ConstellationLayout.swift` — deterministic clustered
  star-field (core centred, category constellations, collision-resolved),
  unit-tested at SE/iPhone/iPad widths.
- `Universe/Constellation/ConstellationView.swift` — SwiftUI star-field +
  ambient twinkle + **connection trace** (lines draw on with a light pulse) +
  **spring/bounce reveal** of connected stars + dim others + reverse on deselect.
  Dropped into the `graph2D` slot (now the default map). Reduce Motion → instant.
- Overview screenshot confirms the star-field renders:
  `screenshots/polish-sprint/constellation/02-overview*`.

### Phase 2 — AI-resolved connections (cached)
Commit `e3c9f83`.
- `RelationAI.swift` — prompts the DeepSeek backend for related tool ids;
  lenient JSON parse validated against the catalog; graceful `[]` on failure.
  Parse + prompt unit-tested.
- `RelationCache.swift` — UserDefaults `[toolID:[relatedID]]`, unit-tested.
- `ConnectionResolver` gained an `aiRelations` param (`.ai` kind, over derived,
  under curated; can cross categories).
- `ConstellationView` reads cached AI relations into the trace and `.task`-fetches
  them lazily on first focus, then re-renders the brighter `.ai` lines.

### Phase 3 — 3D connection traces
- `UniverseSceneController.addConnectionTraces(...)` — on tool focus in the 3D
  scene, draws brighter lines from the focused tool to its `ConnectionResolver`
  connections, reusing `LinkGeometry` + the shared link mesh. Scoped to the
  focused category's tools (the satellites actually rendered).

## Needs a morning pass (visual / live — sim was too flaky overnight)
1. **2D trace animation** — tap a star; confirm lines draw on + pulse + connected
   stars bounce in + others dim + deselect reverses.
2. **Category tap** — confirm tapping a constellation (the clear cluster button,
   id `ConstellationCategory.<cat>`) focuses the branch; if not hittable, move the
   tap target onto the constellation name label.
3. **Top-cluster chrome clearance** — top constellations vs the route/render
   chrome (raised the layout top inset to 156; eyeball it).
4. **Phase 2 live** — with a DeepSeek key present, focus a tool, confirm the AI
   fetch lands + caches + the `.ai` lines brighten.
5. **3D traces** — switch to 3D, focus a tool, confirm the trace lines render.
6. **Re-enable the strict smoke** — `UniverseUISmokeTests` selectors were updated
   to constellation ids; re-run on a healthy sim and fix any navigation gaps.

## Deliberately deferred (needs live iteration with you)
- **Full star-field-in-3D rewrite** (stars in depth instead of the planet/orbit
  scene). Doing a from-scratch RealityKit scene blind (no live render) is
  high-risk; the safe Phase 3 above adds the connection-trace *value* to the
  existing 3D scene. The full 3D rebuild should be done with live visual feedback.
- Tuning star sizes / glow / trace colours / bounce feel — taste calls best done
  watching it live.

## How to verify (morning)
```
xcrun simctl shutdown all; xcrun simctl boot 538F098B-D962-4B6A-85A9-41C96DCF3A99
cd ios-app && xcodegen generate
xcodebuild test -project MyAIMap.xcodeproj -scheme MyAIMap \
  -destination 'platform=iOS Simulator,id=538F098B-D962-4B6A-85A9-41C96DCF3A99' \
  -derivedDataPath build \
  -only-testing:MyAIMapUITests/UniverseUISmokeTests/testCaptureKeyStates \
  -resultBundlePath /tmp/v.xcresult
xcrun xcresulttool export attachments --path /tmp/v.xcresult --output-path /tmp/shots
```
If the runner hangs again, reset the sim (`simctl erase`) or recreate it.
Keep DerivedData (`ios-app/build`) — do not delete it (disk is tight).
