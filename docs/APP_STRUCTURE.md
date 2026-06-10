# Application Structure

Last updated: 2026-06-10

This file explains the product architecture at a level useful for Codex, Claude Code, and future contributors.

## Repository Map

| Path | Owner | Purpose |
| --- | --- | --- |
| `.agent/INSTRUCTIONS.md` | Agent Ops | Shared instructions for Codex and Claude Code. `AGENTS.md` and `CLAUDE.md` symlink here. |
| `docs/PRODUCT_CTO.md` | Product CTO | Product north star, roadmap, decision rules. |
| `docs/APP_STRUCTURE.md` | Tech Lead | High-level structure and file ownership. |
| `docs/AGENT_OPERATING_MODEL.md` | Agent Ops | How Codex and Claude Code split work and communicate. |
| `docs/AGENT_STATUS.md` | Agent Ops | Current handoff dashboard: done items, blockers, next files. |
| `docs/RELEASE_REVIEW.md` | Release Lead | Required release checklist and review gates. |
| `docs/design/` | UI/UX | Visual direction, references, design QA. |
| `docs/superpowers/plans/` | Planning | Superpowers implementation plans. |
| `docs/LOOP_PLAN.md` | Web Delivery | Historical web polish sprint plan. |
| `docs/LOOP_LOG.md` | Web Delivery | Historical sprint execution log. |
| `screenshots/` | QA/UI | Reference screenshots and visual review artifacts. |
| `src/data/ai-tool-universe.seed.json` | Data/Product | Source fixture for categories, tools, relation data, workflow metadata. |
| `src/data/ai-tool-universe.ts` | Data/Product | Typed facade, model types, and lookup maps over the JSON seed. |
| `src/lib/classify-ai-tool.ts` | Data/Product | Rule-based classification for pasted tools/URLs. |
| `src/lib/tool-logos.ts` | UI/Data | Logo URL resolution and logo-related helpers. |
| `src/components/AIToolUniverseMap.tsx` | App Shell | Main web UI: side panel, controls, filters, search, selected tool state. |
| `src/components/AIToolUniverse3D/Scene.tsx` | 3D Lead | Three/R3F scene orchestration and selected category/tool state plumbing. |
| `src/components/AIToolUniverse3D/ToolNode.tsx` | 3D Lead | Individual node rendering, hover/click visuals, logo billboards. |
| `src/components/AIToolUniverse3D/ConnectionLines.tsx` | 3D Lead | Relationship edge rendering. |
| `src/components/AIToolUniverse3D/CameraController.tsx` | 3D Lead | Camera movement and focus transitions. |
| `src/components/AIToolUniverse3D/layout.ts` | 3D/Data | Deterministic spatial layout for tools and categories. |
| `tests/visual-smoke.spec.ts` | QA | Browser smoke checks and screenshots. |
| `ios-app/` | iOS Lead | Native SwiftUI/RealityKit prototype in PR stack. |

## Web Runtime Flow

1. `src/main.tsx` mounts the React app.
2. `src/App.tsx` renders `AIToolUniverseMap`.
3. `AIToolUniverseMap` owns top-level UI state:
   - selected tool
   - active category
   - search input
   - new tool input/classification
   - panel/sheet content
4. `Scene` receives data and callbacks, then renders:
   - galaxy/nebula background
   - founder node
   - category rings
   - tool nodes
   - connection lines
   - camera/proximity behavior
5. `ToolNode` reports hover and selection back up.
6. Side panel/bottom sheet explains selected tool and its connections.

## Data Model Responsibilities

`src/data/ai-tool-universe.seed.json` is currently the canonical web data fixture, exported through `src/data/ai-tool-universe.ts`. It should eventually split into:

| Future File | Purpose |
| --- | --- |
| `src/data/categories.json` | Category ids, labels, colors, workflow stage mapping. |
| `src/data/tools.json` | Tool facts, URLs, summaries, category membership. |
| `src/data/relations.json` | Tool-to-tool and tool-to-workflow relationships with confidence/reason. |
| `src/data/schema.ts` | Runtime validation and TypeScript types. |

Until the DB/API migration happens, do not hand-edit large data sections casually. Add tests when changing category ids, tool ids, relation fields, or classifier behavior.

## UI Composition Rules

- Keep 3D scene logic in `src/components/AIToolUniverse3D/`.
- Keep app controls and panels in `AIToolUniverseMap.tsx` unless extracting a focused component reduces complexity.
- Keep styles in `src/index.css` unless a component already uses local class composition.
- Do not put one UI card inside another card.
- Use mobile bottom-sheet patterns for tool details.
- Use clear selected/hover/focus states; never rely only on tiny text labels.

## iOS Structure Target

Native app target:
- `ios-app/project.yml` defines XcodeGen config.
- `ios-app/Sources/MyAIMap/MyAIMapApp.swift` starts the app.
- `ios-app/Sources/MyAIMap/Universe/` owns RealityKit/SwiftUI universe screens.
- `ios-app/Sources/MyAIMap/Data/` mirrors category/tool data.
- `ios-app/Tests/MyAIMapTests/` validates layout/data assumptions.

Long-term, generate shared JSON from the web data model and load it in both web and iOS.
