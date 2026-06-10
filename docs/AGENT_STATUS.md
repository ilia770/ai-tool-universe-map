# Agent Status Dashboard

Last updated: 2026-06-10

Use this as the fast handoff file before asking Codex or Claude Code to continue.

## Current Product State

Web app:
- Production URL: `https://ai-tool-universe-map.vercel.app`.
- Main experience: interactive AI tool universe map with 3D scene, categories, tool details, search, logos, and pocket-world interactions.
- Active visual polish history is documented in `docs/LOOP_PLAN.md` and `docs/LOOP_LOG.md`.

iOS app:
- Native SwiftUI/RealityKit prototype exists in the iOS PR stack.
- Build succeeded locally with Xcode 26.5.
- `build-for-testing` succeeded.
- Full simulator launch/test was blocked by local CoreSimulator runtime migration, not by Swift compile errors.

## PR Stack Known From Latest Handoff

| PR | Branch | Purpose |
| --- | --- | --- |
| #2 | `track-L-lens-slim-and-hover-stability` | L1 lens slim + L2 hover stability |
| #3 | `chore/cto-cleanup` | docs canon + CI + changelog + budget guardrail |
| #4 | `feat/ios-strategy` | iOS strategy + design refs + Apple skills |
| #5 | `feat/ios-phase0-scaffold` | SwiftUI + RealityKit scaffold |
| #6 | `feat/ios-phase1-product-shell` | Native product shell + test host config |

Merge order: #2 -> #3 -> #4 -> #5 -> #6.

## Current Blockers

| Area | Blocker | Evidence | Next Action |
| --- | --- | --- | --- |
| iOS simulator launch | CoreSimulator hung during runtime/data migration after iOS 26.5 simulator install | `xcodebuild test` reached simulator launch, then `NSMachErrorDomain -308`; `simctl bootstatus` waited on BackBoard/Data Migration | Retry after Xcode finishes runtime cache/migration, or run on real iPhone with Apple signing |
| TestFlight | Apple Developer team id not configured | TestFlight requires signed archive | Add team id to `ios-app/project.yml` after enrollment |
| Web data model | Tool data still TypeScript literal | `docs/LOOP_LOG.md` D1 skipped JSON migration as risky without schema | Create schema-backed JSON migration PR |

## Recent Agent Work

| Area | Done | Validation | Next Action |
| --- | --- | --- | --- |
| Intake relation intelligence | `classifyToolDetailed` now returns explainable relation suggestions while preserving backward-compatible `relationIds` | `npm run typecheck`, `npm run lint`, `npm test`, `npm run build` | Next UI pass can render suggestion labels/reasons/confidence in the Liquid Glass preview and selected-tool details |

## Where To Fix Next

| Goal | Primary Files |
| --- | --- |
| Improve web hover/focus | `src/components/AIToolUniverse3D/Scene.tsx`, `ToolNode.tsx`, `ConnectionLines.tsx`, `src/index.css` |
| Improve category mini-worlds | `src/components/AIToolUniverse3D/layout.ts`, `Scene.tsx`, `CameraController.tsx` |
| Simplify side panel | `src/components/AIToolUniverseMap.tsx`, `src/index.css` |
| Improve logos | `src/lib/tool-logos.ts`, `src/components/ToolLogo.tsx` |
| Improve classifier | `src/lib/classify-ai-tool.ts`, `src/lib/classify-ai-tool.test.ts` |
| Move data to JSON/schema | `src/data/ai-tool-universe.ts`, new `src/data/*.json`, new `src/data/schema.ts` |
| Continue iOS | `ios-app/project.yml`, `ios-app/Sources/MyAIMap/**`, `ios-app/Tests/MyAIMapTests/**` |

## Minimum Next-Agent Startup

```bash
git status --short --branch
sed -n '1,220p' .agent/INSTRUCTIONS.md
sed -n '1,220p' docs/PRODUCT_CTO.md
sed -n '1,220p' docs/AGENT_OPERATING_MODEL.md
sed -n '1,220p' docs/AGENT_STATUS.md
```

Then choose the relevant plan or PR and continue.
