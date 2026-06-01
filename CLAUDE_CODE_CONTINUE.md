# Prompt For Claude Code Or Another Coding Agent

You are working on the standalone `ai-tool-universe-map` React/Vite project. GitNexus is only a visual reference and must not be copied or treated as the target app.

Goal: polish and integrate the AI Tool Universe Map as a premium cosmic 3D product interface.

Current production deployment: https://ai-tool-universe-map.vercel.app

Required workflow:

1. Research the target frontend stack before editing if this is moved into another app.
2. Keep data in `src/data/ai-tool-universe.ts` and classification in `src/lib/classify-ai-tool.ts`.
3. Improve the map without coupling it to GitNexus.
4. Preserve the central `Founder OS` node and category orbits.
5. Keep the Liquid Glass intake field and rule-based classifier.
6. Run `npm run lint`, `npm run typecheck`, `npm test`, and `npm run build`.
7. Redeploy with `npx vercel deploy --prod` when the current state should go live.
8. Summarize changed files, risks, and future improvements.

Useful next improvements:

- Move tool data to JSON.
- Replace rule-based classification with an API-backed classifier.
- Add relation confidence and manual relation editing.
- Add responsive visual snapshots with Playwright.
- Move custom tools from localStorage JSON import/export to real backend storage.
- If the visual direction needs another leap, prototype a GLB/Blender galaxy asset without replacing the current data model.
