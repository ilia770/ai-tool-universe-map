# Loop Plan — AI Tool Universe Map polish sprint

Sprint budget: ~7 hours, executed via `/loop` so progress survives token-limit pauses.

## Execution rules

- One task = one git commit, prefixed `[ID] subject` (e.g. `[A1] camera over-zoom`).
- After each commit: `npm run typecheck && npm run lint && npm test && npm run build`.
  - If any step fails: `git revert HEAD`, log to `LOOP_LOG.md`, move to next task.
  - Do NOT chain risky tasks on a red baseline.
- After every completed track (A, B, C, D, E): `git push origin main`.
- If a task touches > 3 files or > 200 lines, open a PR instead of pushing direct to main.
- Skip task only after writing the reason to `LOOP_LOG.md`.

## Resume protocol

On a new session:

1. Read `docs/LOOP_LOG.md` — find last `status: done` entry.
2. `git log --oneline | grep -E '^\w+ \[[A-E][0-9]+\]'` — confirm commits match the log.
3. Start the first task with `status: pending`. Do not re-run completed ones.

## Backlog

### Track A — Bug triage (must-do)

| ID  | Task | Files | Est | Risk |
| --- | --- | --- | --- | --- |
| A1  | Camera over-zoom: push baseline distances in `CameraController`; add `OrbitControls minDistance/maxDistance`. | `CameraController.tsx`, `Scene.tsx` | 20m | low |
| A2  | Right-panel empty: remove `key={selectedTool.id}` remount; convert `tool-detail-slide` to CSS opacity transition. | `AIToolUniverseMap.tsx`, `index.css` | 25m | low |
| A3  | DOM overlay overlap: reposition Universe lens floating bar; z-index audit; mobile sticky instead of absolute. | `AIToolUniverseMap.tsx`, `index.css` | 25m | low |

### Track B — Mini-world redesign (main creative ask)

| ID  | Task | Files | Est | Risk |
| --- | --- | --- | --- | --- |
| B1  | Zoom-distance trigger: subscribe to camera distance; when below threshold near a category center, auto-enter pocket mode. | `Scene.tsx`, `CameraController.tsx` | 50m | med |
| B2  | Pocket breathing room: rewrite `pocketToolPosition` with wider spread + intra-pocket relation lines emphasized. | `layout.ts`, `Scene.tsx`, `ConnectionLines.tsx` | 70m | med |
| B3  | Pocket exit: Escape + smooth zoom-out + click-outside-pocket dismisses. | `Scene.tsx`, `AIToolUniverseMap.tsx` | 30m | low |

### Track C — Polish UX

| ID  | Task | Files | Est | Risk |
| --- | --- | --- | --- | --- |
| C1  | Connection-line clarity: dim non-pocket links harder; brighten in-pocket lens. | `ConnectionLines.tsx` | 30m | low |
| C2  | Mobile right panel → bottom sheet with drag handle. | `AIToolUniverseMap.tsx`, `index.css` | 50m | med |
| C3  | Search → camera focus on first match. | `AIToolUniverseMap.tsx`, `Scene.tsx` | 20m | low |

### Track D — Hygiene

| ID  | Task | Files | Est | Risk |
| --- | --- | --- | --- | --- |
| D1  | Tool data → JSON (`src/data/tools.json` + loader + types + test). | `src/data/**` | 50m | med |
| D2  | Vite `manualChunks`: split `three`/`drei` to shrink 979 kB chunk. | `vite.config.ts` | 40m | med |
| D3  | Relation confidence field + UI badge. | `src/data/ai-tool-universe.ts`, `src/lib/classify-ai-tool.ts`, `AIToolUniverseMap.tsx` | 30m | low |

### Track E — Stretch (only if time)

| ID  | Task | Files | Est | Risk |
| --- | --- | --- | --- | --- |
| E1  | Playwright responsive snapshots — 3 viewports, retry, deterministic seed. | `tests/visual-smoke.spec.ts`, `playwright.config.ts` | 50m | med |
| E2  | Lighthouse + Core Web Vitals run, save to `docs/perf.md`. | `docs/perf.md` | 25m | low |

### Track F — Perf followup (post-Lighthouse)

| ID  | Task | Files | Est | Risk |
| --- | --- | --- | --- | --- |
| F1  | `frameloop="demand"` + invalidate hooks; cut idle GPU draws. | `Scene.tsx`, `CameraController.tsx`, `ProximityCategoryWatcher.tsx` | 45m | med |
| F2  | Shared BufferGeometry across all ToolNodes — one geom, N instances. | `ToolNode.tsx`, `Scene.tsx` | 40m | med |
| F3  | Pocket glow on near-camera category rings (visual cue: "this opens"). | `CategoryRing.tsx`, `Scene.tsx` | 25m | low |

## Order

`A1 → A2 → A3 → B1 → B2 → B3 → C1 → C2 → C3 → D1 → D2 → D3 → E1 → E2 → F1 → F2 → F3`

Track A first because every later track sits on top of a polished baseline.
B before C/D because mini-world is the user's primary creative ask.
D before E because hygiene reduces noise in any later snapshots.
