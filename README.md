# AI Tool Universe Map

Standalone interactive 3D map for an AI-founder operating system. GitNexus is only a visual reference; this folder is an independent React/Vite implementation that can be moved into any app.

## What It Includes

- Central `Founder OS` node.
- Orbit-style tool groups for coding, design, research, media, distribution, infrastructure, knowledge, and core orchestration.
- Clickable 3D nodes with a side panel explaining category, workflow role, source URL, and connected tools.
- Search and category filtering.
- Liquid Glass intake field for pasting a tool name or URL.
- Rule-based v1 classifier in `src/lib/classify-ai-tool.ts`.
- Data-first structure in `src/data/ai-tool-universe.ts`, ready to move to JSON, API, or database later.

## Run

```bash
npm install
npm run dev
```

The dev server defaults to [http://127.0.0.1:5177](http://127.0.0.1:5177).

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

## Where To Edit

- `src/data/ai-tool-universe.ts`: categories, tools, workflow stages, and graph relations.
- `src/lib/classify-ai-tool.ts`: rule-based classification.
- `src/components/AIToolUniverseMap.tsx`: overlay layout, side panels, intake, search, filters.
- `src/components/AIToolUniverse3D/*`: React Three Fiber scene, camera, stars, nodes, rings, and lines.

## Model Recommendation

For continuing implementation, use Codex or Claude Code with a strong coding model. For this specific feature, the best workflow is:

1. Codex or Claude Code for component implementation, tests, and integration.
2. A stronger reasoning model for architecture review if you connect this to a real database or AI classifier.
3. A visual design pass in browser screenshots before merging.
