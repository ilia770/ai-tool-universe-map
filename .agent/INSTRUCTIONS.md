# Shared Agent Instructions

This file is the canonical project context for both Claude Code and Codex.
`AGENTS.md` and `CLAUDE.md` at the repo root are symlinks to this file —
edit this file, not the symlinks.

## Coordination

- Treat the working tree as shared with the user and possibly another agent.
- Start every task by checking `git status --short --branch`.
- Never overwrite, revert, delete, or reformat changes you did not make
  unless the user explicitly asks.
- If another agent or the user changed a file you need, read the current
  file and work with the new state.
- For large or risky tasks, use a separate git branch or worktree
  (`git worktree add ../<repo>-<topic> origin/main`) instead of editing
  directly on the same branch.
- For small tasks in the same folder, avoid editing the same file
  concurrently. Claim the task in `.agent/status/` when useful.
- Keep generated scratch files, local locks, and temporary notes under
  `.agent/status/` or `.agent/tmp/`; these are local-only and not committed.

## Execution

- Prefer small, incremental changes.
- Read the project structure before editing.
- Use existing project patterns before adding new abstractions.
- Add or update tests when behavior changes.
- Run the narrowest relevant checks first, then broader checks when risk
  is higher. The full chain is: typecheck → lint → unit tests → build →
  Playwright smoke.
- Commit only your own completed changes, and do not stage unrelated files.

## Documentation

- Keep this file as the single source of truth for agent rules. The root
  `AGENTS.md` / `CLAUDE.md` are symlinks.
- Track engineering history in `CHANGELOG.md` per release tier.
- Per-sprint operational tracking lives in `docs/LOOP_PLAN.md` +
  `docs/LOOP_LOG.md` (append-only).

## Project Context

### Canonical docs

- Product authority: `docs/PRODUCT_CTO.md`.
- App structure: `docs/APP_STRUCTURE.md`.
- Agent collaboration and file ownership: `docs/AGENT_OPERATING_MODEL.md`.
- Current handoff status: `docs/AGENT_STATUS.md`.
- Release checklist and stop-ship rules: `docs/RELEASE_REVIEW.md`.
- UI/UX direction and visual QA rubric: `docs/design/README.md`.
- Superpowers implementation plans: `docs/superpowers/plans/`.
- Historical web polish sprint: `docs/LOOP_PLAN.md` and `docs/LOOP_LOG.md`.

### Stack

- **Language:** TypeScript (strict).
- **Build:** Vite 8 + `@vitejs/plugin-react`.
- **UI:** React 18, Tailwind CSS 4 (via `@tailwindcss/vite`), Lucide icons.
- **3D:** `three`, `@react-three/fiber`, `@react-three/drei`,
  `@react-three/postprocessing`, `camera-controls`.
- **Tests:** Vitest (unit) + Playwright (visual smoke across desktop,
  tablet, mobile chromium projects).
- **Deploy:** Vercel. Production at <https://ai-tool-universe-map.vercel.app>.

### Commands

| Verb | Command |
| --- | --- |
| Dev server | `npm run dev` (defaults to `http://127.0.0.1:5177`) |
| Typecheck | `npm run typecheck` |
| Lint | `npm run lint` |
| Unit tests | `npm test` |
| Production build | `npm run build` |
| Visual smoke (needs dev server) | `npm run smoke:visual` |
| Prod deploy | `npx vercel deploy --prod` |

Run the full chain before committing risky changes:
`npm run typecheck && npm run lint && npm test && npm run build`.

### Architecture map

- `src/App.tsx` mounts `AIToolUniverseMap` as the only route.
- `src/components/AIToolUniverseMap.tsx` owns the dialog: header, left
  sidebar (intake + search + categories), centre canvas, right
  tool-detail panel, and bottom Universe lens bar.
- `src/components/AIToolUniverse3D/*` is the R3F scene, lazy-loaded so
  the initial main chunk stays small.
  - `Scene.tsx` — Canvas root, hover state, useFrame orchestration.
  - `CameraController.tsx` — `@react-three/drei` `CameraControls`
    wrapper with `minDistance` / `maxDistance` clamping and per-view
    focus offsets (overview / pocket / node).
  - `ProximityCategoryWatcher.tsx` — non-rendering useFrame watcher
    that auto-opens a category pocket world when the camera dollies
    within `enterDistance`, and auto-closes once it pulls past
    `exitDistance` (enter < exit gives hysteresis).
  - `PocketWorldShell.tsx` — translucent sphere + torus rings that
    visualise an open pocket world.
  - `CategoryRing.tsx`, `ToolNode.tsx`, `FounderOSNode.tsx`,
    `ConnectionLines.tsx`, `StarField.tsx`, `GalaxyDust.tsx` — visual
    primitives.
  - `layout.ts` — pure math for category / tool / pocket positions
    (Fibonacci-sphere distribution inside pockets).
- `src/data/ai-tool-universe.ts` — categories, tools, links, workflow
  stages. Single source of truth for the universe data.
- `src/lib/classify-ai-tool.ts` — rule-based classifier used by the
  Liquid Glass intake field.
- `src/lib/tool-logos.ts` + `src/components/ToolLogo.tsx` — Logo.dev
  publishable-key URL generation with SVG monogram fallback.

### Invariants (do not break without coordination)

1. `Founder OS` stays the central core node (`tools[0]` is `founder-os`).
2. `AITool.orbit ∈ {0, 1, 2, 3}` — three concentric orbits plus the
   core slot (0).
3. `UniverseLink.confidence`, when set, is in `[0, 1]`. Hand-curated
   links may omit it.
4. The 3D scene is lazy-loaded — don't import `AIToolUniverse3D`
   eagerly from `AIToolUniverseMap.tsx`.
5. `frameloop="always"` on the R3F Canvas is required by ambient
   animations (StarField, GalaxyDust, ToolNode hover bob). If you
   switch to `"demand"`, you must invalidate manually for every
   animation source — otherwise visuals freeze.
6. Heavy ambient layers (`StarField`, `GalaxyDust`) mount only after
   `requestIdleCallback` — protects boot TBT.
7. Logo.dev secret keys must never reach the client bundle. Only
   `VITE_LOGO_DEV_PUBLISHABLE_KEY` is allowed in `.env*`.
8. Mobile right-panel uses `sticky bottom-0` + `max-h-[60vh]`;
   desktop reverts to a static left-bordered column. Keep the `lg:`
   override pattern intact.

### Product invariants

- The product is My AI Map: a premium cosmic AI tool universe for
  founders/operators.
- The map should explain what each tool is, what category it belongs to,
  why it matters, and what it connects to.
- Visual polish must serve orientation and readability.
- UI changes require desktop and mobile review before release.
- Do not release if the 3D canvas is blank, major text overlaps, tool
  details disappear, or category focus traps the user.

### Keyboard shortcuts

- `Escape` — layered exit: first reset active category / stage if a
  pocket world is open, then close the full dialog.
- `F` / `C` / `A` — map clarity: focus / context / atlas (suppressed
  when an input / textarea is focused or a modifier is held).
- `Enter` in the Search input — focus the first match.

### Performance budget

Lighthouse on prod after Track F (see `docs/perf.md`):

| Metric | Target | Current |
| --- | --- | --- |
| Performance | ≥ 60 | 67 |
| TBT | ≤ 1500 ms | 840 ms |
| LCP | ≤ 3.5 s | 3.1 s |
| CLS | ≤ 0.05 | 0 |

If a change regresses any of these by more than 10 %, raise it in the
PR description and link to a fresh Lighthouse run.
