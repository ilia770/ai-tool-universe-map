# AI Tool Universe Map

Interactive 3D map of the AI-founder operating system. Built as a
standalone React + Vite app so it can drop into any host application.

Production: <https://ai-tool-universe-map.vercel.app>

## What it includes

- Central `Founder OS` core node with category orbits for coding, design,
  research, media, distribution, infrastructure, knowledge, and core
  orchestration.
- Clickable 3D nodes with a side panel explaining category, workflow
  role, source URL, and connected tools.
- Auto-revealing **pocket worlds**: dolly the camera toward a category
  ring and its sub-universe opens with the Fibonacci-sphere layout.
- Multi-mode relation lens: direct, adjacent orbit, same stage, same
  group.
- Liquid Glass intake field that classifies a pasted tool name or URL
  via `src/lib/classify-ai-tool.ts`.
- Search, category filtering, custom tools persisted in `localStorage`
  with validated JSON import/export.
- Logo.dev-ready service logos via `VITE_LOGO_DEV_PUBLISHABLE_KEY`,
  with a local SVG monogram fallback.
- Dialog focus trap and visible keyboard focus states.

## Keyboard shortcuts

| Key | Action |
| --- | --- |
| `Esc` | Layered exit: pocket world first, full dialog second. |
| `F` / `C` / `A` | Map clarity: focus / context / atlas. |
| `Enter` (in search) | Focus the first match. |

Clarity hotkeys are suppressed when an input is focused or a modifier
key is held.

## Run

```bash
npm install
npm run dev
```

Dev server defaults to <http://127.0.0.1:5177>.

To enable Logo.dev logos, copy `.env.example` to `.env.local` and set
only the publishable key:

```bash
VITE_LOGO_DEV_PUBLISHABLE_KEY=pk_your_publishable_key
```

Never put a Logo.dev secret key in the frontend.

## Verify

```bash
npm run typecheck
npm run lint
npm test
npm run build
npm run smoke:visual:fast      # desktop smoke, needs dev server at :5177
npm run smoke:visual:release   # full desktop/tablet/mobile matrix
```

CI mirrors the first four locally on every PR and push to `main`
(see `.github/workflows/ci.yml`).

## Deploy

Production is on Vercel. The Vercel project is linked locally through
`.vercel/`, which is gitignored. Redeploy the current state with:

```bash
npx vercel deploy --prod
```

`vercel.json` runs `npm run build` and serves `dist`. If enabling
Logo.dev on Vercel, set only `VITE_LOGO_DEV_PUBLISHABLE_KEY` as a
project environment variable. Never expose or commit a Logo.dev
secret key.

## Where to edit

- `src/data/ai-tool-universe.seed.json` — source fixture for categories,
  tools, workflow stages, and graph relations.
- `src/data/ai-tool-universe.ts` — typed facade that exports the seed data,
  lookup maps, and shared data model types.
- `src/lib/classify-ai-tool.ts` — rule-based classifier.
- `src/components/AIToolUniverseMap.tsx` — overlay layout, side panels,
  intake, search, filters, keyboard handlers.
- `src/components/AIToolUniverse3D/*` — R3F scene (Canvas, camera,
  pocket worlds, rings, nodes, lines, ambient cosmos).
- `src/components/ToolLogo.tsx` + `src/lib/tool-logos.ts` — Logo.dev
  URL generation and SVG monogram fallback.
- `screenshots/` — desktop and hover-state visual references.

## Architecture notes & agent collaboration

This repo is shared between Claude Code and Codex. Both agents follow
the rules in `.agent/INSTRUCTIONS.md` (the root `AGENTS.md` and
`CLAUDE.md` are symlinks to it). Key invariants — `frameloop="always"`,
lazy 3D chunk, no secret Logo.dev key in the bundle — are listed in
that file.

Operational tracking lives in Linear. `docs/LOOP_LOG.md` remains as
append-only history; the sprint boards beside it were retired on 2026-08-09.
The latest Lighthouse snapshot is in `docs/perf.md`.

### Native iOS UI architecture

The native app has its own permanent UI architecture and audit baseline:
[ios-app/docs/SPEC_INDEX.md](ios-app/docs/SPEC_INDEX.md). For iOS UI work,
follow [ios-app/AGENTS.md](ios-app/AGENTS.md) and
[ios-app/CONTRIBUTING.md](ios-app/CONTRIBUTING.md), not only the web rules in
this README.

## Release history

See [`CHANGELOG.md`](./CHANGELOG.md).
