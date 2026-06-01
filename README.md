# AI Tool Universe Map

Standalone interactive 3D map for an AI-founder operating system. GitNexus is only a visual reference; this folder is an independent React/Vite implementation that can be moved into any app.

## What It Includes

- Central `Founder OS` node.
- Orbit-style tool groups for coding, design, research, media, distribution, infrastructure, knowledge, and core orchestration.
- Clickable 3D nodes with a side panel explaining category, workflow role, source URL, and connected tools.
- Search and category filtering.
- Liquid Glass intake field for pasting a tool name or URL.
- Rule-based v1 classifier in `src/lib/classify-ai-tool.ts`.
- Custom tools persisted in localStorage with validated JSON import/export.
- Dialog focus trap, Escape close, and visible keyboard focus states.
- Logo.dev-ready service logos via `VITE_LOGO_DEV_PUBLISHABLE_KEY`, with local SVG monogram fallback.
- Data-first structure in `src/data/ai-tool-universe.ts`, ready to move to JSON, API, or database later.

## Run

```bash
npm install
npm run dev
```

The dev server defaults to [http://127.0.0.1:5177](http://127.0.0.1:5177).

To enable Logo.dev logos, copy `.env.example` to `.env.local` and set only the publishable key:

```bash
VITE_LOGO_DEV_PUBLISHABLE_KEY=pk_your_publishable_key
```

Do not put a Logo.dev secret key in the frontend.

## Validate

```bash
npm run lint
npm run typecheck
npm test
npm run smoke:visual
npm run build
```

`npm run smoke:visual` expects the dev server to be running at `http://127.0.0.1:5177`.
The latest desktop screenshot is saved at `screenshots/ai-tool-universe-desktop.png`.

## Deploy

Production is live at [https://ai-tool-universe-map.vercel.app](https://ai-tool-universe-map.vercel.app).

The Vercel project is linked locally through `.vercel/`, which is intentionally ignored by git. Redeploy the current state with:

```bash
npx vercel deploy --prod
```

Vercel uses `vercel.json` to run `npm run build` and serve `dist`. If enabling Logo.dev on Vercel, set only `VITE_LOGO_DEV_PUBLISHABLE_KEY` as a project environment variable. Never expose or commit the Logo.dev secret key.

## Where To Edit

- `src/data/ai-tool-universe.ts`: categories, tools, workflow stages, and graph relations.
- `src/lib/classify-ai-tool.ts`: rule-based classification.
- `src/components/AIToolUniverseMap.tsx`: overlay layout, side panels, intake, search, filters.
- `src/components/AIToolUniverse3D/*`: React Three Fiber scene, camera, stars, nodes, rings, and lines.
- `src/components/ToolLogo.tsx` and `src/lib/tool-logos.ts`: Logo.dev URL generation and SVG fallback logos.
- `screenshots/`: desktop and hover-state visual references.

## Current Remaining Work

- Replace the rule-based classifier with an API-backed classifier when the backend is ready.
- Move custom tools from localStorage into authenticated storage.
- Add manual relation editing and relation confidence.
- Add more Playwright snapshots for search-empty and imported-tool states.

## Model Recommendation

For continuing implementation, use Codex or Claude Code with a strong coding model. For this specific feature, the best workflow is:

1. Codex or Claude Code for component implementation, tests, and integration.
2. A stronger reasoning model for architecture review if you connect this to a real database or AI classifier.
3. A visual design pass in browser screenshots before merging.
